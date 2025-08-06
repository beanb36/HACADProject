#!/bin/bash

# HACADProject WordPress setup page modifier script

# Namespace for WordPress deployment
NAMESPACE="wordpress"

# Get the name of the WordPress pod (assumes label app=wordpress)
WORDPRESS_POD=$(kubectl get pods -n $NAMESPACE -l app=wordpress -o jsonpath="{.items[0].metadata.name}")

# Run sed inside the pod to replace all occurrences in all HTML and PHP files
kubectl exec -n $NAMESPACE $WORDPRESS_POD -- \
sed -i.bak "s/WordPress &rsaquo; Installation/WordPress &rsaquo; HA Install/g" /var/www/html/wp-admin/install.php

echo "If you do not see the change, try restarting the pod or clearing WordPress cache."
