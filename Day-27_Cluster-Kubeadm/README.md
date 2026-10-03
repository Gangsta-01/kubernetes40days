# Kubernetes Cluster Installation

Kubernetes cluster built on VMware ESXi using Ubuntu 24.04.5 LTS.

## Cluster Configuration

- Kubernetes: `v1.36.5`
- Containerd: `2.3.6`
- Calico: `v3.32.0`
- Pod CIDR: `192.168.0.0/16`
- Service CIDR: `10.96.0.0/12`
- Control Plane: `10.0.0.107`
- Worker 01: `10.0.0.104`
- Worker 02: `10.0.0.105`

## Installation

Configure the three VMs with the following hostnames/IPs:

```text
k8s-control   10.0.0.107
worker-01     10.0.0.104
worker-02     10.0.0.105
```

Run the installation script on **all three nodes**:

```bash
chmod +x install-kubernetes.sh
./install-kubernetes.sh
```

The script prepares Ubuntu, disables swap, configures kernel networking, installs containerd, CNI plugins, kubeadm, kubelet and kubectl.

When executed on `k8s-control`, it additionally:

1. Initializes the Kubernetes control plane.
2. Configures kubectl.
3. Installs Calico.
4. Prints the `kubeadm join` command.

Run the printed `kubeadm join` command on `worker-01` and `worker-02`.

## Verify Cluster

From `k8s-control`:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get daemonset -n kube-system
```

Expected nodes:

```text
k8s-control   Ready
worker-01     Ready
worker-02     Ready
```

Expected networking:

```text
calico-node                 3/3
calico-kube-controllers     Running
```

## Test Workload

```bash
kubectl create namespace nginx-app

kubectl create deployment nginx \
  --image=nginx:latest \
  --replicas=2 \
  -n nginx-app

kubectl get pods -n nginx-app -o wide
```

Both Pods should become `Running` and receive Pod IPs from:

```text
192.168.0.0/16
```