# uninstall-and-delete-k3s-master-client.ps1
Import-Module .\modules\MultipassUtils.psm1
Import-Module .\modules\LoggingUtils.psm1
Import-Module .\modules\K3sUtils.psm1

# VM Names
$masterVmName = "k3s-master"
$clientVmName = "k3s-client"

# Scale Down All Worker Nodes
$workerBaseName = "worker"
$workerNodes = & multipass exec k3s-client -- kubectl get nodes --no-headers | Where-Object { $_ -like "*$workerBaseName*" }

foreach ($node in $workerNodes) {
    $nodeName = ($node -split '\s+')[0]
    Write-Log "Draining and removing node $nodeName..."
    & multipass exec k3s-client -- kubectl drain $nodeName --ignore-daemonsets --delete-emptydir-data
    & multipass exec k3s-client -- kubectl delete node $nodeName
    & multipass exec $nodeName -- /usr/local/bin/k3s-agent-uninstall.sh
    & multipass delete $nodeName
}

& multipass purge
Write-Log "All worker nodes have been scaled down and removed."

# Uninstall K3s from Master
Write-Log "Uninstalling K3s from $masterVmName..."
& multipass exec $masterVmName -- sudo /usr/local/bin/k3s-uninstall.sh
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to uninstall K3s from $masterVmName"
}

# Delete Master VM
Write-Log "Deleting VM $masterVmName..."
& multipass delete $masterVmName
& multipass purge
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to delete VM $masterVmName"
}


# Delete Client VM
# Write-Log "Deleting VM $clientVmName..."
# & multipass delete $clientVmName
# & multipass purge
# if ($LASTEXITCODE -ne 0) {
#     Write-Log "Failed to delete VM $clientVmName"
# }

Write-Log "Uninstallation and deletion of k3s-master and k3s-client completed successfully."
