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
