#!/bin/bash

# This does NOT work
#source .env; podman run --rm --name="pgloader-test" -v ./:/migration --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PGLOADER} bash -c "pgloader /migration/pgloader/intermediary/migrate.sql"

# This seems to work
source .env; podman run --rm --name="pgloader-test" -v ./sourcedata/:/sourcedata -v ./:/migration --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PGLOADER} bash -c "sleep 5; pgloader /migration/pgloader/intermediary/migrate.sql"

# This works
source .env; podman run --rm --name="psql-test" --net=${CONTAINER_NETWORK} --network-alias "psql-test" --pull missing --replace --restart no ${IMAGE_PSQL} bash -c "sleep 5; psql ${DATABASE_INTERMEDIARY_STRING} -c '\l'"


# !!! MUST USE A NETWORK CREATE with `podman create network XXX` NOT using --internal !!!
