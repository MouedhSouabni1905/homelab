# Installation
## Installing operating systems
For the laptop, any linux distribution will do and go through the installation normally, making sure you remove any graphical environment by the end. For the LePotato SBC it is trickier, because if you have no monitor then it's quite hard to get it working, but the simplest way is to look for "armbian lepotato" and download the official armbian image for the board, then write it to the microsd card using rpi-imager. Once it boots (simply connect it to the power plug and insert the microsd card, it boots alone, solid red and green with flickering blue means it booted correctly) you can ssh into it with the `root` user and `1234` as password, you can then proceed with the installation through the command line.
## Kubernetes tools
We need to install the kubernetes tools, for that we go through [the installation manual](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).
For some reason the certificate verification fails so in order to bypass it temporarily, add the `-o Acquire::https::Verify-Peer=false` option to any apt commands.
Then run this as root:
```bash
#!/bin/bash


# disable swap
swapoff -a
sed -ri "s/(.*)swap(.*)/#\1swap\2/g" /etc/fstab

# containerd installation
sudo apt install -y containerd

# containerd configuration
containerd config default > /etc/containerd/config.toml
sed -ri "s/^(.*)SystemdCgroup = false(.*)$/\1SystemdCgroup = true\2/g" /etc/containerd/config.toml
systemctl restart containerd

# Ensure kernel modules is activated
modprobe overlay
modprobe br_netfilter
echo overlay | sudo tee -a /etc/modules-load.d/k8s.conf
echo br_netfilter | sudo tee -a /etc/modules-load.d/k8s.conf
```
Refs:
- https://gitlab.com/xavki/kubernetes-tutorials-new-version/-/blob/main/045-kubeadm-master-init
- https://www.youtube.com/watch?v=quNfkAe00ZI
## Set up kubernetes cluster
- On the control plane node:
Run the following command (the addresses might change):
```
sudo kubeadm init --apiserver-advertise-address=192.168.50.1 --apiserver-cert-extra-sans=192.168.50.1 --node-name=yorozuya --pod-network-cidr=10.200.0.0/16 --service-cidr=10.201.0.0/16 --control-plane-endpoint=192.168.50.1
```
- On worker node:
First run this on the control plane: `kubeadm token create --print-join-command`
Then copy and paste the resulting command and run it on each worker node.

Kubernetes needs a CNI plugin to make Pod networking work, Calico is one of the common choices:
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
kubectl taint nodes yorozuya node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes yorozuya node-role.kubernetes.io/not-ready:NoSchedule-
kubectl taint nodes shinsengumi node-role.kubernetes.io/not-ready:NoSchedule-
```
For the last 3 commands, check with `kubectl get nodes <node-name> -o json | jq '.spec.taints'` and adapt accordingly it might not be exactly like this. 
Refs:
- https://www.perplexity.ai/search/9fc420ae-448f-427e-a517-04cc146dbbe1
