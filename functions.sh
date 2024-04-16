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

   # Echo
   echo "Removing Container ${lcontainer}"

   # Remove Container
   $engine rm ${larguments} ${lcontainer}
}


container_run_generic() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Container Image is passed as Argument
   local limage=$2

   # Volumes are passed as Argument as a String
   local lvolumes=$3
   echo "Volumes: " ${lvolumes[*]}

   # Container Command is passed as Argument
   local lcommand=$4
   echo "Command: " ${lcommand[*]}

   # Extra Arguments
   local larguments="${@:5}"
   local lcheckarguments=$(echo ${larguments} | tr -d ' ')
   echo "Podman Extra Arguments: " ${larguments[*]}

   # Create Network if Not Exist
   #$engine network create --internal --ignore $net
   $engine network create --ignore $net

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
      # No Command Provided
      # Just Use Docker Image Entrypoint
      if [[ -n "${larguments[*]}" ]]
      then
         # Run Container
         $engine run --rm "${larguments[*]}" --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --net "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}"
      else
         # Run Container
         echo "NO ARGUMENTS"
         $engine run --rm --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --net "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}"
      fi
   else
      # A Command was Provided
      # Run it with bash -c "..."
      if [[ -n "${larguments[*]}" ]]
      then
         # Run Container
         $engine run --rm "${larguments[*]}" --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --net "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "${lcommand[*]}"
      else
         # Run Container
         echo "NO ARGUMENTS"
         $engine run --rm --log-level="${loglevel}" --name="${lcontainer}" ${lvolumes[*]} --net "${CONTAINER_NETWORK}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "${lcommand[*]}"
      fi
   fi

}

container_run_migration() {
   # Container Name is passed as Argument
   local lcontainer="$1"

   # Container Image is passed as Argument
   local limage="$2"

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
   container_run_generic "${lcontainer}" "${limage}" "${lvolumes[*]}" "${lcommand[*]}" "${larguments}"
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
   container_run_generic "${lcontainer}" "${limage}" "${lvolumes[*]}" "" "${larguments}"
}
