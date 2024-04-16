#!/bin/bash

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

