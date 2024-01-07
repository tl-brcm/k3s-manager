#!/bin/bash
source modules/LoggingUtils.sh
source modules/MultipassUtils.sh
# Function to Copy K3s Configuration
# Function to Copy File from VM to Local Machine

copy_k3s_config() {
    local master_vm_name=$1
    local client_vm_name=$2
    local k3s_config_file=$3
    local local_temp_path=$4
    local remote_temp_path=$5
    local is_use_scp=${6:-false}

    write_log "Transferring k3s configuration..."
    ssh-keygen -f "/home/tony/.ssh/known_hosts" -R "$master_vm_name"

    [[ ! -d $local_temp_path ]] && mkdir -p $local_temp_path

    # Copy and modify file on the master VM
    execute_on_vm "$master_vm_name" "sudo cp /etc/rancher/k3s/k3s.yaml $remote_temp_path$k3s_config_file && sudo chmod 644 $remote_temp_path$k3s_config_file" "$is_use_scp"

    # Transfer file from master VM to local
    copy_file_from_vm "$remote_temp_path$k3s_config_file" "$local_temp_path$k3s_config_file" "$master_vm_name" "$is_use_scp"

    # Transfer file from local to client VM
    copy_file_to_vm "$local_temp_path$k3s_config_file" "/home/ubuntu/$k3s_config_file" "$client_vm_name"

    # Modify file on the client VM
    execute_on_vm "$client_vm_name" "sudo sed -i 's/127.0.0.1/k3s-master/' /home/ubuntu/$k3s_config_file && sudo mkdir -p /home/ubuntu/.kube && sudo mv /home/ubuntu/$k3s_config_file /home/ubuntu/.kube/config && sudo chmod 600 /home/ubuntu/.kube/config"

    # Clean up the temporary file on the master VM
    execute_on_vm "$master_vm_name" "sudo rm $remote_temp_path$k3s_config_file" "$is_use_scp"

    # Clean up the local temporary file
    rm -f "$local_temp_path$k3s_config_file"
    write_log "Local copy of k3s.yaml removed for security."
}


copy_k3s_config_as_slave() {
    local master_vm_name=$1
    local client_vm_name=$2
    local k3s_config_file=$3
    local local_temp_path=$4
    local remote_temp_path=$5

    write_log "Transferring k3s configuration..."

    if [[ ! -d $local_temp_path ]]; then
        mkdir -p $local_temp_path
    fi


    multipass exec "$master_vm_name" -- sudo bash -c "cp /etc/rancher/k3s/k3s.yaml $remote_temp_path$k3s_config_file && chmod 644 $remote_temp_path$k3s_config_file"
    
    multipass transfer "$master_vm_name:$remote_temp_path$k3s_config_file" "$local_temp_path$k3s_config_file"
    
    multipass transfer "$local_temp_path$k3s_config_file" "${client_vm_name}:/home/ubuntu/$k3s_config_file"

    multipass exec "$client_vm_name" -- sudo sed -i 's/127.0.0.1/k3s-master/' "/home/ubuntu/$k3s_config_file"
    multipass exec "$client_vm_name" -- sudo bash -c "mkdir -p /home/ubuntu/.kube && mv /home/ubuntu/$k3s_config_file /home/ubuntu/.kube/config && chmod 600 /home/ubuntu/.kube/config"
    
    multipass exec "$master_vm_name" -- sudo rm "$remote_temp_path$k3s_config_file"
    rm -f "$local_temp_path$k3s_config_file"
    write_log "Local copy of k3s.yaml removed for security."
}

# Function to Install Kubectl
install_kubectl() {
    local vm_name=$1
    write_log "Updating and installing required packages for $vm_name..."
    
    multipass exec "$vm_name" -- sudo apt-get update
    multipass exec "$vm_name" -- sudo apt-get install -y apt-transport-https ca-certificates curl
    multipass exec "$vm_name" -- sudo bash -c "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    multipass exec "$vm_name" -- sudo bash -c "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
    multipass exec "$vm_name" -- sudo apt-get update
    multipass exec "$vm_name" -- sudo apt-get install -y kubectl
}

# Function to Install Helm
install_helm() {
    local vm_name=$1
    write_log "Installing Helm..."
    multipass exec "$vm_name" -- bash -c "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh"
}

