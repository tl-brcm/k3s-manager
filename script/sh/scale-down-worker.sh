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

client_vm_name=$prefix"-k3s-client"

# Determine the highest-numbered worker node
highest_index=$(find_next_worker_index "$prefix")
let "highest_index=highest_index-1" # Adjust index to the current highest node

if [ "$highest_index" -eq 0 ]; then
    write_log "No worker nodes found for scaling down."
    exit 0
fi

worker_base_name="${prefix}-worker"

node_name="${worker_base_name}${highest_index}"

# Draining the node (moving workloads away)
write_log "Draining node $node_name..."
execute_on_vm "$client_vm_name" "kubectl drain $node_name --ignore-daemonsets --delete-local-data"

# Deleting the node from the K3s cluster
write_log "Deleting node $node_name from the cluster..."
execute_on_vm "$client_vm_name" "kubectl delete node $node_name"

# Uninstalling K3s agent
write_log "Uninstalling K3s agent from $node_name..."
execute_on_vm "$node_name" "/usr/local/bin/k3s-agent-uninstall.sh"

# Deleting the VM
write_log "Deleting VM $node_name..."
multipass delete "$node_name"
multipass purge

write_log "Scaling down K3s cluster by removing node $node_name completed successfully."
