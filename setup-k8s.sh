#!/bin/bash

# Install dependencies
sudo apt-get updatenv
sudo apt-get install -y kubectl
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
python websocket_server.py
