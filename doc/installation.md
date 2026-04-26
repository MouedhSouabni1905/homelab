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
After running the following command (the addresses might change):
```
sudo kubeadm init --apiserver-advertise-address=192.168.50.1 --apiserver-cert-extra-sans=192.168.50.1 --node-name=yorozuya --pod-network-cidr=10.200.0.0/16 --service-cidr=10.201.0.0/16 --control-plane-endpoint=192.168.50.1
```
You should see something like this at the end of the output:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join 192.168.50.1:6443 --token nehglv.wbnlrzszvhfzh0y1 \
	--discovery-token-ca-cert-hash sha256:6addf69a32b540d5eb624c7165c36039e193eb6a0e1951054958a86f33aa8e1a \
	--control-plane

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.50.1:6443 --token nehglv.wbnlrzszvhfzh0y1 \
	--discovery-token-ca-cert-hash sha256:6addf69a32b540d5eb624c7165c36039e193eb6a0e1951054958a86f33aa8e1a
```
- On worker node:

