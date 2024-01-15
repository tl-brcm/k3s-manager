# K3s Cluster Management with Multipass

This repository contains a collection of scripts for managing a Kubernetes (K3s) cluster using Multipass. It includes both PowerShell scripts for Windows and Bash shell scripts for Ubuntu, allowing for easy scaling, setup, and teardown of K3s clusters on different platforms.

## Prerequisites

Before using these scripts, ensure the following prerequisites are met:

### Windows Users

- **Hyper-V**: Ensure Hyper-V is enabled on your system. Hyper-V is required for Multipass to create virtual machines on Windows.
- **External Network in Hyper-V**: Create an external network named `br0` in Hyper-V. This network is used by the VMs for external connectivity.

### Ubuntu Users

- **LXD**: Install and configure LXD as the driver for Multipass. LXD is required for Multipass to create virtual machines on Ubuntu.
- **Network Bridge**: Create a network bridge called `br0` and bind it to your main network interface. This bridge is necessary for the VMs to connect to your network.

- **Multipass**: Install Multipass on your system. Multipass is used to manage the virtual machines that will run the K3s nodes. You can download it from [Multipass website](https://multipass.run/).

- **LAN IP Range**: This setup assumes that devices in your LAN use the IP range `192.168.1.x`. Ensure that this is consistent with your network configuration.

## Overview

The scripts are designed to manage a K3s cluster comprising a master node, a client node, and multiple worker nodes. They handle tasks such as setting up VMs, installing K3s, scaling the number of worker nodes up and down, and cleaning up the environment.

## Initial Setup

Before starting, run the `init-env.sh` script on Ubuntu or `init-env.ps1` script on Windows. These scripts will create necessary configuration files and the `current_prefix` file, which are used in subsequent operations.

## Modules

- `MultipassUtils`: Contains utility functions for managing VMs with Multipass.
- `LoggingUtils`: Provides logging functionalities.
- `K3sUtils`: Includes functions specific to K3s operations.

## Scripts

1. `init-master.(ps1|sh)`: Sets up the K3s master node.
2. `init-client.(ps1|sh)`: Sets up the K3s client node.
3. `scale-out-worker.(ps1|sh)`: Scales out the cluster by adding worker nodes.
4. `scale-down-worker.(ps1|sh)`: Scales down the cluster by removing worker nodes.
5. `cleanup-cluster.(ps1|sh)`: Uninstalls K3s from the nodes and deletes their VMs.

## Configuration

Configuration settings are managed through a `config.json` file and `current_prefix` file. The `config.json` specifies VM settings for the master, client, and worker nodes, while `current_prefix` holds the active prefix for node naming.

Example `config.json`:

```json
{
    "vmSettings": {
        "master": {
            "vmName": "k3s-master",
            "cpuCores": 4,
            "ram": "8G",
            "disk": "40G",
            "vmIp": "192.168.1.210"
        },
        "client": {
            "vmName": "k3s-client",
            "cpuCores": 1,
            "ram": "2G",
            "disk": "10G",
            "vmIp": "192.168.1.251"
        },
        "worker": {
            "defaultCpuCores": 2,
            "defaultRam": "4G",
            "defaultDisk": "10G"
        }
    },
    "k3sVersion": "v1.27.8+k3s2",
    "timeoutSeconds": 60
}
```
