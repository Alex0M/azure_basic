#!/bin/bash
# Usage: bash create-load-balancer.sh

# Create a public IP
echo '------------------------------------------'
echo 'Creating a public IP'
az network public-ip create \
  --resource-group demo-cli \
  --allocation-method Static \
  --name demo-lb-pip

echo '------------------------------------------'
echo 'Creating a Load Balancer'
az network lb create \
  --resource-group demo-cli \
  --name demo-app-lb \
  --public-ip-address demo-lb-pip \
  --frontend-ip-name demo-frontend-pool \
  --backend-pool-name demo-backend-pool

echo '------------------------------------------'
echo 'Creating a Load Balancer Probe'
az network lb probe create \
  --resource-group demo-cli \
  --lb-name demo-app-lb \
  --name demo-health-probe \
  --protocol tcp \
  --port 80 

echo '------------------------------------------'
echo 'Creating a Load Balancer Rule'
az network lb rule create \
  --resource-group demo-cli \
  --lb-name demo-app-lb \
  --name demo-HTTP-rule \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name demo-frontend-pool \
  --backend-pool-name demo-backend-pool \
  --probe-name demo-health-probe


for i in `seq 1 2`; do
    echo '------------------------------------------'
    echo 'Update appNic'$i
    az network nic ip-config update \
    --resource-group demo-cli \
    --nic-name demo-app-nic$i \
    --name ipconfig1 \
    --lb-name demo-app-lb \
    --lb-address-pools demo-backend-pool
done

echo '--------------------------------------------------------'
echo '             LB Setup Script Completed'
echo '--------------------------------------------------------'
echo http://$(az network public-ip show \
                --resource-group demo-cli \
                --name demo-lb-pip \
                --query ipAddress \
                --output tsv)
