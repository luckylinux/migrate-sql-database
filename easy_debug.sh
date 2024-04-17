#!/bin/bash

# This does NOT work
#source .env; podman run --rm --name="pgloader-test" -v ./:/migration --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PGLOADER} bash -c "pgloader /migration/pgloader/intermediary/migrate.sql"

# This seems to work
source .env; podman run --rm --name="pgloader-test" -v ./sourcedata/:/sourcedata -v ./:/migration --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PGLOADER} bash -c "sleep 5; pgloader /migration/pgloader/intermediary/migrate.sql"

# This works
source .env; podman run --rm --name="psql-test" --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PSQL} bash -c "sleep 5; psql ${DATABASE_INTERMEDIARY_STRING} -c '\l'"


# !!! MUST USE A NETWORK CREATE with `podman create network XXX` NOT using --internal !!!

#####################################################
# Run a Container to Troubleshoot Network Issues
#####################################################

# Attended
#source .env; podman run --rm --name=network-debug-utils --user root --net ${CONTAINER_NETWORK} -it arunvelsriram/utils bash

# Unattended
#source .env; podman run -d --rm --name=network-debug-utils --user root --net ${CONTAINER_NETWORK} arunvelsriram/utils bash -c "while [ true ]; do sleep 1; done;"

# Unattended - Catch SIGTERM Correctly
source .env; podman run -d --replace --rm -v ./loop.sh:/loop.sh --name=network-debug-utils --user root --net ${CONTAINER_NETWORK} arunvelsriram/utils bash -c "/loop.sh"

# Get IP Address of running Container
#source .env; podman inspect migration-timescaledb-testing --format {{.NetworkSettings.Networks.${CONTAINER_NETWORK}.IPAddress}}

# Get IP address Details of All Containers
source .env; ./list_ips.sh
