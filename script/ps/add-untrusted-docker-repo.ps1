# PowerShell Script to Update K3s Worker Nodes

# Check if the necessary parameters are provided
param (
    [Parameter(Mandatory=$true)]
    [string]$baseName,

    [Parameter(Mandatory=$true)]
    [string]$registryHost,

    [Parameter(Mandatory=$true)]
    [string]$registryIP
)

$start = 1
$end = 9

# The configuration to be applied
$registriesConfig = @"
mirrors:
  "$registryHost":
    endpoint:
      - "http://$registryHost"
"@

# Loop through each worker node
for ($i = $start; $i -le $end; $i++) {
    $nodeName = "$baseName-worker$i"

    # Check if the node exists
    $nodeExists = multipass list | Select-String "$nodeName"
    if (-not $nodeExists) {
        Write-Host "Node $nodeName not found. Stopping the script."
        exit
    }

    # Copy the registries.yaml file to each worker node
    $registriesConfig | Set-Content "registries.yaml"
    multipass transfer "registries.yaml" "${nodeName}:/tmp/registries.yaml"
    Remove-Item "registries.yaml" -Force

    # Execute commands on the worker node
    multipass exec $nodeName -- bash -c "sudo mkdir -p /etc/rancher/k3s && sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml && sudo systemctl restart k3s-agent"

    # Add registry host to /etc/hosts
    multipass exec $nodeName -- sudo bash -c "echo '$registryIP $registryHost' >> /etc/hosts"
}

Write-Host "Updated all worker nodes."
