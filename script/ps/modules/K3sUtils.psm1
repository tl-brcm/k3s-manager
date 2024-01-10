function Copy-K3sConfig {
    param ($masterVmName, $clientVmName, $k3sConfigFile, $localTempPath, $remoteTempPath)
    Write-Host "Transferring k3s configuration..."

    if (-not (Test-Path -Path $localTempPath)) {
        New-Item -ItemType Directory -Path $localTempPath
    }

    & multipass exec $masterVmName -- sudo bash -c "cp /etc/rancher/k3s/k3s.yaml $remoteTempPath$k3sConfigFile && chmod 644 $remoteTempPath$k3sConfigFile"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to copy k3s.yaml to a user-accessible location on $masterVmName"
        exit $LASTEXITCODE
    }

    & multipass transfer ${masterVmName}:$remoteTempPath$k3sConfigFile $localTempPath$k3sConfigFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to transfer k3s.yaml from $masterVmName to local system"
        exit $LASTEXITCODE
    }

    & multipass transfer $localTempPath$k3sConfigFile ${clientVmName}:/home/ubuntu/$k3sConfigFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to transfer k3s.yaml to $clientVmName"
        exit $LASTEXITCODE
    }

    & multipass exec $clientVmName -- sudo sed -i 's/127.0.0.1/k3s-master/' /home/ubuntu/$k3sConfigFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to update k3s.yaml on $clientVmName"
        exit $LASTEXITCODE
    }

    & multipass exec $clientVmName -- sudo bash -c "mkdir -p /home/ubuntu/.kube && mv /home/ubuntu/$k3sConfigFile /home/ubuntu/.kube/config && chmod 600 /home/ubuntu/.kube/config"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to move k3s.yaml to /home/ubuntu/.kube/config on $clientVmName"
        exit $LASTEXITCODE
    }

    & multipass exec $masterVmName -- sudo rm $remoteTempPath$k3sConfigFile
    Remove-Item -Path $localTempPath$k3sConfigFile -Force
    Write-Host "Local copy of k3s.yaml removed for security."
}

function Install-Kubectl {
    param ($vmName)
    Write-Host "Updating and installing required packages for $vmName..."
    
    & multipass exec -n $vmName -- sudo apt-get update
    & multipass exec -n $vmName -- sudo apt-get install -y apt-transport-https ca-certificates curl
    & multipass exec -n $vmName -- sudo bash -c "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    & multipass exec -n $vmName -- sudo bash -c "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
    & multipass exec -n $vmName -- sudo apt-get update
    & multipass exec -n $vmName -- sudo apt-get install -y kubectl

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to update and install packages on $vmName"
        exit $LASTEXITCODE
    }
}

function Install-Helm {
    param ($vmName)
    Write-Host "Installing Helm..."
    & multipass exec -n $vmName -- bash -c "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install Helm"
        exit $LASTEXITCODE
    }
}

function Update-Bashrc {
    param ($vmName)
    Write-Host "Updating .bashrc for kubectl and Helm..."
    $bashrcContent = @"
export KUBECONFIG=~/.kube/config
source <(kubectl completion bash)
alias k='kubectl'
complete -o default -F __start_kubectl k
alias h='helm'
source <(helm completion bash)
complete -o default -F __start_helm h
alias ks=kubens
alias kx=kubectx

#kubectx and kubens
export PATH=~/.kubectx:$PATH
# we need to source the path here. 
. ~/.kubectx/completion/kubens.bash
. ~/.kubectx/completion/kubectx.bash

complete -F _kube_namespaces ks
complete -F _kube_contexts kx

alias kp='kubectl get pods'
alias ka='kubectl get all'
alias kpa='kubectl get pods --all-namespaces'
alias kpaw='kubectl get pods --all-namespaces'
alias knw='kubectl get nodes -o wide'

"@
    & multipass exec -n $vmName -- bash -c "echo '$bashrcContent' >> ~/.bashrc"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to update .bashrc"
        exit $LASTEXITCODE
    }
}

function Copy-InstallScript {
    param ($vmName, $localScriptPath)
    Write-Host "Transferring the script to the VM..."
    & multipass transfer $localScriptPath ${vmName}:/home/ubuntu/install_kubectx_kubens.sh
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to transfer the script to the VM"
        exit $LASTEXITCODE
    }

    Write-Host "Executing the script inside the VM..."
    & multipass exec $vmName -- sudo bash /home/ubuntu/install_kubectx_kubens.sh
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to execute the script inside the VM"
        exit $LASTEXITCODE
    }
}


# Function to Install K3s on Worker Node
function Install-K3sWorker {
    param ($vmName, $k3sToken, $k3sNodeIp)
    Write-Log "Installing K3s on worker node $vmName..."
    & multipass exec -n $vmName -- sudo apt-get update
    & multipass exec -n $vmName -- sudo sudo apt install -y wireguard
    $installCmd = "curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master:6443 K3S_TOKEN=$k3sToken INSTALL_K3S_VERSION='v1.27.8+k3s2' sh -s - --node-external-ip $k3sNodeIp"
    & multipass exec $vmName -- bash -c $installCmd
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to install K3s on worker node $vmName"
        exit $LASTEXITCODE
    }
}

# Function to Get K3s Token from Master
function Get-K3sToken {
    param ($masterVmName)
    Write-Log "Retrieving K3s token from master node..."
    $token = & multipass exec $masterVmName -- sudo cat /var/lib/rancher/k3s/server/node-token
    if (-not $token) {
        Write-Log "Failed to retrieve K3s token from master node"
        exit 1
    }
    return $token
}


function Get-ClusterNodeStatus-And-Remove-NotReady {
    param (
        [Parameter(Mandatory = $true)]
        [string]$nodeName
    )

    $nodeInfo = & multipass exec k3s-client -- kubectl get nodes --no-headers | Where-Object { $_ -like "*$nodeName*" }
    if ($nodeInfo) {
        if ($nodeInfo -like "*NotReady*") {
            Write-Log "Node $nodeName is in NotReady state. Removing..."
            & multipass exec k3s-client -- kubectl delete node $nodeName
            & multipass delete $nodeName
            & multipass purge
            return "Removed"
        } elseif ($nodeInfo -like "*Ready*") {
            Write-Log "Node $nodeName is already in Ready state."
            return "Ready"
        }
    } else {
        Write-Log "Node $nodeName is not part of the cluster."
        return "NotExists"
    }
}

# Export functions
Export-ModuleMember -Function Copy-K3sConfig, Install-Kubectl, Install-Helm, Update-Bashrc, Copy-InstallScript, Install-K3sWorker, Get-K3sToken, Get-ClusterNodeStatus-And-Remove-NotReady
