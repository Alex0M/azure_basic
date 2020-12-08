variable "subscription_id" {
    description = "Enter the subsription ID"
}

variable "env_tag" {
  description = "Enter the environment tag that will be ued to derive the name of resources"
}

variable "location" {
  description = "Enter the location name which is where the resource group will be created"
  default = "eastus"
}

variable "vm_count" {
    description = "Enter the number of VMs"
    default = 1
}

variable "vm_pass" {
    description = "Enter the password of VM user"
}
