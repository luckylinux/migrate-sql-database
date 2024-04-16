# Introduction
Script Configuration to Migrate a [SQLite3] Database to [PostgreSQL].

# Use Case
I wanted to convert my HomeAssistant SQLite3 Database to PostgreSQL/TimescaleDB.

I attempted to follow the instructions in:
- https://sigfried.be/blog/migrating-home-assistant-sqlite-to-postgresql/
- https://www.redpill-linpro.com/techblog/2023/03/21/migrating-home-assistnt-to-postgresql.html

However something was off.
The Instructions (and SQL commands) in those Blogs reported:
```
load database
  from ${DATABASE_SOURCE_STRING}
  into ${DATABASE_DESTINATION_STRING}
with data only, drop indexes, reset sequences, truncate, batch rows = 1000
SET work_mem to '32 MB', maintenance_work_mem to '64 MB';
```

First of all I had to remove the quotes around the `${DATABASE_SOURCE_STRING}` and `${DATABASE_DESTINATION_STRING}`. `pgloader` just would refuse to even start otherwise.

However, in my case at least, the `reset sequences` part (and potentially other) was causing quite a bit of problems.

```
2024-04-15T21:43:39.008000Z LOG pgloader version "3.6.7~devel"
2024-04-15T21:43:39.115997Z LOG Migrating from #<SQLITE-CONNECTION sqlite:///home/USER/Migration/home-assistant_v2.db {XXXXXXXXXX}>
2024-04-15T21:43:39.115997Z LOG Migrating into #<PGSQL-CONNECTION pgsql://DBUSER@DBHOST:5432/DBNAME {XXXXXXXXXX}>
KABOOM!
SIMPLE-ERROR: pgloader failed to find anything in schema "public" in target catalog.
An unhandled error condition has been signalled:
   pgloader failed to find anything in schema "public" in target catalog.




What I am doing here?

pgloader failed to find anything in schema "public" in target catalog.

```

Looking at the [Documentation](https://github.com/dimitri/pgloader/blob/master/docs/ref/sqlite.rst) for the different options I attempted to change the SQL Command a bit until I got it working:
```
load database
  from ${DATABASE_SOURCE_STRING}
  into ${DATABASE_DESTINATION_STRING}
  with data only, include drop, create tables, drop indexes, truncate, batch rows = 1000
  SET work_mem to '64 MB', maintenance_work_mem to '512 MB'
;
``` 

And specifically I did:
- Removed the `reset sequences` (this is the main offender)
- Added `include drop`
- Added `create tables`

Note however that further Investigation is required.

The Options might need to be further tuned once I test with a bigger Database.

# Easy Debugging of PostgreSQL Issues
In case you want to list the Databases on the other running Container you can for instance do:
```
source .env; podman run --name="psql-test" --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PSQL} bash -c "psql ${DATABASE_INTERMEDIARY_STRING} -c '\l'"
```

# Not Currently Working
Obviously it's not fully correct, otherwise I wouldn't be seeing a lot of these errors in the `homeassistant-server` Container Logs:
```
duplicate key value violates unique constraint "states_pkey"
```

So there is probably something not working quite right with regards to PostgreSQL UNIQUE Constraint.

This might be related to Sequences that are now out of sync:
- https://web.archive.org/web/20230928041745/https://arctype.com/blog/postgres-sequence/
- https://writech.run/blog/how-to-fix-sequence-out-of-sync-postgresql/

Furthermore from https://sigfried.be/blog/migrating-home-assistant-sqlite-to-postgresql/ this may prove useful:
```
SELECT setval(pg_get_serial_sequence('statistics_runs', 'run_id'), coalesce(MAX(run_id), 1)) from statistics_runs;
SELECT setval(pg_get_serial_sequence('statistics_meta', 'id'), coalesce(MAX(id), 1)) from statistics_meta;
SELECT setval(pg_get_serial_sequence('statistics', 'id'), coalesce(MAX(id), 1)) from statistics;
SELECT setval(pg_get_serial_sequence('statistics_short_term', 'id'), coalesce(MAX(id), 1)) from statistics_short_term;
SELECT setval(pg_get_serial_sequence('states', 'state_id'), coalesce(MAX(state_id), 1)) from states;
SELECT setval(pg_get_serial_sequence('state_attributes', 'attributes_id'), coalesce(MAX(attributes_id), 1)) from state_attributes;
SELECT setval(pg_get_serial_sequence('events', 'event_id'), coalesce(MAX(event_id), 1)) from events;
SELECT setval(pg_get_serial_sequence('event_data', 'data_id'), coalesce(MAX(data_id), 1)) from event_data;
SELECT setval(pg_get_serial_sequence('recorder_runs', 'run_id'), coalesce(MAX(run_id), 1)) from recorder_runs;
SELECT setval(pg_get_serial_sequence('schema_changes', 'change_id'), coalesce(MAX(change_id), 1)) from schema_changes;
```



# Fixing all Sequences with one Script
File `fix_sequences.sql`:
```
SELECT 'SELECT SETVAL(' ||
       quote_literal(quote_ident(PGT.schemaname) || '.' || quote_ident(S.relname)) ||
       ', COALESCE(MAX(' ||quote_ident(C.attname)|| '), 1) ) FROM ' ||
       quote_ident(PGT.schemaname)|| '.'||quote_ident(T.relname)|| ';'
FROM pg_class AS S,
     pg_depend AS D,
     pg_class AS T,
     pg_attribute AS C,
     pg_tables AS PGT
WHERE S.relkind = 'S'
    AND S.oid = D.objid
    AND D.refobjid = T.oid
    AND D.refobjid = C.attrelid
    AND D.refobjsubid = C.attnum
    AND T.relname = PGT.tablename
ORDER BY S.relname;
```

1. Save the query in a fix_sequences.sql file.
2. Run the query contained in the fix_sequences.sql file and store the result in a temp file. 
3. Then, run the queries contained in the temp file. 
4. Finally, delete the temp file.

```
#!/bin/bash

psql -Atq -f fix_sequences.sql -o temp
psql -f temp
rm temp
```

# Motivation
I wanted to save this Script somewhere because I know I will need to convert another Installation of HomeAssistant soon.

And I do NOT think I am the only one facing this issue ...

# Before Migration
1. Backup
2. Backup
3. BACKUP

Once that is done:
4. Spin up a fresh `postgres` or `timescaledb-ha` Instance.
5. Configure the `recorder` Section in HomeAssistant `configuration.yaml`
6. Restart HomeAssistant
7. Let HomeAssistant Create the Tables in the new Database
8. Stop the HomeAssistant Container

# Usage
Clone the Repository
```
git clone https://github.com/luckylinux/migrate-sql-database.git
```

Edit the Secrets using your preferred Text Editor:
```
# Copy Example File
cp secrets.sh.example secrets.sh

# Edit using nano
nano secrets.sh 
```

Run the Migration Script:
```
./migrate.sh
```

# TODO
- Implement Docker Container Support (for running from the `pgloader` Container)

# Important
When using `podman`, do **NOT** use the default `podman` network for either the Destination Database Server (`DATABASE_DESTINATION_HOST`}) otherwise DNS Name Resolution will **NOT** work between the Destination Container and the Migration Containing Script.
