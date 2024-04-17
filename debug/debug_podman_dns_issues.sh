#!/bin/bash

# Legacy Networks PREVIOUSLY Associated with the Container are still listed in /run/user/1000/networks/aardvark-dns/${networkname} as well as some host file in /run/user/1000/overlay-containers/*/userdata/hosts

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Set Secrets and Settings
CONTAINER_DANGLING_NETWORK="homeassistant"
CONTAINER_NETWORK="homeassistant_internal"
POSTGRES_DB="homeassistant"
POSTGRES_USER="homeassistant"
POSTGRES_PASSWORD="MySuperSecretPassword"

# Configure Timing Parameters
delayedstart="15"
loopinterval="5"

# Setup Traps
trap "echo signal; exit 0" SIGTERM

# Define Debug Running Container Name
debugcontainer="network-debug-utils"

# Define Target Container for nslookup
targetcontainer="migration-postgresql-testing"

# Stop Containers in Case they are Running
podman stop --ignore ${debugcontainer} 1> /dev/null 2> /dev/null
podman stop --ignore ${targetcontainer} 1> /dev/null 2> /dev/null
podman rm --ignore ${debugcontainer} 1> /dev/null 2> /dev/null
podman rm --ignore ${targetcontainer} 1> /dev/null 2> /dev/null

# Echo
echo "Create Target Container ${targetcontainer} attached to ${CONTAINER_NETWORK} and ${CONTAINER_DANGLING_NETWORK}"

# Create Extra Network
podman network create --ignore ${CONTAINER_DANGLING_NETWORK} 1> /dev/null 2> /dev/null

# Create Target Container
podman stop --ignore ${targetcontainer} 1> /dev/null 2> /dev/null
podman rm --ignore ${targetcontainer} 1> /dev/null 2> /dev/null
podman create --name=${targetcontainer} --env-file ./.env -e POSTGRES_DB=${INTERMEDIARY_DATABASE_DB} -e POSTGRES_USER=${INTERMEDIARY_DATABASE_USER} -e POSTGRES_PASSWORD=${INTERMEDIARY_DATABASE_PASSWORD} -v ./test/containers/data/migration-postgresql-testing:/var/lib/postgresql/data --network=${CONTAINER_NETWORK},${CONTAINER_DANGLING_NETWORK} --network-alias ${targetcontainer} --expose 5432 -p 5433:5432 -u root --pull missing --restart unless-stopped postgres:latest

# Echo
echo "Start Target Container ${targetcontainer}"

# Start Target Container
podman start ${targetcontainer} 1> /dev/null 2> /dev/null

# List all IPs
./list_ips.sh

# Wait a bit
sleep ${delayedstart}

# Echo
echo "Create Target Container ${targetcontainer} attached to ${CONTAINER_NETWORK} Only"

# Create Target Container
podman stop --ignore ${targetcontainer} 1> /dev/null 2> /dev/null
podman rm --ignore ${targetcontainer} 1> /dev/null 2> /dev/null

# Remove Network
####podman network rm ${CONTAINER_DANGLING_NETWORK}

# Start Container
podman create --name=${targetcontainer} --env-file ./.env -e POSTGRES_DB=${INTERMEDIARY_DATABASE_DB} -e POSTGRES_USER=${INTERMEDIARY_DATABASE_USER} -e POSTGRES_PASSWORD=${INTERMEDIARY_DATABASE_PASSWORD} -v ./test/containers/data/migration-postgresql-testing:/var/lib/postgresql/data --network=${CONTAINER_NETWORK} --network-alias ${targetcontainer} --expose 5432 -p 5433:5432 -u root --pull missing --restart unless-stopped postgres:latest

# Echo
echo "Start Target Container ${targetcontainer}"

# Start Target Container
podman start ${targetcontainer} 1> /dev/null 2> /dev/null

# List all IPs
./list_ips.sh

# Wait a bit
sleep ${delayedstart}


# Echo
echo "Running Container ${debugcontainer}"

# Run Unattended Container and let it Loop
# Replace Container if it already exists
podman run -d --rm -v ./loop.sh:/loop.sh --name="${debugcontainer}" --user root --net "${CONTAINER_NETWORK}" arunvelsriram/utils bash -c "/loop.sh"

# Initialize Counter
counter=1

# Run nslookup upon multiple Restarts
while [ true ]
do
    # Wait 5 seconds
    sleep ${loopinterval} & wait $!

    # Echo
    echo "==============================================================================================="
    echo "==============================================================================================="
    echo "==============================================================================================="

    # Echo
    c=$(printf "%03d" $counter)
    echo "Performing Run ${c}"

    # Echo
    echo "Performing NSLOOKUP from Container ${debugcontainer} Querying DNS for ${targetcontainer}"

    # Run nslookup
    podman exec -it ${debugcontainer} nslookup ${targetcontainer}

    # List all IPs
    ./list_ips.sh

    # Echo
    echo "Restarting Container ${debugcontainer}"

    # Restart Container
    podman restart ${debugcontainer} 1> /dev/null 2> /dev/null

    # Echo
    echo -e "\n\n"

    # Increment Counter
    counter=$((counter + 1))
done