# Function to Update .bashrc
update_bashrc() {
    local vm_name=$1
    local bashrc_content="export KUBECONFIG=~/.kube/config
source <(kubectl completion bash)
alias k='kubectl'
complete -o default -F __start_kubectl k
alias h='helm'
source <(helm completion bash)
complete -o default -F __start_helm h
alias ks=kubens
alias kx=kubectx"

    write_log "Updating .bashrc for kubectl and Helm..."
    multipass exec "$vm_name" -- bash -c "echo '$bashrc_content' >> ~/.bashrc"
}

# Function to Copy Installation Script
copy_install_script() {
    local vm_name=$1
    local local_script_path=$2
    write_log "Transferring the script to the VM..."
    multipass transfer "$local_script_path" "${vm_name}:/home/ubuntu/install_kubectx_kubens.sh"
    write_log "Executing the script inside the VM..."
    multipass exec "$vm_name" -- sudo bash /home/ubuntu/install_kubectx_kubens.sh
}

# Add more K3s related functions here if needed

# Function to Install K3s on Worker Node
install_k3s_worker() {
    local vm_name=$1
    local k3s_token=$2
    local k3s_node_ip=$3

    write_log "Installing K3s on worker node $vm_name..."
    # Create a temp script file
    temp_script="temp/install_k3s_$vm_name.sh"
    
    printf '#!/bin/bash\n' > "$temp_script"
    printf "curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master:6443 K3S_TOKEN=$k3s_token INSTALL_K3S_VERSION='v1.27.8+k3s2' K3S_NODE_IP='$k3s_node_ip' sh -s - --node-ip $k3s_node_ip" >> "$temp_script"
    printf '\n' >> "$temp_script"

    multipass transfer "$temp_script" "$vm_name:/home/ubuntu/install_k3s.sh"
    # Execute the script
    multipass exec "$vm_name" -- chmod +x /home/ubuntu/install_k3s.sh    
    sleep 20
    write_log "Wait for 20 secs for the VM to get ready..."
    multipass exec "$vm_name" -- bash -c "/home/ubuntu/install_k3s.sh"

    # Remove the local temp script file
    rm "$temp_script"
}

# Function to Get K3s Token from Master
get_k3s_token() {
    local master_vm_name=$1
    local is_use_scp=${2:-false}

    # Redirect log output to stderr
    write_log "Retrieving K3s token from master node..." >&2

    local token
    # Capture only stdout, assuming execute_on_vm writes only the necessary output to stdout
    token=$(execute_on_vm "$master_vm_name" "sudo cat /var/lib/rancher/k3s/server/node-token" "$is_use_scp")

    if [ -z "$token" ]; then
        write_log "Failed to retrieve K3s token from master node" >&2
        return 1
    fi

    echo "$token"
}


# Function to Get Cluster Node Status and Remove If Not Ready
get_cluster_node_status_and_remove_not_ready() {
    local node_name=$1
    local prefix=$2
    local client_vm_name="k3s-client"

    # Modify client VM name based on the prefix
    if [ -n "$prefix" ]; then
        client_vm_name="${prefix}-k3s-client"
    fi

    local node_info
    node_info=$(execute_on_vm "$client_vm_name" "kubectl get nodes --no-headers | grep '$node_name'")

    if [[ "$node_info" ]]; then
        if echo "$node_info" | grep -q "NotReady"; then
            write_log "Node $node_name is in NotReady state. Removing..."
            execute_on_vm "$client_vm_name" "kubectl delete node '$node_name'"
            execute_on_vm "$node_name" "sudo shutdown -h now" # Assuming a way to shutdown VMs safely
            # Additional commands to delete the VM from multipass if necessary
        elif echo "$node_info" | grep -q "Ready"; then
            write_log "Node $node_name is already in Ready state."
            echo "Ready"
        fi
    else
        write_log "Node $node_name is not part of the cluster."
        echo "NotExists"
    fi
}

find_next_worker_index() {
    local prefix=$1
    local client_vm_name="${prefix}-k3s-client"
    local max_index=0

    # Get the list of nodes, filter by prefix, extract the index, and find the maximum
    local nodes_output=$(execute_on_vm "$client_vm_name" "kubectl get nodes | grep '$prefix' | awk '{print \$1}' | sort -r")

    # Iterate through the node names to find the highest index
    for node_name in $nodes_output; do
        if [[ $node_name =~ ${prefix}-worker([0-9]+) ]]; then
            local current_index="${BASH_REMATCH[1]}"
            if (( current_index > max_index )); then
                max_index=$current_index
            fi
        fi
    done

    echo $((max_index + 1)) # Return the next index
}