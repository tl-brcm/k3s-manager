# PowerShell script to scale out k3s cluster with worker nodes

# Import necessary modules
$scriptBaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$modulesDir = Join-Path $scriptBaseDir "modules"  # Specify the correct path to your modules directory
Import-Module (Join-Path $modulesDir "MultipassUtils.psm1") -Force
Import-Module (Join-Path $modulesDir "K3sUtils.psm1") -Force
Import-Module (Join-Path $modulesDir "LoggingUtils.psm1") -Force

# Get the script name without extension
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)

# Function to print usage
function Print-Usage {
    Write-Host "Usage: $scriptName <number_of_workers>"
    Write-Host "Example: $scriptName 3"
}

# # Check if the correct number of arguments are provided
# if ($args.Count -ne 1) {
#     Print-Usage
#     exit 1
# }

# Retrieve the current prefix from the file
$currentPrefixPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "..\..\config\current_prefix"
$workerBaseName = Get-Content -Path $currentPrefixPath

# Paths to host list and config.json based on the current prefix
$hostListPath = Join-Path (Join-Path (Join-Path -Path $scriptBaseDir -ChildPath "..\..\config\slaves") $workerBaseName) "host_list"
$configPath = Join-Path (Join-Path (Join-Path -Path $scriptBaseDir -ChildPath "..\..\config\slaves") $workerBaseName) "config.json"

# Load configuration from JSON file
$configJson = Get-Content $configPath | ConvertFrom-Json
$workerSettings = $configJson.vmSettings.worker
$defaultCpuCores = $workerSettings.defaultCpuCores
$defaultRam = $workerSettings.defaultRam
$defaultDisk = $workerSettings.defaultDisk
$workerStartIndex = 1
$timeoutSeconds = $configJson.timeoutSeconds
$workerCount = $args[0] -as [int]
if (-not $workerCount -or $workerCount -le 0) { $workerCount = 1 }

# Retrieve K3s Token
$k3sToken = Get-K3sToken -masterVmName "k3s-master"

# Scaling Out Worker Nodes
for ($i = $workerStartIndex; $i -lt ($workerStartIndex + $workerCount); $i++) {
    $workerName = "$workerBaseName-worker$i"

    # If in 'NotReady' state, remove from cluster and try to remove VM, then continue to create a new one
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
