#!/bin/bash

# Variables
PROJECT_ID="gke-ha-project"
REGION="us-east1"
CLUSTER_NAME="project-cluster"
VPC_NAME="project-vpc"
SUBNET_NAME="gke-subnet"

# Set project ID
gcloud config set project $PROJECT_ID

# Enable Compute and Container APIs
echo "Enabling GCP APIs..."
gcloud services enable container.googleapis.com compute.googleapis.com

# Create a VPC and subnet
echo "Creating VPC Network..."
gcloud compute networks create $VPC_NAME --subnet-mode=custom --bgp-routing-mode=regional

echo "Creating Subnet..."
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --range=10.10.0.0/24 \
  --region=$REGION

# Put together a Kubernetes cluster (TODO: Add more configuration)
echo "Creating GKE Cluster..."
gcloud container clusters create $CLUSTER_NAME \
  --region=$REGION \
  --network=$VPC_NAME \
  --subnetwork=$SUBNET_NAME \
  --disk-size=15GB \
  --machine-type=e2-small \
  --num-nodes=1 \
  --enable-autoscaling --min-nodes=3 --max-nodes=6 \
  --no-enable-insecure-kubelet-readonly-port

# Let the user know everything went well.
echo "Infrastructure setup complete!"
