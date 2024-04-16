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
   local lcontainer="$1"

   # Container Image is passed as Argument
   local limage="$2"

   # Container Command is passed as Argument
   local lcommand="$3"

   # Volumes are passed as Argument as a String
   local lvolumes="$4"

   # Extra Arguments
   local lextraargs="${@:5}"

   # Echo
   echo "Running Container ${lcontainer}"

   # Command String
   # Handle the case where the command is NOT specified
   if [[ -z "$lcommand" ]]
   then
      #lcommandstr=""

      # Run Container
      $engine run --name=${lcontainer} ${lvolumes} ${networkstring} --network-alias ${lcontainer} --pull missing --restart no ${limage} ${lextraargs}
   else
      #lcommandstr="bash -c "

      # Run Container
      $engine run --name=${lcontainer} ${lvolumes} ${networkstring} --network-alias ${lcontainer} --pull missing --restart no ${limage} bash -c "${lcommand}" ${lextraargs}
   fi

   # Run Container
   #$engine run --name=${lcontainer} ${lvolumes} ${networkstring} --network-alias ${lcontainer} --pull missing --restart no ${limage} ${lcommandstr} ${lcommand} ${lextraargs}
}

container_run_migration() {
   # Container Name is passed as Argument
   local lcontainer="$1"

   # Container Image is passed as Argument
   local limage="$2"

   # Container Command is passed as Argument
   local lcommand="$3"

   # Extra Arguments
   local lextraargs="${@:4}"

   # Run Container
   container_run_generic "${lcontainer}" "${limage}" "${lcommand}" "-v ./:/migration -v ${sourcedata}:/sourcedata" "${lextraargs}"
   #$engine run --name="${lcontainer}" -v ./:/migration -v ${sourcedata}:/sourcedata ${networkstring} --network-alias ${lcontainer} --pull missing --restart no ${limage} bash -c "${lcommand}" ${lextraargs}
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

   # Run Container
   container_run_generic "${lcontainer}" "${limage}" "${lcommand}" "-v ./homeassistant/:/config" "${lextraargs}"
}
