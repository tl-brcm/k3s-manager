#!/bin/bash
# This script is to copy the keys from a remote physical host to the k3s master so that it can ssh and read the k3s key when installing. 
# Load modules
source ./modules/MultipassUtils.sh
source ./modules/LoggingUtils.sh
source modules/LoggingUtils.sh

sshPubKeyPath="$HOME/.ssh/id_rsa.pub"

# Append SSH public key to the VM's authorized_keys file
copy_ssh_key "$vmName" "$sshPubKeyPath"

# Remote host details
remoteHost="mini"
remoteUser="tony"

write_log "Fetching SSH public key from $remoteHost..."
sshPubKey=$(ssh $remoteUser@$remoteHost "cat ~/.ssh/id_rsa.pub")
if [ -z "$sshPubKey" ]; then
    echo "Failed to fetch SSH public key from $remoteHost"
    exit 1
fi

# Use the Copy-SSHKey function to append the fetched key
copy_ssh_key "$vmName" "" "$sshPubKey"
