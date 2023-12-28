#!/bin/bash

# Import necessary modules
source ./modules/MultipassUtils.sh
source ./modules/LoggingUtils.sh
source ./modules/K3sUtils.sh

scriptBaseDir=$(dirname "$(realpath "$0")")

# Read the prefix from the current_prefix file
current_prefix_path="$scriptBaseDir/../../config/current_prefix"
if [ -f "$current_prefix_path" ]; then
    prefix=$(cat "$current_prefix_path")
else
    write_log "No current_prefix file found." "ERROR"
    exit 1
fi

# Set the slave directory based on the prefix
slave_dir="$scriptBaseDir/../../config/slaves/$prefix"
if [ ! -d "$slave_dir" ]; then
    write_log "No configuration directory found for prefix $prefix." "ERROR"
    exit 1
fi

configPath="$slave_dir/config.json"
host_list_path="$slave_dir/host_list"

# Load configuration from JSON file
config_json=$(jq '.' "$configPath")

# Extract Worker Node Settings from the config
worker_settings=$(echo "$config_json" | jq '.vmSettings.worker')
default_cpu_cores=$(echo "$worker_settings" | jq -r '.defaultCpuCores')
default_ram=$(echo "$worker_settings" | jq -r '.defaultRam')
default_disk=$(echo "$worker_settings" | jq -r '.defaultDisk')
worker_base_name="${prefix}-worker" # Using the prefix for the base name
worker_start_index=1
timeout_seconds=$(echo "$config_json" | jq -r '.timeoutSeconds')
worker_count=${1:-1} # Default worker count is 1 if not provided as the first argument

# Retrieve K3s Token
k3s_token=$(get_k3s_token "k3s-master" true)

# Find the next worker index
worker_start_index=$(find_next_worker_index "$prefix")

# Scaling Out Worker Nodes
for ((i = worker_start_index; i < worker_start_index + worker_count; i++)); do
    worker_name="${worker_base_name}${i}"

    # Check node status and remove if 'NotReady'
    node_status=$(get_cluster_node_status_and_remove_not_ready "$worker_name" "$prefix")
    if [[ "$node_status" == "Ready" ]]; then
        continue
    fi

    # Extracting IP address for the worker node from the host list file
    worker_entry=$(grep "$worker_name" "$host_list_path")
    if [[ -z "$worker_entry" ]]; then
        write_log "IP address for $worker_name not found in host list"
        exit 1
    fi

    worker_ip=$(echo "$worker_entry" | awk '{print $1}')

    # Launch Worker Node
    start_vm "$worker_name" "$default_cpu_cores" "$default_ram" "$default_disk"
    set_network_configuration "$worker_name" "$worker_ip"
    invoke_network_settings_application "$worker_name" "$timeout_seconds"

    # Install K3s on Worker Node
    install_k3s_worker "$worker_name" "$k3s_token" "$worker_ip"
   
    write_log "Worker node $worker_name is successfully in the ready state."
done

write_log "Scaling out K3s cluster with worker nodes completed successfully"
