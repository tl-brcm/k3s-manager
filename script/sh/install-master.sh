#!/bin/bash

# Load modules
source ./modules/MultipassUtils.sh
source ./modules/LoggingUtils.sh
source modules/LoggingUtils.sh

# Load configuration from JSON file
scriptBaseDir=$(dirname "$0")
configPath="$scriptBaseDir/../../config/config.json"
configJson=$(jq '.' < "$configPath")

# Extract VM settings from the config
vmName=$(echo "$configJson" | jq -r '.vmSettings.master.vmName')
cpuCores=$(echo "$configJson" | jq -r '.vmSettings.master.cpuCores')
ram=$(echo "$configJson" | jq -r '.vmSettings.master.ram')
disk=$(echo "$configJson" | jq -r '.vmSettings.master.disk')
vmIp=$(echo "$configJson" | jq -r '.vmSettings.master.vmIp')
k3sVersion=$(echo "$configJson" | jq -r '.k3sVersion')
timeoutSeconds=$(echo "$configJson" | jq -r '.timeoutSeconds')

# Define other variables
hostListPath="$scriptBaseDir/../../config/host_list"


# Use functions from the module
test_vm_existence "$vmName"
start_vm "$vmName" "$cpuCores" "$ram" "$disk"
set_network_configuration "$vmName" "$vmIp"
invoke_network_settings_application "$vmName" "$timeoutSeconds"
install_k3s "$vmName" "$k3sVersion" "$vmIp"
add_host_list "$vmName" "$hostListPath"
