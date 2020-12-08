#!/bin/bash
# Usage: bash create-high-availability-vm-with-sets.sh

date
# Create a Resource Group
echo '------------------------------------------'
echo 'Creating a Resource Group'
az group create \
    --location eastus \
    --name demo-cli


# Create a Virtual Network for the VMs
echo '------------------------------------------'
echo 'Creating a Virtual Network for the VMs'
az network vnet create \
    --resource-group demo-cli \
    --name demo-cli-vnet \
    --address-prefix 10.0.0.0/16 \
    --subnet-name app-subnet \
    --subnet-prefix 10.0.0.0/24

# Create a Virtual Network for the VMs
echo '------------------------------------------'
echo 'Creating a Subnet for jumpbox vm'
az network vnet subnet create \
    --address-prefixes 10.0.1.0/24 \
    --name jumpbox-subnet \
    --resource-group demo-cli \
    --vnet-name demo-cli-vnet

# Create a Network Security Group
echo '------------------------------------------'
echo 'Creating a Network Security Group'
az network nsg create \
    --resource-group demo-cli \
    --name demo-app-nsg

# Add inbound rule on port 80
echo '------------------------------------------'
echo 'Allowing access on port 80'
az network nsg rule create \
    --resource-group demo-cli \
    --nsg-name demo-app-nsg \
    --name Allow-80-Inbound \
    --priority 110 \
    --source-address-prefixes '*' \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --description "Allow inbound on port 80."

# Create the NIC
for i in `seq 1 2`; do
  echo '------------------------------------------'
  echo 'Creating appNic'$i
  az network nic create \
    --resource-group demo-cli \
    --name demo-app-nic$i \
    --vnet-name demo-cli-vnet \
    --subnet app-subnet \
    --network-security-group demo-app-nsg
done 

# Create an availability set
echo '------------------------------------------'
echo 'Creating an availability set'
az vm availability-set create -n demo-avset -g demo-cli

# Create 2 VM's from a template
for i in `seq 1 2`; do
    echo '------------------------------------------'
    echo 'Creating appVM'$i
    az vm create \
        --admin-username azureuser \
        --generate-ssh-keys \
        --resource-group demo-cli \
        --name app-demo-$i \
        --nics demo-app-nic$i \
        --image UbuntuLTS \
        --availability-set demo-avset \
        --custom-data cloud-init.txt
done

# Done
echo '--------------------------------------------------------'
echo '             VM Setup Script Completed'
echo '--------------------------------------------------------'