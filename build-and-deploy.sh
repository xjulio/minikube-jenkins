#!/bin/bash

DIR=$(pwd)
NS=jenkins

minikube status > /dev/null 2>&1

if [ $? -ne 0 ]; then
	minikube start
fi


# Create namespace
kubectl describe namespace $NS > /dev/null 2>&1
if [ $? -ne 0 ]; then
	kubectl create namespace $NS
fi

#Build Jenkins custom image
docker image build . -t jenkins:custom

# create jenkins deployment and service
kubectl apply -f services/jenkins.yml