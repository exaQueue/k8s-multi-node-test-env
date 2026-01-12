# K8s Multi-Node Test Environment

This repository contains a script to quickly set up a local multi-node Kubernetes cluster using [Multipass](https://multipass.run/) and [MicroK8s](https://microk8s.io/). It is designed for testing and development purposes.

## Features

- **Automated VM Provisioning:** Launches multiple Ubuntu 24.04 VMs using Multipass.
- **MicroK8s Cluster:** Installs and configures MicroK8s on all nodes and joins them into a high-availability (HA) cluster.
- **NFS Storage:** Sets up a dedicated VM as an NFS server and configures `nfs-common` on all Kubernetes nodes.
- **Networking:** Automatically updates `/etc/hosts` on all VMs for easy node-to-node communication.
- **Kubeconfig Export:** Automatically generates and exports the cluster's `kubeconfig` to your local machine.

## Prerequisites

- [Multipass](https://multipass.run/install) installed.
- [jq](https://jqlang.github.io/jq/download/) installed (for processing Multipass output).
- Bash shell environment.

## Quick Start

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/k8s-multi-node-test-env.git
    cd k8s-multi-node-test-env
    ```

2.  **Run the setup script:**
    ```bash
    ./setup_multpass_k8s.sh
    ```

3.  **Configure kubectl:**
    Once the script finishes, it will save a `kubeconfig` file in the current directory.
    ```bash
    export KUBECONFIG=$(pwd)/kubeconfig
    ```

4.  **Verify the cluster:**
    ```bash
    kubectl get nodes
    ```

## Clean Up

To tear down the environment and delete all created VMs:

```bash
./setup_multpass_k8s.sh clean
```

## Configuration

You can modify the following variables at the top of `setup_multpass_k8s.sh` to suit your needs:

- `K8S_CHANNEL`: The MicroK8s snap channel (default: `1.30`).
- `K8S_VM_NAMES`: Names of the Kubernetes nodes.
- `CPUS`, `MEM`, `DISK`: Resource allocation for each VM.

## License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.
