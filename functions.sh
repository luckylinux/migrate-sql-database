#!/bin/bash

container_destroy() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Optional Flags are passed as following Arguments
   local larguments="${@:2}"

   # Echo
   echo "Stopping Container ${lcontainer}"

   # Stop Container
   $engine stop ${larguments} ${lcontainer}

   # Remove Container
   $engine rm ${larguments} ${lcontainer}

   # Echo
   echo "Removing Container ${lcontainer}"
}


container_run_generic() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Volumes are passed as Argument as a String
   local lvolumes=$2
   echo "Volumes: " ${lvolumes[*]}

   # Container Image is passed as Argument
   local limage=$3

   # Container Command is passed as Argument
   local lcommand=$4
   echo "Command: " ${lcommand[*]}

   # Extra Arguments
   local larguments="${@:5}"
   echo "Extra Arguments: " ${larguments[*]}

   # Define Log Level if not defined yet
   if [[ -z "${loglevel}"  ]]
   then
      loglevel="error"
      #loglevel="debug"
   fi

   # Echo
   echo "Running Container ${lcontainer}"
   # Command String
   # Handle the case where the command is NOT specified
   if [[ -z "$lcommand" ]]
   then
      # Run Container
      #$engine run ${loglevel[*]} --name="${lcontainer}" ${lvolumes[@]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" ${larguments[*]}
      #$engine run --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" "${larguments[*]}"
      $engine run "${larguments[*]}" --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}"
   else
      # Run Container
      #echo "${networkstring[*]}"
      #$engine run "${loglevel[*]}" --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "\"${lcommand[*]}\"" "${larguments[*]}"
      #$engine run ${loglevel[*]} --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "\"${lcommand[*]}\"" "${larguments[*]}"
      #$engine run ${loglevel[*]} --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "\"${lcommand[*]}\"" "${larguments[*]}"
      #$engine run --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "\"${lcommand[*]}\"" "${larguments[*]}"
      $engine run "${larguments[*]}" --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --network "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "${lcommand[*]}"
   fi

}

container_run_migration() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Container Image is passed as Argument
   local limage=$2

   # Container Command is passed as Argument
   local lcommand=$3

   # Extra Arguments
   local larguments="${@:4}"

   # Get full path of base folder
   local basefolderfullpath=$(realpath --canonicalize-missing "./")

   # Get full path of source data folder
   local sourcedatafullpath=$(dirname ${DATABASE_SOURCE_FILE_REAL_PATH})
   sourcedatafullpath=$(realpath --canonicalize-missing ${sourcedatafullpath})


   # Define Volumes
   #local lvolumes=("-v ./:/migration -v ${sourcedata}:/sourcedata")
   local lvolumes=()
   lvolumes+=("-v" "${basefolderfullpath}:/migration")
   lvolumes+=("-v" "${sourcedatafullpath}:/sourcedata")

   # Run Container
   container_run_generic "${lcontainer}" "${lvolumes[*]}" "${limage}" "${lcommand[*]}" "${larguments}"
}


container_run_homeassistant() {
   # Container Name is passed as Argument
   local lcontainer="$1"

   # Container Image is passed as Argument
   local limage="$2"

   # Container Command is Not Used for HomeAssistant
   local lcommand="true;"

   # Extra Arguments
   local larguments="${@:3}"

   # Get full path of homeassistant subfolder
   local fullpath=$(realpath --canonicalize-missing "./homeassistant")

   # Define Volumes
   local lvolumes=("-v" "${fullpath}:/config")

   # Run Container
   container_run_generic "${lcontainer}" "${lvolumes[*]}" "${limage}" "" "${larguments}"
}
