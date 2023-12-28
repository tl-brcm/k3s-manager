# scale-down-worker.ps1
Import-Module .\modules\MultipassUtils.psm1
Import-Module .\modules\LoggingUtils.psm1
Import-Module .\modules\K3sUtils.psm1

# Variables
$workerBaseName = "worker"

# Get the list of current worker nodes
$workerNodes = & multipass exec k3s-client -- kubectl get nodes --no-headers | Where-Object { $_ -like "*$workerBaseName*" }

if ($workerNodes.Count -eq 0) {
    Write-Log "No worker nodes found for scaling down."
    exit 0
}

# Determine the highest-numbered worker node
$highestNumberedNode = $workerNodes | Sort-Object -Descending | Select-Object -First 1
$nodeName = ($highestNumberedNode -split '\s+')[0]

# Draining the node (moving workloads away)
Write-Log "Draining node $nodeName..."
& multipass exec k3s-client -- kubectl drain $nodeName --ignore-daemonsets --delete-local-data

# Deleting the node from the K3s cluster
Write-Log "Deleting node $nodeName from the cluster..."
& multipass exec k3s-client -- kubectl delete node $nodeName

# Uninstalling K3s agent
Write-Log "Uninstalling K3s agent from $nodeName..."
& multipass exec $nodeName -- /usr/local/bin/k3s-agent-uninstall.sh

# Deleting the VM
Write-Log "Deleting VM $nodeName..."
& multipass delete $nodeName
& multipass purge

Write-Log "Scaling down K3s cluster by removing node $nodeName completed successfully."
