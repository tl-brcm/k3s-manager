# K3s Worker Nodes Configuration Scripts

## Overview

These scripts are designed to automate the process of configuring K3s worker nodes in a cluster to trust an insecure Docker registry. This is particularly useful in environments where you are using a private or internal Docker registry with a self-signed certificate, or in a development setup where strict SSL verification is not required.

The scripts handle two main tasks:
1. Updating the `containerd` configuration on each K3s worker node to add the specified Docker registry as an insecure registry.
2. Adding a specific registry host and IP mapping to the `/etc/hosts` file on each worker node.

## Why is this Necessary?

In a K3s cluster, each worker node operates with its own container runtime (`containerd`). When pulling images from a Docker registry, `containerd` needs to trust the registry's SSL certificate. In cases where the registry's SSL certificate is not from a recognized Certificate Authority (CA) - such as with self-signed certificates - `containerd` will fail to pull images due to SSL verification failures.

By configuring each worker node to treat the registry as an insecure registry and mapping the registry hostname to the correct IP in `/etc/hosts`, these scripts allow K3s clusters to seamlessly pull images from such registries.

## Scripts

### 1. `update-nodes.sh` (Unix/Linux)

- **Purpose**: Configures K3s worker nodes to trust an insecure Docker registry.
- **Usage**:
  ```bash
  ./update-nodes.sh <base-name> <registry-host> <registry-ip>
  ```
  Example:
  ```bash
  ./update-nodes.sh max artifactory.k3s.demo 192.168.1.205
  ```

### 2. `Update-Nodes.ps1` (Windows)

- **Purpose**: Similar to `update-nodes.sh`, but for Windows environments.
- **Usage**:
  ```powershell
  .\Update-Nodes.ps1 -baseName "max" -registryHost "artifactory.k3s.demo" -registryIP "192.168.1.205"
  ```

## Requirements

- For `update-nodes.sh`: Bash shell, Multipass CLI.
- For `Update-Nodes.ps1`: PowerShell, Multipass CLI accessible in PowerShell.

## Security Considerations

Using insecure registries bypasses SSL/TLS verification, introducing potential security risks. It is recommended to use these scripts in controlled environments such as development or testing, and not in production.
