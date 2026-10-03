#!/bin/bash
set -e

K8S_VERSION="1.36.5-1.1"
CALICO_VERSION="v3.32.0"
POD_CIDR="192.168.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
CONTROL_IP="10.0.0.107"
NODE_IP=$(hostname -I | awk '{print $1}')

echo "=== Kubernetes Node Setup ==="

# Hostname resolution
sudo tee -a /etc/hosts >/dev/null <<EOF
10.0.0.107 k8s-control
10.0.0.104 worker-01
10.0.0.105 worker-02
EOF

# System preparation
sudo apt update
sudo apt upgrade -y
sudo swapoff -a
sudo sed -i.bak '/\sswap\s/ s/^/#/' /etc/fstab

# Kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Containerd
sudo apt install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

sudo systemctl enable --now containerd

# CNI plugins
CNI_VERSION="v1.9.1"
ARCH="amd64"

curl -L \
  "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" \
  -o /tmp/cni-plugins.tgz

sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz

# Kubernetes repository
sudo apt install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key |
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' |
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y \
  kubeadm=${K8S_VERSION} \
  kubelet=${K8S_VERSION} \
  kubectl=${K8S_VERSION}

sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable kubelet

echo "=== Base Kubernetes installation completed ==="

# Control-plane initialization
if [ "$NODE_IP" = "$CONTROL_IP" ]; then

cat <<EOF | sudo tee /etc/kubernetes/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: ${CONTROL_IP}
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.36.5
controlPlaneEndpoint: "${CONTROL_IP}:6443"
networking:
  podSubnet: "${POD_CIDR}"
  serviceSubnet: "${SERVICE_CIDR}"
apiServer:
  certSANs:
    - "${CONTROL_IP}"
    - "k8s-control"
EOF

sudo kubeadm config validate \
  --config /etc/kubernetes/kubeadm-config.yaml

sudo kubeadm config images pull \
  --config /etc/kubernetes/kubeadm-config.yaml

sudo kubeadm init \
  --config /etc/kubernetes/kubeadm-config.yaml

mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Install Calico
curl -fL \
  -o /tmp/calico.yaml \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

kubectl apply -f /tmp/calico.yaml

echo
echo "=============================================="
echo "Control plane initialized successfully."
echo "=============================================="
echo
echo "Run the following command on each worker:"
echo
kubeadm token create --print-join-command
echo

else

echo
echo "=============================================="
echo "Worker base installation completed."
echo "=============================================="
echo
echo "Run the kubeadm join command provided by the"
echo "control-plane installation."
echo

fi