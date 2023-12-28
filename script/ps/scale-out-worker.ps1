# PowerShell script to scale out k3s cluster with worker nodes

# Import necessary modules
Import-Module .\modules\MultipassUtils.psm1
Import-Module .\modules\LoggingUtils.psm1
Import-Module .\modules\K3sUtils.psm1

# Load configuration from JSON file
$configPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "..\..\config\config.json"
$configJson = Get-Content $configPath | ConvertFrom-Json
$scriptBaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Extract Worker Node Settings from the config
$workerSettings = $configJson.vmSettings.worker
$defaultCpuCores = $workerSettings.defaultCpuCores
$defaultRam = $workerSettings.defaultRam
$defaultDisk = $workerSettings.defaultDisk
$workerBaseName = "worker"
$workerStartIndex = 1
$timeoutSeconds = $configJson.timeoutSeconds
$hostListPath = Join-Path $scriptBaseDir "..\..\config\host_list"
$workerCount = $args[0] -as [int]
if (-not $workerCount -or $workerCount -le 0) { $workerCount = 1 }

# Retrieve K3s Token
$k3sToken = Get-K3sToken -masterVmName "k3s-master"

# Scaling Out Worker Nodes
for ($i = $workerStartIndex; $i -lt ($workerStartIndex + $workerCount); $i++) {
    $workerName = "$workerBaseName$i"

    # If in 'NotReady' state, remove from cluster and try to remove VM, then continue to create new one
    $nodeStatus = Get-ClusterNodeStatus-And-Remove-NotReady -nodeName $workerName
    if ($nodeStatus -eq "Ready") {
        continue
    }

    # Extracting IP address for the worker node from the host list file
    $workerEntry = Get-Content $hostListPath | Where-Object { $_ -like "*$workerName" }
    if (-not $workerEntry) {
        Write-Log "IP address for $workerName not found in host list"
        exit 1
    }

    $workerIp = $workerEntry.Split(' ')[0].Trim()

    # Launch Worker Node
    Start-VM -vmName $workerName -cpuCores $defaultCpuCores -ram $defaultRam -disk $defaultDisk
    Set-NetworkConfiguration -vmName $workerName -vmIp $workerIp
    Invoke-NetworkSettingsApplication -vmName $workerName -timeoutSeconds $timeoutSeconds

    # Install K3s on Worker Node
    Install-K3sWorker -vmName $workerName -k3sToken $k3sToken -k3sNodeIp $workerIp
   
    Write-Log "Worker node $workerName is successfully in the ready state."
}

Write-Log "Scaling out K3s cluster with worker nodes completed successfully"
