param (
    [string]$SlaveName,
    [string]$FirstWorkerIp
)

# Function to print usage
function Print-Usage {
    Write-Host "Usage: $MyInvocation.MyCommand.Name <slave_name> <first_worker_ip>"
    Write-Host "Example: $MyInvocation.MyCommand.Name mini 192.168.1.221"
}

# Check if the correct number of arguments are provided
# if ($args.Count -ne 2) {
#     Print-Usage
#     exit 1
# }

# Get the script name without extension
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)

# Function to add a host entry to the slave's host_list if it doesn't exist
function Add-ToSlaveHostList {
    param (
        [string]$Ip,
        [string]$Hostname
    )

    $hostEntry = "$Ip $Hostname"

    if (Test-Path -Path $slaveHostListPath -PathType Leaf) {
        if (-not (Select-String -Path $slaveHostListPath -Pattern $Hostname -SimpleMatch)) {
            Write-Host "Adding $hostEntry to $slaveHostListPath"
            Add-Content -Path $slaveHostListPath -Value "`n$hostEntry"
        } else {
            Write-Host "$hostEntry already exists in $slaveHostListPath"
        }
    } else {
        Write-Host "$slaveHostListPath not found. Creating..."
        $hostEntry | Set-Content -Path $slaveHostListPath
    }
}

# Variables
$scriptBaseDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$configTemplatePath = Join-Path -Path $scriptBaseDir -ChildPath "..\..\config\config.json"
$slaveConfigDir = Join-Path -Path $scriptBaseDir -ChildPath "..\..\config\slaves\$SlaveName"
$slaveConfigPath = Join-Path -Path $slaveConfigDir -ChildPath "config.json"
$slaveHostListPath = Join-Path -Path $slaveConfigDir -ChildPath "host_list"

# Function to print usage
function Print-Usage {
    Write-Host "Usage: $scriptName <slave_name> <first_worker_ip>"
    Write-Host "Example: $scriptName mini 192.168.1.221"
}

# Write the prefix to the current_prefix file
$currentPrefixPath = Join-Path -Path $scriptBaseDir -ChildPath "..\..\config\current_prefix"
Set-Content -Path $currentPrefixPath -Value $SlaveName

# Validate IP address
if (-not ([System.Net.IPAddress]::TryParse($FirstWorkerIp, [ref]$null))) {
    Write-Host "Invalid IP address format."
    Print-Usage
    exit 1
}

# Delete existing slave config directory if it exists
if (Test-Path -Path $slaveConfigDir -PathType Container) {
    Write-Host "Existing configuration for slave $SlaveName found. Deleting..."
    Remove-Item -Path $slaveConfigDir -Recurse -Force
}

# Create slave config directory if it doesn't exist
mkdir $slaveConfigDir

# Read and modify the template config.json
if (Test-Path -Path $configTemplatePath -PathType Leaf) {
    $templateContent = Get-Content -Path $configTemplatePath | ConvertFrom-Json
    $originalClientIp = $templateContent.vmSettings.client.vmIp
    $clientIp = $FirstWorkerIp  # Use the provided IP for client

    $templateContent.vmSettings.client.vmIp = $clientIp
    $templateContent.vmSettings.client.vmName = "$SlaveName-k3s-client"

    $templateContent | ConvertTo-Json | Set-Content -Path $slaveConfigPath
} else {
    Write-Host "Template config.json not found at $configTemplatePath"
    exit 1
}

# Generate host_list and update hosts file
$ipParts = $FirstWorkerIp.Split('.')
$baseIp = $ipParts[0..2] -join '.'
$workerIp = $FirstWorkerIp  # Use the provided IP for the first worker

# Read and append content from ../../config/host_list
if (Test-Path -Path "$scriptBaseDir\..\..\config\host_list" -PathType Leaf) {
    $hostListContent = Get-Content -Path "$scriptBaseDir\..\..\config\host_list"
    Add-Content -Path $slaveHostListPath -Value $hostListContent
}

for ($i = 1; $i -le 9; $i++) {
    $workerName = "$SlaveName-worker$i"
    Add-ToSlaveHostList -Ip $workerIp -Hostname $workerName

    # Convert the last part of the IP to an integer, increment, and convert it back to a string
    $lastIpPart = [int]$ipParts[3] + $i
    $workerIp = "$baseIp.$lastIpPart"
}



Write-Host "Configuration for slave $SlaveName generated successfully."
