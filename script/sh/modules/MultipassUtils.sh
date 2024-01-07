#!/bin/bash
source modules/LoggingUtils.sh
# Function to Test VM Existence
test_vm_existence() {
    local vm_name=$1
    if multipass list | grep -q "$vm_name"; then
        write_log "A VM with the name '$vm_name' already exists. Exiting script."
        exit 1
    fi
}

# Function to Start VM
start_vm() {
    local vm_name=$1
    local cpu_cores=$2
    local ram=$3
    local disk=$4
    write_log "Launching $vm_name VM..."
    multipass launch -n "$vm_name" -c "$cpu_cores" -m "$ram" -d "$disk" --network name=br0,mode=manual --cloud-init ../../config/user-data.yaml
}

# Function to Set Network Configuration
set_network_configuration() {
    local vm_name=$1
    local vm_ip=$2
    write_log "Configuring network settings for $vm_name..."
    multipass exec "$vm_name" -- sudo bash -c "echo 'network:
      version: 2
      ethernets:
        enp6s0:
          dhcp4: no
          addresses: [$vm_ip/24]
          nameservers:
            addresses: [8.8.8.8, 8.8.4.4]' > /etc/netplan/11-bridge.yaml"
}

# Function to Invoke Network Settings Application
invoke_network_settings_application() {
    local vm_name=$1
    local timeout_seconds=$2
    write_log "Applying network settings with a timeout of $timeout_seconds seconds..."
    multipass exec "$vm_name" -- sudo netplan apply
}

# Function to Copy SSH Key
copy_ssh_key() {
    local vm_name=$1
    local ssh_pub_key_path=$2
    local ssh_pub_key=$3

    if [[ -z "$ssh_pub_key" && -f "$ssh_pub_key_path" ]]; then
        ssh_pub_key=$(cat "$ssh_pub_key_path")
    fi

    if [[ -n "$ssh_pub_key" ]]; then
        write_log "Appending SSH public key to $vm_name's authorized_keys file..."
        multipass exec "$vm_name" -- sudo bash -c "echo '$ssh_pub_key' >> /home/ubuntu/.ssh/authorized_keys"
    else
        write_log "SSH public key not found or not provided"
    fi
}

# Function to Install K3s
install_k3s() {
    local vm_name=$1
    local k3s_version=$2
    local vm_ip=$3
    write_log "Installing K3s on $vm_name..."
    multipass exec "$vm_name" -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='$k3s_version' K3S_NODE_IP='$vm_ip' sh -s - --disable=traefik --node-ip $vm_ip"
}

# Function to Add Host List
add_host_list() {
    local vm_name=$1
    local host_list_path=$2
    if [[ -f "$host_list_path" ]]; then
        local host_list_content=$(cat "$host_list_path")
        write_log "Appending content to /etc/hosts in $vm_name..."
        multipass exec "$vm_name" -- sudo bash -c "echo '$host_list_content' >> /etc/hosts"
    else
        write_log "Host list file not found at $host_list_path"
    fi
}


copy_file_from_vm() {
    local source=$1
    local destination=$2
    local vm_name=$3
    local use_scp=$4

    if [[ "$use_scp" == true ]]; then
        scp ubuntu@"$vm_name":"$source" "$destination"
    else
        multipass transfer "$vm_name:$source" "$destination"
    fi
}

# Function to Copy File from Local Machine to VM
copy_file_to_vm() {
    local source=$1
    local destination=$2
    local vm_name=$3
    local use_scp=$4

    if [[ "$use_scp" == true ]]; then
        scp "$source" ubuntu@"$vm_name":"$destination"
    else
        multipass transfer "$source" "$vm_name:$destination"
    fi
}

execute_on_vm() {
    local vm_name=$1
    local command=$2
    local use_scp=$3

    if [[ "$use_scp" == true ]]; then
        ssh ubuntu@"$vm_name" "${command}"
    else
        multipass exec "$vm_name" -- bash -c "${command}"
    fi
}