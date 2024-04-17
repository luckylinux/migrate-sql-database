#!/bin/bash

trap "echo signal; exit 0" SIGTERM

while [ true ]
do
    sleep 1 & wait $!
done
