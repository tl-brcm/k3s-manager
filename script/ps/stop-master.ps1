# PowerShell Script to Stop K3s Master Node

$masterNodeName = "k3s-master"

# Check if the master node exists
$nodeExists = multipass list | Select-String "$masterNodeName"
if (-not $nodeExists) {
    Write-Host "Master node $masterNodeName not found. Exiting the script."
    exit
}

# Stop the k3s service on the master node
multipass exec $masterNodeName -- sudo systemctl stop k3s

Write-Host "Stopped k3s service on $masterNodeName."

# Stop the Multipass VM for the master node
multipass stop $masterNodeName

Write-Host "$masterNodeName VM stopped."

Write-Host "K3s master node stopped successfully."
