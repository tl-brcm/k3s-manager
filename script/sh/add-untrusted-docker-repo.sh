#!/bin/bash

# Check if the necessary parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <base-name> <registry-host> <registry-ip>"
    echo "Example: $0 max artifactory.k3s.demo 192.168.1.205"
    exit 1
fi

# Assign parameters to variables
baseName="$1"
registryHost="$2"
registryIP="$3"

# Range of your worker nodes
start=1
end=5

# The configuration to be applied
registriesConfig=$(cat <<EOF
mirrors:
  "$registryHost":
    endpoint:
      - "http://$registryHost"
EOF
)

# Loop through each worker node
for i in $(seq $start $end); do
    nodeName="${baseName}-worker$i"

    # Check if the node exists
    if ! multipass list | grep -q "$nodeName"; then
        echo "Node $nodeName not found. Stopping the script."
        exit 1
    fi

    # Copy the registries.yaml file to each worker node
    echo "$registriesConfig" | multipass transfer /dev/stdin $nodeName:/tmp/registries.yaml

    # Execute commands on the worker node
    multipass exec $nodeName -- bash -c "sudo mkdir -p /etc/rancher/k3s && sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml && sudo systemctl restart k3s-agent"

    # Add registry host to /etc/hosts
    multipass exec $nodeName -- sudo bash -c "echo '$registryIP $registryHost' >> /etc/hosts"
done

echo "Updated all worker nodes."
