#!/bin/bash

# Check if the necessary parameters are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <baseName>"
    exit 1
fi

baseName=$1
start=1
end=9

# Loop through each worker node
for ((i=start; i<=end; i++)); do
    nodeName="${baseName}-worker${i}"

    # Check if the node exists
    if ! multipass list | grep -q "$nodeName"; then
        echo "Node $nodeName not found. Skipping to the next node."
        continue
    fi

    # Stop the k3s-agent service on the worker node
    multipass exec "$nodeName" -- sudo systemctl stop k3s-agent
    echo "Stopped k3s-agent on $nodeName."

    # Stop the Multipass VM
    multipass stop "$nodeName"
    echo "$nodeName VM stopped."
done

echo "Completed stopping all worker nodes."
