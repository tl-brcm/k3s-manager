# PowerShell Script to Stop K3s Worker Nodes and Multipass VMs

param (
    [Parameter(Mandatory=$true)]
    [string]$baseName
)

$start = 1
$end = 9

# Loop through each worker node
for ($i = $start; $i -le $end; $i++) {
    $nodeName = "$baseName-worker$i"

    # Check if the node exists
    $nodeExists = multipass list | Select-String "$nodeName"
    if (-not $nodeExists) {
        Write-Host "Node $nodeName not found. Skipping to the next node."
        continue
    }

    # Stop the k3s-agent service on the worker node
    multipass exec $nodeName -- sudo systemctl stop k3s-agent
    Write-Host "Stopped k3s-agent on $nodeName."

    # Stop the Multipass VM
    multipass stop $nodeName
    Write-Host "$nodeName VM stopped."
}

Write-Host "Completed stopping all worker nodes."
