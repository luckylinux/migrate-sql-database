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



# Sequences Issues
## Introduction
Attempting to follow the instructions in:
- https://sigfried.be/blog/migrating-home-assistant-sqlite-to-postgresql/
- https://www.redpill-linpro.com/techblog/2023/03/21/migrating-home-assistnt-to-postgresql.html

Yields some Sequences Errors, where some Unique Keys are not Unique Anymore.

Obviously it's not fully correct, otherwise I wouldn't be seeing a lot of these errors in the `homeassistant-server` Container Logs:
```
duplicate key value violates unique constraint "states_pkey"
```

So there is probably something not working quite right with regards to PostgreSQL UNIQUE Constraint.

This might be related to Sequences that are now out of sync:
- https://web.archive.org/web/20230928041745/https://arctype.com/blog/postgres-sequence/
- https://writech.run/blog/how-to-fix-sequence-out-of-sync-postgresql/

## Possible Solutions
### Manual Sequence Fixing based of Sigfried's Blog
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

### Fixing all Sequences with one automated Script
#### General
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

#### PostgreSQL >= 16
File `fix-sequences.sql`:
```
SELECT 
    'SELECT SETVAL(' ||
       quote_literal(quote_ident(sequence_namespace.nspname) || '.' || quote_ident(class_sequence.relname)) ||
       ', COALESCE(MAX(' ||quote_ident(pg_attribute.attname)|| '), 1) ) FROM ' ||
       quote_ident(table_namespace.nspname)|| '.'||quote_ident(class_table.relname)|| ';'
FROM pg_depend 
    INNER JOIN pg_class AS class_sequence
        ON class_sequence.oid = pg_depend.objid 
            AND class_sequence.relkind = 'S'
    INNER JOIN pg_class AS class_table
        ON class_table.oid = pg_depend.refobjid
    INNER JOIN pg_attribute 
        ON pg_attribute.attrelid = class_table.oid
            AND pg_depend.refobjsubid = pg_attribute.attnum
    INNER JOIN pg_namespace as table_namespace
        ON table_namespace.oid = class_table.relnamespace
    INNER JOIN pg_namespace AS sequence_namespace
        ON sequence_namespace.oid = class_sequence.relnamespace
ORDER BY sequence_namespace.nspname, class_sequence.relname;

```

#### PostgreSQL < 15

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

# Motivation
I wanted to save this Script somewhere because I know I will need to convert another Installation of HomeAssistant soon.

And I do NOT think I am the only one facing this issue :smile:.

# Before Migration
## Backup
First and Foremost:
1. Backup
2. Backup
3. Backup

Did I say BACKUP :smile: ?

## Stop your Current HomeAssistant Instance
As part of the Migration, this Tool will spin up a fresh HomeAssistant Container, just in order to get the Required SQL Tables Created.

However, First and Foremost, your **Production** HomeAssistant Container **MUST** be stopped !

For instance using `podman-compose`:
```
# Stop you HomeAssistant Installation
podman-compose down
```

# Usage
Clone the Repository
```
git clone https://github.com/luckylinux/migrate-sql-database.git
```

Edit the Configuration File using your preferred Text Editor and set all Options to the desired Values:
```
# Copy Example Environment File
cp .env.example .env

# Edit using nano
nano secrets.sh 
```

**Important**: for better Control and Stability, it is recommended to PIN a specific TAG for the different Docker/Podman Images. Do NOT use ":latest" !

# Update the Compose File
Based on the Examples provided in `.env.example` file, you must now configure **TWO** new Containers.

The first is Temporary (PostgreSQL) in order to handle the first Stage of the Conversion and Fixing the required SQL Tables.

The second one is Permanent (TimescaleDB-HA).

It can be debated what's the most Pratical approach, either one of these can work:
a. Update you existing `compose.yml` file
   1. Comment ALL the `homeassistant-server` related lines, to make sure that your original HomeAssistant Container does NOT start to write a handful of Data in the middle of the Database Migration
   2. Add the lines (based on the example of `.env.example`) for the Temporary PostgreSQL Database Container as well as the TimescaleDB Database Container
   3. Bring these Containers up with e.g. `podman-compose up -d`
   4. Set the required Parameters in the `.env` file
   5. Perform the Migration
   6. Let the Migration complete without errors - Try again if errors occur
   7. Uncomment ALL the `homeassistant-server` related lines
   8. Configure the `recorder` Section in HomeAssistant `configuration.yaml` Configuration File
   9. Bring your production HomeAssistant Instance back Up with e.g. `podman-compose up -d`
b. Use the provided `compose.yml` file as part of this Repository
   1. Select a Permanent Data Location in `compose.yml` which you will later use once the production HomeAssistant Container will be back up Running
   2. Configure the Required Parameters in `.env` (in particular Container Images and User/Password/Database)
   3. Bring these containers up with `podman-compose up -d`
   4. Perform the Migration
   5. Let the Migration complete without errors - Try again if errors occur
   6. Copy the relevant Parts of this `compose.yml` file into your production HomeAssistant `compose.yml` file
   7. Copy the relevant Parts of this `.env` file into your production HomeAssistant `compose.yml` file (or use Secrets, `.env_file` etc)
   8. Configure the `recorder` Section in HomeAssistant `configuration.yaml` Configuration File
   9. Bring your production HomeAssistant Instance back Up with e.g. `podman-compose up -d`
    
# Run the Migration Script
Run the Migration Script after Ensuring a Clean State.

IMPORTANT: this will DELETE **ALL** DATA from the Databases when running the Provided "testing" environment (ALL DATA in `./test/containers/data` will be DELETED).

In case of multiple executions of the script due to e.g. Errors occurring, most likely you will have to MANUALLY DELETE ALL DATA of the new PostgreSQL and TailscaleDB-HA Databases, otherwise the Conversion Scripts, the SQL fixes etc will most likely not work correctly.

```
./reset.sh; ./migrate.sh
```

# Issues due to DNS Name Resolution Failure
See https://github.com/containers/podman/issues/22407 for my Experience. I lost several Days due to this Problem. It's quite Intermittent and difficult to replicate.

On another Note, be aware that the Default `podman` Network does NOT have DNS Resolution Enabled  !!!

Possible Docker has the same / similar Issues.

# Debugging of Networking Issues with the Container
In case you experience some Network Communication Failures from one Container to the Other, this Docker Image can prove very useful:

Run with:
```
podman run -d --rm -v ./loop.sh:/loop.sh --name="${debugcontainer}" --user root --net "${CONTAINER_NETWORK}" arunvelsriram/utils bash -c "/loop.sh"
```

Then Access it to run the desired Diagnostic (`ping`, `nslookup`, etc):
```
podman exec -it ${debugcontainer} /bin/bash

nslookup migration-postgresql-testing
```

**Note**: for Ping to work correctly, it is MOST LIKELY required to run with --user root. This is particularly the case when running a Podman RootLess Container.

Docker may have similar Issues/Requirements/Features.

# Debugging of PostgreSQL Issues
In case you want to list the Databases on the other running Container you can for instance do:
```
source .env; podman run --name="psql-test" --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PSQL} bash -c "psql ${DATABASE_INTERMEDIARY_STRING} -c '\l'"
```

Further Notes available in `easy_debug.sh` and `podman_debug_dns_issues.sh`.

# TODO
- Implement Docker Container Support (for running from the `pgloader` Container)

# Important
When using `podman`, do **NOT** use the default `podman` network for either the Destination Database Server (`DATABASE_DESTINATION_HOST`}) otherwise DNS Name Resolution will **NOT** work between the Destination Container and the Migration Containing Script.
