#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Secrets
source $toolpath/.env

# Override Engine (Docker/Podman)
engine=${1-"podman"}

# Check Engine
source $toolpath/engine.sh

# Load Functions
source $toolpath/functions.sh

# Disable Debug
debug=""

# Enable Debug
# Prevents Containers from Exiting after they finished their Task(s)
# !! Enabling this REQUIRES killing with CTRL+Z since Traps are NOT (currently ?) setup !!!
#debug=" while [ true ]; do sleep 1; done;"

# Create test folder if not exist
mkdir -p test

# Create a source folder if not exist
mkdir -p sourcedata

# Create homeassistant folder if not exist
mkdir -p homeassistant

# Create backup folders if not exist
mkdir -p backup/source
mkdir -p backup/intermediary
mkdir -p backup/destination

# Generate Networks List for Docker/Podman
networkstring=""
for net in "${CONTAINER_NETWORK[@]}"
do
    networkstring="${networkstring} --net=${net}"

    # Create Network if Not Exist
    $engine network create --ignore $net
done

# Bring Down Containers
#$compose down

# Bring Up Containers
#$compose up -d


#####################################################################################
################## SQLITE3 -> PostgreSQL (Intermediary) Conversion ##################
#####################################################################################

# Step 1 - Generate Basic HomeAssistant Configuration
tee homeassistant/configuration.yaml << EOF
# Loads default set of integrations. Do not remove.
default_config:

http:
#  ip_ban_enabled: true
#  login_attempts_threshold: 5
  use_x_forwarded_for: true
  trusted_proxies:
    # IP address of the proxy server
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - 127.0.0.1
    - ::1
    - fe80::/64
    - fe00::/64
    - fd00::/64

# Database
recorder:
  db_url: postgresql://${DATABASE_INTERMEDIARY_USER}:${DATABASE_INTERMEDIARY_PASSWORD}@${DATABASE_INTERMEDIARY_HOST}:${DATABASE_INTERMEDIARY_PORT}/${DATABASE_INTERMEDIARY_DB}
  db_retry_wait: 5 # Wait 5 seconds before retrying
EOF


# Step 2 - Let Temporary HomeAssistant Container Create the Database Tables
# ============================================================================

# Create Initial Tables with HomeAssistant Container
hcreatetablescontainer="homeassistant-create-tables"

# Stop and Remove Container (if Already Running / Existing)
container_destroy "${hcreatetablescontainer}" "--destroy"

# Create & Run Container Now
#$engine run --name=${hcreatetablescontainer} -v ./homeassistant/:/config ${networkstring} --network-alias ${hcreatetablescontainer} --pull missing --restart unless-stopped ghcr.io/home-assistant/home-assistant:stable >> homeassistant/${hcreatetablescontainer}.log &
container_run_homeassistant "${hcreatetablescontainer}" "ghcr.io/home-assistant/home-assistant:stable" "" >> homeassistant/${hcreatetablescontainer}.log &

# Wait a bit for Database Tables to be Created
sleep 30

# Stop and Remove Container (when working on the Database we MUST AVOID CORRUPTION - If HomeAssistant keeps writing to the Database it WILL GENERATE CORRUPTION)
container_destroy "${hcreatetablescontainer}"






# Mount also SourceData inside the Container
sourcedata=$(dirname ${DATABASE_SOURCE_FILE_REAL_PATH})
sourcedata=$(realpath --canonicalize-missing ${sourcedata})

# Copy Database Source File to a location accessible by the Container
# Only Needed if not in this folder or if Volume not mounted within the Container
#cp ${DATABASE_SOURCE_FILE} source/

# Generate SQL Command File to migrate to PostgreSQL
tee pgloader/intermediary/migrate.sql << EOF
load database
  from ${DATABASE_SOURCE_STRING}
  into ${DATABASE_INTERMEDIARY_STRING}
  with data only, include drop, create tables, drop indexes, truncate, batch rows = 1000
  SET work_mem to '64 MB', maintenance_work_mem to '512 MB'
;
EOF

# Generate SQL Fix Command File
# Maybe Valid for Version 16 Only ?
# Source: https://wiki.postgresql.org/wiki/Fixing_Sequences
tee psql/intermediary/fix-sequences.sql << EOF
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
EOF

