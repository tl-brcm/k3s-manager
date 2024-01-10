Import-Module modules\LoggingUtils.psm1

function Test-VMExistence {
    param ($vmName)
    $existingVMs = multipass list | Select-String $vmName
    if ($null -ne $existingVMs) {
        Write-Log "A VM with the name '$vmName' already exists. Exiting script."
        exit
    }
}

function Start-VM {
    param ($vmName, $cpuCores, $ram, $disk)
    Write-Log "Launching $vmName VM..."
    & multipass launch -n $vmName -c $cpuCores -m $ram -d $disk --network name=br0,mode=manual --cloud-init ../../config/user-data.yaml
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to launch $vmName VM"
        exit $LASTEXITCODE
    }
}

function Set-NetworkConfiguration {
    param ($vmName, $vmIp)
    Write-Log "Configuring network settings for $vmName..."
    $networkConfig = @"
network:
    version: 2
    ethernets:
        eth1:
            dhcp4: no
            addresses: [$vmIp/24]
"@
    & multipass exec -n $vmName -- sudo bash -c "cat << EOF > /etc/netplan/11-bridge.yaml
$networkConfig
EOF"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to configure network settings"
        exit $LASTEXITCODE
    }
}

function Invoke-NetworkSettingsApplication{
    param ($vmName, $timeoutSeconds)
    Write-Log "Applying network settings with a timeout of $timeoutSeconds seconds..."
    $startTime = Get-Date

    $job = Start-Job -ScriptBlock {
        multipass exec -n $args[0] -- sudo netplan apply
    } -ArgumentList $vmName

    do {
        Start-Sleep -Seconds 1
        $currentTime = Get-Date
        $elapsed = $currentTime - $startTime
        $job = Get-Job -Id $job.Id
    } while ($job.State -eq 'Running' -and $elapsed.TotalSeconds -lt $timeoutSeconds)

    if ($job.State -eq 'Running') {
        Write-Log "Command timed out. Proceeding to next step."
        Stop-Job -Id $job.Id
        Remove-Job -Id $job.Id
    } else {
        Write-Log "Command completed within timeout period."
        Receive-Job -Id $job.Id
        Remove-Job -Id $job.Id
    }
}

# Add the new function for copying the SSH key
function Copy-SSHKey {
    param (
        [Parameter(Mandatory = $true)]
        [string]$vmName,

        [Parameter(Mandatory = $false)]
        [string]$sshPubKeyPath,

        [Parameter(Mandatory = $false)]
        [string]$sshPubKey
    )

    if (-not $sshPubKey -and (Test-Path $sshPubKeyPath)) {
        $sshPubKey = Get-Content $sshPubKeyPath
    }

    if ($sshPubKey) {
        Write-Host "Appending SSH public key to $vmName's authorized_keys file..."
        & multipass exec $vmName -- sudo bash -c "echo '$sshPubKey' >> /home/ubuntu/.ssh/authorized_keys"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to append SSH public key to authorized_keys in $vmName"
            exit $LASTEXITCODE
        }
        Write-Host "SSH public key appended successfully to $vmName"
    } else {
        Write-Host "SSH public key not found or not provided"
    }
}


function Install-K3s {
    param ($vmName, $k3sVersion, $vmIp)
    Write-Log "Installing K3s on $vmName..."
    & multipass exec -n $vmName -- sudo apt-get update
    & multipass exec -n $vmName -- sudo sudo apt install -y wireguard
    & multipass exec $vmName -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='$k3sVersion' sh -s - --disable=traefik --node-external-ip=$vmIp --flannel-backend=wireguard-native --flannel-external-ip"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to install K3s on $vmName"
        exit $LASTEXITCODE
    }
}

function Add-HostList {
    param ($vmName, $hostListPath)
    if (Test-Path $hostListPath) {
        $hostListContent = Get-Content $hostListPath -Raw
        Write-Log "Appending content to /etc/hosts in $vmName..."
        & multipass exec $vmName -- sudo bash -c "echo '$hostListContent' >> /etc/hosts"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to append content to /etc/hosts in $vmName"
            exit $LASTEXITCODE
        }
    } else {
        Write-Log "Host list file not found at $hostListPath"
    }
}

# Export the new functions along with the existing ones
Export-ModuleMember -Function Test-VMExistence, Start-VM, Set-NetworkConfiguration, Invoke-NetworkSettingsApplication, Copy-SSHKey, Install-K3s, Add-HostList
