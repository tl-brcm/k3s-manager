param (
    [int]$WorkerNumber
)

Import-Module .\modules\MultipassUtils.psm1
Import-Module .\modules\LoggingUtils.psm1
Import-Module .\modules\K3sUtils.psm1

# Read the current_prefix file to determine the workerBaseName
$currentPrefixPath = Join-Path -Path (Get-Location) -ChildPath "..\..\config\current_prefix"
$currentPrefix = Get-Content -Path $currentPrefixPath

# Variables
$workerBaseName = "$currentPrefix-worker"

# Get the list of current worker nodes
$workerNodes = & multipass exec k3s-client -- kubectl get nodes --no-headers | Where-Object { $_ -like "*$workerBaseName*" } | ForEach-Object { ($_ -split '\s+')[0] }

if ($workerNodes.Count -eq 0) {
    Write-Log "No worker nodes found for scaling down."
    exit 0
}

# Determine the worker node to delete
if ($WorkerNumber) {
    $nodeName = "$workerBaseName$WorkerNumber"
} else {
    # Determine the highest-numbered worker node
    $highestNumberedNode = $workerNodes | ForEach-Object {
        $nodeNumber = ($_ -split '\s+')[0] -replace "[^0-9]", ""
        [PSCustomObject]@{
            NodeName = $_
            NodeNumber = [int]$nodeNumber
        }
    } | Sort-Object -Property NodeNumber -Descending | Select-Object -First 1

    if ($highestNumberedNode -eq $null) {
        Write-Log "Failed to determine the highest-numbered worker node."
        exit 1
    }

    $nodeName = $highestNumberedNode.NodeName
}

# Check if the node exists before deleting
if ($nodeName -in $workerNodes) {
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
} else {
    Write-Log "Node $nodeName not found. No action taken."
}