# Generate SQL Fix Command File
# Maybe Valid for Version 14-15 ?
# Source: https://writech.run/blog/how-to-fix-sequence-out-of-sync-postgresql/
#tee psql/intermediary/fix-sequences.sql << EOF
#SELECT 'SELECT SETVAL(' ||
#       quote_literal(quote_ident(PGT.schemaname) || '.' || quote_ident(S.relname)) ||
#       ', COALESCE(MAX(' ||quote_ident(C.attname)|| '), 1) ) FROM ' ||
#       quote_ident(PGT.schemaname)|| '.'||quote_ident(T.relname)|| ';'
#FROM pg_class AS S,
#     pg_depend AS D,
#     pg_class AS T,
#     pg_attribute AS C,
#     pg_tables AS PGT
#WHERE S.relkind = 'S'
#    AND S.oid = D.objid
#    AND D.refobjid = T.oid
#    AND D.refobjid = C.attrelid
#    AND D.refobjsubid = C.attnum
#    AND T.relname = PGT.tablename
#ORDER BY S.relname;
#EOF


# Other Required Fixes
#tee psql/intermediary/fix-other.sql << EOF
#
#EOF



# Step 3. Migrate the Data using pgloader
# ============================================================================

# Execute pgloader Using Docker
# Documentation: https://pgloader.readthedocs.io/en/latest/tutorial/tutorial.html
pgloadercontainer="pgloader-migration"

# Stop and Remove Container (if Already Running / Existing)
container_destroy "${pgloadercontainer}" "--ignore"

# Create & Run Container Now
container_run_migration "${pgloadercontainer}" "ghcr.io/dimitri/pgloader:latest" "pgloader /migration/pgloader/intermediary/migrate.sql; ${debug}"
#$engine run --name="${pgloadercontainer}" -v ./:/migration -v ${sourcedata}:/sourcedata ${networkstring} --network-alias ${pgloadercontainer} --pull missing --restart no ghcr.io/dimitri/pgloader:latest bash -c "pgloader /migration/pgloader/intermediary/migrate.sql; ${debug}"

# Stop and Remove Container
container_destroy "${pgloadercontainer}"



# Step 4. Fix some Stuff by Running SQL Queries using psql
# ============================================================================

# No Official psql Image is available so just run another PostgreSQL Server Instance
pfixcontainer="psql-intermediary-fixes"
generatedsequencesfix="generated-sequences-fix.sql"

# Stop and Remove Container (if Already Running / Existing)
container_stop "${pfixcontainer}" "--ignore"

# Create & Run Container Now
# -Atx or -Atq are common options for the psql command
container_run_migration "${pfixcontainer}" "postgres:latest" "cd /migration/psql/intermediary; psql -Atq ${DATABASE_INTERMEDIARY_STRING} -f fix-sequences.sql -o ${generatedsequencesfix}; psql -Atx ${DATABASE_INTERMEDIARY_STRING} -f ${generatedsequencesfix}; rm ${generatedsequencesfix}; ${debug}"
#$engine run --name="${pfixcontainer}" -v ./:/migration -v ${sourcedata}:/sourcedata ${networkstring} --network-alias ${pfixcontainer} --pull missing --restart no postgres:latest bash -c "cd /migration/psql/intermediary; psql -Atq ${DATABASE_INTERMEDIARY_STRING} -f fix-sequences.sql -o ${generatedsequencesfix}; psql -Atx ${DATABASE_INTERMEDIARY_STRING} -f ${generatedsequencesfix}; rm ${generatedsequencesfix}; ${debug}"

# Stop and Remove Container
container_stop "${pfixcontainer}" "--ignore"


#####################################################################################
######### PostgreSQL (Intermediary) -> TimescaleDB (Destination) Conversion #########
#####################################################################################
# Source https://docs.timescale.com/self-hosted/latest/migration/
#        - If < 100GB:
#             - Do Migration at Once: https://docs.timescale.com/self-hosted/latest/migration/entire-database/
#        - Otherwise:
#             - Migrate Schema and Tables Separately: https://docs.timescale.com/self-hosted/latest/migration/schema-then-data/
#             - Live Migration without Intermediary Database: https://docs.timescale.com/self-hosted/latest/migration/same-db/
#
#
# For the Following it is assumed to do Migration at Once (< 100GB)

