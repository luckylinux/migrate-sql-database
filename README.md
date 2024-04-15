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

# Motivation
I wanted to save this Script somewhere because I know I will need to convert another Installation of HomeAssistant soon.

And I do NOT think I am the only one facing this issue ...

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

