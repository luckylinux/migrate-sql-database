#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Override Engine (Docker/Podman)
engine=${1-"podman"}

# Check Engine
source $toolpath/engine.sh

# Stop Containers in case they are running
$compose down

# Remove Data in the test Folder
sudo rm -rf ./test/containers/data/*

# Stop other Running Processes
# For a Single Process
#OLDPROCESS=$(ps aux | grep "/bin/bash ./migrate.sh" | head -1 | awk {'print $2'})

# For Multiple Processes
mapfile -t OLDPROCESSES < <( ps aux | grep "migrate.sh" | grep -v "grep" | awk {'print $2'} )

for oldprocess in "${OLDPROCESSES[@]}"
do
   # Echo
   echo "Kill Unfinished Process $oldprocess"

   # Kill Process
   kill -9 $oldprocess
done

# Restart Containers
$compose up -d

# Wait a bit to make sure that Database is Up and Running
sleep 60
