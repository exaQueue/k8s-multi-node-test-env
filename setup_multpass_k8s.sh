#!/bin/bash
# -----------------------------
# Config
# -----------------------------

K8S_CHANNEL="1.30"
K8S_VM_NAMES=("mk8s-1" "mk8s-2" "mk8s-3")
NFS_VM="nfs"
CPUS=2
MEM=4G
DISK=20G

# -----------------------------
# Clean install
# -----------------------------

if [ "$1" == "clean" ]; then
    for VM in "${K8S_VM_NAMES[@]}" $NFS_VM; do
        multipass stop $VM
        multipass delete $VM
    done
    multipass purge
fi


# -----------------------------
# Create NFS VM
# -----------------------------

multipass launch 24.04 --name "$NFS_VM" --cpus "$CPUS" --memory "$MEM" --disk "$DISK"
multipass exec "$NFS_VM" -- sudo apt-get update
multipass exec "$NFS_VM" -- sudo apt install -y nfs-kernel-server
multipass exec "$NFS_VM" -- sudo systemctl enable nfs-server
multipass exec "$NFS_VM" -- sudo systemctl start nfs-server
multipass exec "$NFS_VM" -- bash -c 'sudo mkdir -p /exports/slurm && sudo chown nobody:nogroup /exports/slurm'
multipass exec "$NFS_VM" -- sudo bash -c "echo '/exports/slurm *(rw,sync,no_subtree_check,no_root_squash)'>>/etc/exports"
multipass exec "$NFS_VM" -- sudo exportfs -rav
multipass exec "$NFS_VM" -- sudo ufw allow nfs

# -----------------------------
# Create VMs
# -----------------------------

echo "Creating Multipass VMs..."
for VM in "${K8S_VM_NAMES[@]}"; do
    if ! multipass list | grep $VM 2>&1 1>/dev/null;  then
        multipass launch 24.04 --name "$VM" --cpus "$CPUS" --memory "$MEM" --disk "$DISK"
    fi
done

# -----------------------------
# Install MicroK8s and other software on each node
# -----------------------------

echo "Installing MicroK8s..."
for VM in "${K8S_VM_NAMES[@]}"; do
    multipass exec "$VM" -- sudo snap install microk8s --classic --channel="$K8S_CHANNEL"
    multipass exec "$VM" -- sudo usermod -aG microk8s ubuntu
    multipass exec "$VM" -- sudo apt install nfs-common -y
    multipass exec "$VM" -- microk8s enable ha-cluster
    multipass exec "$VM" -- microk8s enable hostpath-storage
done

# -----------------------------
# Wait for MicroK8s to be ready
# -----------------------------

echo "Waiting for MicroK8s on primary..."
multipass exec mk8s-1 -- microk8s status --wait-ready

# -----------------------------
# Initialize cluster
# -----------------------------

echo "Join command: $JOIN_CMD"

for VM in "${K8S_VM_NAMES[@]:1}"; do
    echo "Generating join command..."
    JOIN_CMD=$(multipass exec mk8s-1 -- microk8s add-node | grep "microk8s join" | head -n1)
    echo "Joining $VM..."
    multipass exec "$VM" -- sudo $JOIN_CMD
done

# -----------------------------
# Add hosts file to each
# -----------------------------

mapfile -t lines < <(
    multipass list --format json \
        | jq -r '.list[] | "\(.ipv4[0]) \(.name)"'
)
for line in "${lines[@]}"; do
    for VM in "${K8S_VM_NAMES[@]}" $NFS_VM; do
        multipass exec $VM -- sudo bash -c "echo '$line' | tee -a /etc/hosts"
    done
done

# -----------------------------
# Export kubeconfig
# -----------------------------

echo "Exporting kubeconfig..."
multipass exec mk8s-1 -- microk8s config > kubeconfig
echo "KUBECONFIG saved to ./kubeconfig"
echo "Run: export KUBECONFIG=$(pwd)/kubeconfig"

echo "Cluster ready!"
