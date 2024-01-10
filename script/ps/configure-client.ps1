# import-k3s-client.ps1
Import-Module .\modules\MultipassUtils.psm1
Import-Module .\modules\LoggingUtils.psm1
Import-Module .\modules\K3sUtils.psm1

# Load configuration from JSON file
$configPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "..\..\config\config.json"
$configJson = Get-Content $configPath | ConvertFrom-Json

# Extract VM settings from the config
$vmSettings = $configJson.vmSettings.client
$vmName = $vmSettings.vmName
$cpuCores = $vmSettings.cpuCores
$ram = $vmSettings.ram
$disk = $vmSettings.disk
$vmIp = $vmSettings.vmIp

# Other configuration
$timeoutSeconds = $configJson.timeoutSeconds

# Define other variables
$scriptBaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$masterVmName = $configJson.vmSettings.master.vmName
$k3sConfigFile = "k3s.yaml"
$localTempPath = ".\temp\"
$localScriptPath = "..\sh\install_kubectx_kubens.sh"
$remoteTempPath = "/home/ubuntu/"
$hostListPath = Join-Path $scriptBaseDir "..\config\host_list"
$sshPubKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"

# Use functions from the module

Copy-K3sConfig -masterVmName $masterVmName -clientVmName $vmName -k3sConfigFile $k3sConfigFile -localTempPath $localTempPath -remoteTempPath $remoteTempPath


Write-Log "$vmName VM setup completed successfully"
