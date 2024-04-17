#!/bin/bash

# List All containers
mapfile -t containers < <( podman ps --all --format="{{.Names}}" )
for container in "${containers[@]}"
do
    # Echo
    echo "Processing Container $container"

    # List associated IPs
    #mapfile -t networks < <( podman inspect $container --format {{.NetworkSettings.Networks}} )
    mapfile -t networks < <( podman inspect $container | jq -r '.[0].NetworkSettings.Networks | keys[]'  )
    for network in "${networks[@]}"
    do
        # Get Network Name
        netname=$network

        # Get IP Address
        #netip=$(podman inspect $container --format {{.NetworkSettings.Networks.$network.IPAddress}})
        netip=$(podman inspect $container | jq -r ".[0].NetworkSettings.Networks.$netname.IPAddress")

        # Echo
        echo -e "\t Network: ${netname} , IP: ${netip}"
    done
done