# Perform the following Operations:
# 1. Dump the Intermediary Database
# 1. Prepare your Timescale Database for data restoration by using timescaledb_pre_restore to stop background workers:
# 2. Restore the dumped Data
# 3. At the psql prompt, return your Timescale database to normal operations by using the timescaledb_post_restore command:
# 4. ANALYZE;

# Genernate Timestamp both for Backup and Restore Purposes
timestamp=$(date +"%Y%m%d-%H%M%S")


# Step 1. Backup/Export Intermediary PostgreSQL Database using pg_dump
# ============================================================================

# No Official psql Image is available so just run another PostgreSQL Server Instance
pbackupcontainer="psql-intermediary-dump"

# Stop and Remove Container (if Already Running / Existing)
container_stop "${pbackupcontainer}" "--ignore"

# Create & Run Container Now
# -Atx or -Atq are common options for the psql command
container_run "${pbackupcontainer}" "postgres:latest" "cd /migration/backup/intermediary; pg_dump ${DATABASE_INTERMEDIARY_STRING} -Fc -v -f backup-${timestamp}.dump; ${debug}"
#$engine run --name="${pbackupcontainer}" -v ./:/migration -v ${sourcedata}:/sourcedata ${networkstring} --network-alias ${pbackupcontainer} --pull missing --restart no postgres:latest bash -c "cd /migration/backup/intermediary; pg_dump ${DATABASE_INTERMEDIARY_STRING} -Fc -v -f backup-${timestamp}.dump; ${debug}" # rm ${generatedsequencesfix}; ${debug}"

# Stop and Remove Container
container_stop "${pbackupcontainer}"



# Step 2. Stop Background Workers
# ============================================================================
# No Official psql Image is available so just run another PostgreSQL Server Instance
pprerestorecontainer="psql-destination-prerestore"

# Stop and Remove Container (if Already Running / Existing)
container_stop "${pprerestorecontainer}" "--ignore"

# Create & Run Container Now
container_run "${pprerestorecontainer}" "postgres:latest" "cd /migration/backup/destination; psql ${DATABASE_INTERMEDIARY_STRING} -c 'SELECT timescaledb_pre_restore();'; ${debug}"

# Stop and Remove Container
container_stop "${pprerestorecontainer}"



# Step 3. Import dumped Data
# ============================================================================
# No Official psql Image is available so just run another PostgreSQL Server Instance
pimportcontainer="psql-destination-import"

# Stop and Remove Container (if Already Running / Existing)
container_stop "${pimportcontainer}" "--ignore"

# Create & Run Container Now
container_run_migration "${pimportcontainer}" "postgres:latest" "cd /migration/backup/intermediary; pg_restore ${DATABASE_DESTINATION_STRING} --no-owner -Fc -v backup-${timestamp}.dump; ${debug}"

# Stop and Remove Container
container_stop "${pimportcontainer}" "--ignore"


# Step 4. Return TimescaleDB to Normal Operation
# ============================================================================
# No Official psql Image is available so just run another PostgreSQL Server Instance
ppostrestorecontainer="psql-destination-postrestore"

# Stop and Remove Container (if Already Running / Existing)
container_stop "${ppostrestorecontainer}" "--ignore"

# Create & Run Container Now
container_run_migration "${postrestorecontainer}" "postgres:latest" "cd /migration/backup/intermediary; psql ${DATABASE_DESTINATION_STRING} -c 'SELECT timescaledb_post_restore();'; ${debug}"

# Stop and Remove Container
container_stop "${ppostrestorecontainer}"


# Step 5. Update Table Statistics
# ============================================================================
# No Official psql Image is available so just run another PostgreSQL Server Instance
panalyzepostrestorecontainer="psql-destination-analyze"

# Stop and Remove Container (if Already Running / Existing)
container_stop "${panalyzepostrestorecontainer}" "--ignore"

# Create & Run Container Now
container_run_migration "${panalyzepostrestorecontainer}" "postgres:latest" "cd /migration/backup/intermediary; psql ${DATABASE_DESTINATION_STRING} -c 'ANALYZE;'; ${debug}"

# Stop and Remove Container
container_stop "${panalyzepostrestorecontainer}"
