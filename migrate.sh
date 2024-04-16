#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Secrets
source $toolpath/secrets.sh

# Override Engine (Docker/Podman)
engine=${1-"podman"}

# Prefer Podman over Docker
if [[ -n $(command -v podman) ]] && [[ "$engine" == "podman" ]]
then
    # Use Podman to run the image
    engine="podman"

    # Use podman-compose
    compose="podman-compose"
elif [[ -n $(command -v docker) ]] && [[ "$engine" == "docker" ]]
then
    # Use Docker to run the image
    engine="docker"

    # Use docker-compose
    compose="docker-compose"
else
    # Error
    echo "Neither Podman nor Docker could be found and/or the specified Engine <$engine> was not Found. Aborting !"
fi

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

# Generate Basic HomeAssistant Configuration
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
  db_url: postgresql://${DATABASE_DESTINATION_USER}:${DATABASE_DESTINATION_PASSWORD}@${DATABASE_DESTINATION_HOST}:${DATABASE_DESTINATION_PORT}/${DATABASE_DESTINATION_DB}
  db_retry_wait: 5 # Wait 5 seconds before retrying
EOF

# Populate Initial Tables with HomeAssistant Container
populatetablescontainer="homeassistant-populate-tables"

# Stop and Remove Container (if Already Running / Existing)
$engine stop --ignore ${populatetablescontainer}
$engine rm --ignore ${populatetablescontainer}

# Create & Run Container Now
#$engine run -d --name=${populatetablescontainer} -v ./homeassistant/:/config ${networkstring} --network-alias ${populatetablescontainer} --pull missing --restart unless-stopped ghcr.io/home-assistant/home-assistant:stable
$engine run --name=${populatetablescontainer} -v ./homeassistant/:/config ${networkstring} --network-alias ${populatetablescontainer} --pull missing --restart unless-stopped ghcr.io/home-assistant/home-assistant:stable >> homeassistant/${populatetablescontainer}.log &
sleep 30

# Stop and Remove Container (when working on the Database we MUST AVOID CORRUPTION - If HomeAssistant keeps writing to the Database it WILL GENERATE CORRUPTION)
$engine stop ${populatetablescontainer}
$engine rm ${populatetablescontainer}

# Mount also SourceData inside the Container
sourcedata=$(dirname ${DATABASE_SOURCE_FILE_REAL_PATH})
sourcedata=$(realpath --canonicalize-missing ${sourcedata})

# Copy Database Source File to a location accessible by the Container
# Only Needed if not in this folder or if Volume not mounted within the Container
#cp ${DATABASE_SOURCE_FILE} source/

# Generate SQL Command File to migrate to PostgreSQL
tee pgloader/migrate.sql << EOF
load database
  from ${DATABASE_SOURCE_STRING}
  into ${DATABASE_DESTINATION_STRING}
  with data only, include drop, create tables, drop indexes, truncate, batch rows = 1000
  SET work_mem to '64 MB', maintenance_work_mem to '512 MB'
;
EOF

# Generate SQL Fix Command File
tee psql/fix-sequences.sql << EOF
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
EOF

#tee psql/fix-other.sql << EOF
#
#EOF

# Generate TimescaleDB Conversion Command File


# Execute pgloader Using Docker
# Documentation: https://pgloader.readthedocs.io/en/latest/tutorial/tutorial.html
#$engine run -v "./:/migration" "${networkstring}" --rm -it ghcr.io/dimitri/pgloader:latest bash -c "pgloader /migration/pgloader/migrate.sql"
pgloadercontainer="pgloader-migration"

# Stop and Remove Container (if Already Running / Existing)
$engine stop --ignore ${pgloadercontainer}
$engine rm --ignore ${pgloadercontainer}

# Create & Run Container Now
$engine run --name="${pgloadercontainer}" -v ./:/migration -v ${sourcedata}:/sourcedata ${networkstring} --network-alias ${pgloadercontainer} --pull missing --restart no ghcr.io/dimitri/pgloader:latest bash -c "pgloader /migration/pgloader/migrate.sql; ${debug}"

# Stop and Remove Container
$engine stop ${pgloadercontainer}
$engine rm ${pgloadercontainer}

# Execute psql Using Docker
# No Official psql Image is available so just run another PostgreSQL Server Instance
psqlcontainer="psql-migration"
generatedsequencesfix="generated-sequences-fix.sql"

# Stop and Remove Container (if Already Running / Existing)
$engine stop --ignore ${pgloadercontainer}
$engine rm --ignore ${pgloadercontainer}

# Create & Run Container Now
# -Atx or -Atq are common options for the psql command
$engine run --name="${psqlcontainer}" -v ./:/migration -v ${sourcedata}:/sourcedata ${networkstring} --network-alias ${psqlcontainer} --pull missing --restart no postgres:latest bash -c "cd /migration/psql; psql -Atq ${DATABASE_DESTINATION_STRING} -f ${generatedsequencesfix}; psql -Atq ${DATABASE_DESTINATION_STRING} -f temp ${generatedsequencesfix}; rm ${generatedsequencesfix}; ${debug}"

# Stop and Remove Container
$engine stop ${psqlcontainer}
$engine rm ${psqlcontainer}
