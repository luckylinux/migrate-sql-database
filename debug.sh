#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load .env
source $toolpath/.env

# Override Engine (Docker/Podman)
engine=${1-"podman"}

# Check Engine
source $toolpath/engine.sh

# Mount also SourceData inside the Container
sourcedata=$(dirname ${DATABASE_SOURCE_FILE_REAL_PATH})
sourcedata=$(realpath --canonicalize-missing ${sourcedata})

#####################################################################################
################################### Load Functions ##################################
#####################################################################################

# Load Functions
source $toolpath/functions.sh

#####################################################################################
####################### Try to Debug BASH Variable Expansion ########################
#####################################################################################

# Do not perform infinite debug loop
debug=""

# Generate Networks List for Docker/Podman
networkstring=()
#networkstring=(--net ${CONTAINER_NETWORK})
for net in "${CONTAINER_NETWORK[@]}"
do
    networkstring+=("--net ${net}")

    # Create Network if Not Exist
    $engine network create --ignore $net
done

# Run Test
cmd=("psql ${DATABASE_INTERMEDIARY_STRING} -c 'SELECT timescaledb_pre_restore();'; ${debug}")
container_run_migration "psql-test" "postgres:latest" "${cmd}"
