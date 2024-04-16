#!/bin/bash

exec_cmd() {
   # Command is passed as argument
   local lcmd=$1

   # Echo
   echo "Executing Command: ${lcmd}"

   # Exec / Eval Command
   eval $lcmd
}

container_destroy() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Optional Flags are passed as following Arguments
   local larguments="${@:2}"

   # Stop Container
   container_stop "${lcontainer}" "${larguments}"

   # Remove Container
   container_remove "${lcontainer}" "${larguments}"
}

container_remove() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Optional Flags are passed as following Arguments
   local larguments="${@:2}"

   # Echo
   echo "Removing Container ${lcontainer}"

   # Remove Container
   $engine rm ${larguments} ${lcontainer}
}

container_stop() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Optional Flags are passed as following Arguments
   local larguments="${@:2}"

   # Echo
   echo "Stopping Container ${lcontainer}"

   # Stop Container
   $engine stop ${larguments} ${lcontainer}
}


container_run_generic() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Container Image is passed as Argument
   local limage=$2

   # Volumes are passed as Argument as a String
   local lvolumes=$3

   # Container Command is passed as Argument
   local lcommand=$4

   # Extra Arguments
   local larguments="${@:5}"

   # Create Network if Not Exist
   #$engine network create --internal --ignore $net    # !! DOES NOT WORK WITH PGLOADER CONTAINER !!
   $engine network create --ignore $net

   # Define Log Level if not defined yet
   if [[ -z "${loglevel}"  ]]
   then
      loglevel="error"
   fi

   # Build List of Arguments for the Left Side
   local largs=()
   if [[ -n "${larguments[*]}" ]]
   then
      largs+=("${larguments}")
   fi
   largs+=("--rm")
   largs+=("--name=${lcontainer}")
   largs+=("--log-level=${loglevel}")
   largs+=("${lvolumes[*]}")
   largs+=("--net ${CONTAINER_NETWORK}")
   largs+=("--network-alias")
   largs+=("${lcontainer}")
   largs+=("--pull")
   largs+=("missing")
   largs+=("--restart")
   largs+=("no")

   # Build List of Arguments for the Right Side
   local rargs=()
   if [[ -n "${lcommand[*]}" ]]
   then
      # A running Command has been provided
      rargs+=("bash")
      rargs+=("-c")
      rargs+=("\"${lcommand[*]}\"")
   fi

   # Build the complete command
   cmd="$engine run ${largs[*]} ${limage} ${rargs[*]}"

   # Execute the Command
   exec_cmd "$cmd"
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
   lvolumes+=("-v")
   lvolumes+=("${basefolderfullpath}:/migration")
   lvolumes+=("-v")
   lvolumes+=("${sourcedatafullpath}:/sourcedata")

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
