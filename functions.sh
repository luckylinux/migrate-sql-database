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

   # Container Image is passed as Argument
   local limage=$3

   # Container Command is passed as Argument
   local lcommand=$4

   # Extra Arguments
   local lextraargs="${@:5}"

   # Define Log Level
   loglevel=("--log-level=debug")

   # Echo
   echo "Running Container ${lcontainer}"

   # Command String
   # Handle the case where the command is NOT specified
   if [[ -z "$lcommand" ]]
   then
      #lcommandstr=""
#      cat <<EOF
#      Running: $engine run "${loglevel[*]}" --name="${lcontainer}" ${lvolumes[*] "${networkstring[*]}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" ${lextraargs[*]}
#EOF

      # Run Container
      $engine run "${loglevel[*]}" --name="${lcontainer}" "${lvolumes[@]}" "${networkstring[*]}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" ${lextraargs[*]}
   else
      #lcommandstr="bash -c "

      # Run Container
#      cat <<EOF
#      Running: $engine run "${loglevel[*]}" --name="${lcontainer}" "${lvolumes[*]}" "${networkstring[*]}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "${lcommand[*]}" ${lextraargs[*]}
#EOF
      $engine run "${loglevel[*]}" --name="${lcontainer}" "${lvolumes[@]}" "${networkstring[*]}" --network-alias "${lcontainer}" --pull missing --restart no "${limage}" bash -c "${lcommand[*]}" ${lextraargs[*]}
   fi

   # Run Container
   #$engine run --name=${lcontainer} ${lvolumes} ${networkstring} --network-alias ${lcontainer} --pull missing --restart no ${limage} ${lcommandstr} ${lcommand} ${lextraargs}
}

container_run_migration() {
   # Container Name is passed as Argument
   local lcontainer=$1

   # Container Image is passed as Argument
   local limage=$2

   # Container Command is passed as Argument
   local lcommand=$3

   # Extra Arguments
   local lextraargs="${@:4}"

   # Define Volumes
   #local lvolumes=("-v ./:/migration -v ${sourcedata}:/sourcedata")
   local lvolumes=()
   lvolumes+=(-v "./:/migration")
   lvolumes+=(-v "${sourcedata}:/sourcedata")

   # Run Container
   container_run_generic ${lcontainer} ${lvolumes} ${limage} ${lcommand} ${lextraargs}
}


container_run_homeassistant() {
   # Container Name is passed as Argument
   local lcontainer="$1"

   # Container Image is passed as Argument
   local limage="$2"

   # Container Command is Not Used for HomeAssistant
   local lcommand=""

   # Extra Arguments
   local lextraargs="${@:3}"

   # Define Volumes
   local lvolumes=(-v ./homeassistant/:/config)

   # Run Container
   container_run_generic ${lcontainer} ${lvolumes} ${limage} ${lcommand} ${lextraargs}
}
