#!/bin/bash

# Source the logging utility script
source modules/LoggingUtils.sh

# Function to print usage
print_usage() {
    write_log "Usage: $0 <slave_name> <first_worker_ip>" "INFO"
    write_log "Example: $0 mini 192.168.1.221" "INFO"
}

# Function to add a host entry to /etc/hosts if it doesn't exist
add_host_entry() {
    local ip=$1
    local hostname=$2
    local host_entry="$ip $hostname"

    if ! grep -qw "$hostname" /etc/hosts; then
        echo "Adding $host_entry to /etc/hosts"
        echo "$host_entry" | sudo tee -a /etc/hosts > /dev/null
    else
        write_log "$host_entry already exists in /etc/hosts" "INFO"
    fi
}

# Function to add a host entry to the slave's host_list if it doesn't exist
add_to_slave_host_list() {
    local ip=$1
    local hostname=$2
    local host_entry="$ip $hostname"

    if ! grep -qw "$hostname" "$slave_host_list_path"; then
        echo "Adding $host_entry to $slave_host_list_path"
        # Check if the file is empty; if not, prepend a newline
        if [ -s "$slave_host_list_path" ]; then
            echo -e "\n$host_entry" >> "$slave_host_list_path"
        else
            echo "$host_entry" >> "$slave_host_list_path"
        fi
    else
        write_log "$host_entry already exists in $slave_host_list_path" "INFO"
    fi
}

scriptBaseDir=$(dirname "$(realpath "$0")")
config_template_path="$scriptBaseDir/../../config/config.json"
slave_config_dir="$scriptBaseDir/../../config/slaves/$1"
slave_config_path="$slave_config_dir/config.json"
slave_host_list_path="$slave_config_dir/host_list"

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    print_usage
    exit 1
fi

slave_name=$1
first_worker_ip=$2

# Write the prefix to the current_prefix file
current_prefix_path="$scriptBaseDir/../../config/current_prefix"
echo "$slave_name" > "$current_prefix_path"

# Validate IP address
if ! [[ $first_worker_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    write_log "Invalid IP address format." "ERROR"
    print_usage
    exit 1
fi

# Delete existing slave config directory if it exists
if [ -d "$slave_config_dir" ]; then
    write_log "Existing configuration for slave $slave_name found. Deleting..." "INFO"
    rm -rf "$slave_config_dir"
fi

# Create slave config directory if it doesn't exist
mkdir -p "$slave_config_dir"

# Read and modify the template config.json
if [ -f "$config_template_path" ]; then
    # Increment client IP
    original_client_ip=$(jq -r '.vmSettings.client.vmIp' "$config_template_path")
    client_ip=$(echo $original_client_ip | awk -F. -v OFS=. '{$4=$4+1;print}')
    
    jq --arg client_ip "$client_ip" --arg client_name "$slave_name-k3s-client" \
       '.vmSettings.client.vmIp = $client_ip |
        .vmSettings.client.vmName = $client_name' "$config_template_path" > "$slave_config_path"
else
    write_log "Template config.json not found at $config_template_path" "ERROR"
    exit 1
fi

# Generate host_list and update /etc/hosts
if [ -f "$scriptBaseDir/../../config/host_list" ]; then
    cp "$scriptBaseDir/../../config/host_list" "$slave_host_list_path"
    master_ip=$(jq -r '.vmSettings.master.vmIp' "$config_template_path")
    master_name=$(jq -r '.vmSettings.master.vmName' "$config_template_path")
    add_host_entry "$master_ip" "$master_name"

    add_host_entry "$client_ip" "$slave_name-k3s-client"

    for i in $(seq 0 8); do
        worker_ip=$(echo $first_worker_ip | awk -F. -v OFS=. -v increment="$i" '{$4=$4+increment;print}')
        worker_name="$slave_name-worker$((i+1))"
        add_host_entry "$worker_ip" "$worker_name"
        add_to_slave_host_list "$worker_ip" "$worker_name" # Use the new function for slave host_list

    done
else
    write_log "Master host_list not found." "ERROR"
    exit 1
fi

write_log "Configuration for slave $slave_name generated successfully." "INFO"
