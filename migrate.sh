#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Secrets
source $toolpath/secrets.sh

# Generate sql command file
tee migrate.sql <<EOF
load database
  from ${DATABASE_SOURCE_STRING}
  into ${DATABASE_DESTINATION_STRING}
  with data only, include drop, create tables, drop indexes, truncate, batch rows = 1000
  SET work_mem to '64 MB', maintenance_work_mem to '512 MB'
;
EOF;

# Run Using Docker
#https://pgloader.readthedocs.io/en/latest/tutorial/tutorial.html
#podman run -v "./:/migration" --rm -it dimitri/pgloader:latest pgloader /migration/migrate.sql

# Run Local
pgloader migrate-remote.sql
