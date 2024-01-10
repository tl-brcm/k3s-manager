# PowerShell script to launch and configure k3s-master in Multipass
Import-Module .\modules\MultipassUtils.psm1 -Force
Import-Module .\modules\LoggingUtils.psm1

# Load configuration from JSON file
$configPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "..\..\config\config.json"
$configJson = Get-Content $configPath | ConvertFrom-Json

# Extract VM settings from the config
$vmSettings = $configJson.vmSettings.master
$vmName = $vmSettings.vmName
$cpuCores = $vmSettings.cpuCores
$ram = $vmSettings.ram
$disk = $vmSettings.disk
$vmIp = $vmSettings.vmIp
$k3sVersion = $configJson.k3sVersion
$timeoutSeconds = $configJson.timeoutSeconds

# Define other variables
$scriptBaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$hostListPath = Join-Path $scriptBaseDir "..\config\host_list"
$sshPubKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"

# Use functions from the module
Test-VMExistence -vmName $vmName
Start-VM -vmName $vmName -cpuCores $cpuCores -ram $ram -disk $disk
Set-NetworkConfiguration -vmName $vmName -vmIp $vmIp
Invoke-NetworkSettingsApplication -vmName $vmName -timeoutSeconds $timeoutSeconds
Install-K3s -vmName $vmName -k3sVersion $k3sVersion -vmIp $vmIp
Add-HostList -vmName $vmName -hostListPath $hostListPath

# Append SSH public key to the VM's authorized_keys file
Copy-SSHKey -vmName $vmName -sshPubKeyPath $sshPubKeyPath

# Remote host details
$remoteHost = "mini"
$remoteUser = "tony"

Write-Log "Fetching SSH public key from $remoteHost..."
$sshPubKey = ssh $remoteUser@$remoteHost "cat ~/.ssh/id_rsa.pub"
if (-not $sshPubKey) {
    Write-Host "Failed to fetch SSH public key from $remoteHost"
    exit 1
}

# Use the Copy-SSHKey function to append the fetched key
Copy-SSHKey -vmName $vmName -sshPubKey $sshPubKey
