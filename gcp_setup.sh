#!/bin/bash

# Configuration variables
PROJECT_ID="gke-ha-testing"
REGION="us-east1"
CLUSTER_NAME="project-cluster"
VPC_NAME="project-vpc"
SUBNET_NAME="gke-subnet"

# Set project context
gcloud config set project $PROJECT_ID

# Enable necessary APIs
echo "Enabling GCP APIs..."
gcloud services enable container.googleapis.com compute.googleapis.com file.googleapis.com

# Create VPC and subnet
echo "Creating VPC Network..."
gcloud compute networks create $VPC_NAME --subnet-mode=custom --bgp-routing-mode=regional

echo "Creating Subnet..."
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --range=10.10.0.0/24 \
  --region=$REGION

# Create GKE cluster (TODO: More options?)
echo "Creating GKE Cluster..."
gcloud container clusters create $CLUSTER_NAME \
  --region=$REGION \
  --network=$VPC_NAME \
  --subnetwork=$SUBNET_NAME \
  --disk-size=15GB \
  --machine-type=e2-small \
  --num-nodes=1 \
  --enable-autoscaling --min-nodes=3 --max-nodes=6 \
  --no-enable-insecure-kubelet-readonly-port \
  --addons=GcpFilestoreCsiDriver \
  --release-channel=regular

echo "Infrastructure setup complete!"

# Get credentials for the new cluster to configure kubectl
echo "Configuring kubectl..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
kubectl create ns wordpress

# Handle existing Persistent Volume Claims from volumes.yml
echo "Checking for existing PersistentVolumeClaims..."
if kubectl get pvc mysql-pv-claim &> /dev/null && kubectl get pvc wordpress-pv-claim &> /dev/null; then
  echo "PersistentVolumeClaims 'mysql-pv-claim' and 'wordpress-pv-claim' already exist."
  read -p "Do you want to skip creating them and continue with the deployment? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting deployment."
    exit 1
  fi
else
  echo "Applying volumes.yml..."
  kubectl apply -f volumes.yml -n wordpress
fi

# Setup secrets

echo "Checking for existing Secrets..."
if kubectl get secret mysql-pass &> /dev/null || kubectl get secret wordpress-db-credentials &> /dev/null; then
    echo "One or more secrets ('mysql-pass', 'wordpress-db-credentials') already exist."
    read -p "Do you want to skip creating them and continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting deployment. Please delete the existing secrets if you wish to recreate them."
        exit 1
    fi
else
    echo "Creating Kubernetes Secrets..."
    # Prompt for MySQL root password with verification
    while true; do
        read -s -p "Enter the password for MySQL ROOT user: " MYSQL_ROOT_PASSWORD
        echo
        read -s -p "Confirm the password for MySQL ROOT user: " MYSQL_ROOT_PASSWORD_CONFIRM
        echo
        if [ "$MYSQL_ROOT_PASSWORD" = "$MYSQL_ROOT_PASSWORD_CONFIRM" ]; then
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
    kubectl create secret generic mysql-pass --from-literal=password="$MYSQL_ROOT_PASSWORD" -n wordpress

    # Prompt for WordPress database password with verification
    while true; do
        read -s -p "Enter the password for the WordPress database user 'wordpress': " WORDPRESS_DB_PASSWORD
        echo
        read -s -p "Confirm the password for the WordPress user: " WORDPRESS_DB_PASSWORD_CONFIRM
        echo
        if [ "$WORDPRESS_DB_PASSWORD" = "$WORDPRESS_DB_PASSWORD_CONFIRM" ]; then
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
    kubectl create secret generic wordpress-db-credentials \
      --from-literal=username='wordpress' \
      --from-literal=password="$WORDPRESS_DB_PASSWORD" -n wordpress
    echo "Secrets created successfully."
fi

# 3. Apply the rest of the Kubernetes manifests in order

# Setup internal service for MySQL to be accessable to Wordpress pods
echo "Applying mysqlservice.yml for internal MySQL access..."
kubectl apply -f mysqlservice.yml -n wordpress

# Setup load balancer with the option of a specific subnet.
read -p "Enter a source IP CIDR to restrict access (e.g., 1.2.3.4/32). Press Enter to use the default '0.0.0.0/0': " SOURCE_IP_RANGE

if [ -n "$SOURCE_IP_RANGE" ]; then
    echo "Updating load balancer to allow traffic from: $SOURCE_IP_RANGE"
    # Using a different sed separator (#) here to avoid issues with the / in the IP address
    sed -i "s#0.0.0.0/0#$SOURCE_IP_RANGE#" loadbalancer.yml
else
    echo "Using default source IP range '0.0.0.0/0'."
fi

# Apply the setup load balancer
echo "Applying loadbalancer.yml for WordPress..."
kubectl apply -f loadbalancer.yml -n wordpress

# Deploy MySQL for Wordpress
echo "Applying wordpress-mysql.yml..."
kubectl apply -f wordpress-mysql.yml -n wordpress

# Setup Filestore
echo "Updating Filestore StorageClass with VPC name: $VPC_NAME"
sed -i "s/network: .*/network: $VPC_NAME #automatically changed by setup script/" wordpress-standard-rwx.yml

# Deploy Filestore for Wordpress
echo "Creating Filestore for Wordpress..."
kubectl apply -f wordpress-standard-rwx.yml -n wordpress

# Deploy Wordpress
echo "Applying wordpress.yml..."
kubectl apply -f wordpress.yml -n wordpress

# Let the user know everything went well and to be patient.
echo "Kubernetes deployment complete!"
echo "It may take a few minutes for the external IP for WordPress to become available."
echo "Run 'kubectl get services wordpress -n wordpress' to check the status of the Wordpress load balancer."
