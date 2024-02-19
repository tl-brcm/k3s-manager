#!/bin/bash

# Source utility scripts
source modules/K3sUtils.sh
source modules/MultipassUtils.sh
source modules/LoggingUtils.sh

scriptBaseDir=$(dirname "$(realpath "$0")")

# Check if prefix is provided
if [ -z "$1" ]; then
    # Get the first available directory under slaves if no prefix is provided
    slave_dir=$(find "$scriptBaseDir/../../config/slaves/" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$slave_dir" ]; then
        write_log "No slave configuration directory found." "ERROR"
        exit 1
    fi
    write_log "No prefix provided. Using configuration from $slave_dir" "WARN"
else
    slave_dir="$scriptBaseDir/../../config/slaves/$1"
fi

configPath="$slave_dir/config.json"
hostListPath="$slave_dir/host_list"

# Load configuration from JSON file
if [ ! -f "$configPath" ]; then
    write_log "Config file not found at $configPath" "ERROR"
    exit 1
fi

configJson=$(cat "$configPath")

# Extract VM settings from the config
vmName=$(echo "$configJson" | jq -r '.vmSettings.client.vmName')
cpuCores=$(echo "$configJson" | jq -r '.vmSettings.client.cpuCores')
ram=$(echo "$configJson" | jq -r '.vmSettings.client.ram')
disk=$(echo "$configJson" | jq -r '.vmSettings.client.disk')
vmIp=$(echo "$configJson" | jq -r '.vmSettings.client.vmIp')

# Other configuration
timeoutSeconds=$(echo "$configJson" | jq -r '.timeoutSeconds')
masterVmName=$(echo "$configJson" | jq -r '.vmSettings.master.vmName') # Assuming the master's name is still relevant for the slave setup
k3sConfigFile="k3s.yaml"
localTempPath="$scriptBaseDir/temp/"
localScriptPath="$scriptBaseDir/install_kubectx_kubens.sh"
remoteTempPath="/home/ubuntu/"
use_scp=false

# Check VM existence and start VM
write_log "Checking if VM $vmName already exists..." "INFO"
test_vm_existence "$vmName"
write_log "Starting VM $vmName..." "INFO"
start_vm "$vmName" "$cpuCores" "$ram" "$disk"

# Set Network Configuration
write_log "Setting network configuration for $vmName..." "INFO"
set_network_configuration "$vmName" "$vmIp"

# Invoke Network Settings Application
write_log "Applying network settings for $vmName..." "INFO"
invoke_network_settings_application "$vmName" "$timeoutSeconds"

write_log "Wait for 20 secs for host to be initialized..." "INFO"
sleep 20

# Add Host List
write_log "Adding host list to $vmName..." "INFO"
add_host_list "$vmName" "$hostListPath"

# Install Kubectl
write_log "Installing Kubectl on $vmName..." "INFO"
install_kubectl "$vmName"

# Copy K3s Config
write_log "Copying K3s configuration from $masterVmName to $vmName..." "INFO"
copy_k3s_config "$masterVmName" "$vmName" "$k3sConfigFile" "$localTempPath" "$remoteTempPath" $use_scp

# Install Helm
write_log "Installing Helm on $vmName..." "INFO"
install_helm "$vmName"

# Update .bashrc
write_log "Updating .bashrc on $vmName..." "INFO"
update_bashrc "$vmName"

# Copy Installation Script
write_log "Copying installation script to $vmName..." "INFO"
copy_install_script "$vmName" "$localScriptPath"

write_log "$vmName VM setup completed successfully" "INFO"
