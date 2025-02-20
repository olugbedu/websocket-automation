#!/bin/bash

# Install dependencies
sudo apt-get 
sudo apt update && sudo apt install -y python3
sudo apt-get install -y python3-pip
pip3 install websockets
sudo apt-get install -y curl
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
minikube version
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
docker --version
sudo usermod -aG docker $USER && newgrp docker
minikube start --driver=docker
minikube status
kubectl get nodes
kubectl get pods --all-namespaces
python websocket_server.py
