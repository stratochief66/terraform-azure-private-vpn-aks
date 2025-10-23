# ============================================
# FILE: outputs.tf
# Purpose: Values to display after terraform apply
# ============================================

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.rg.id
}

output "location" {
  description = "Location where resources were created"
  value       = azurerm_resource_group.rg.location
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.az_vn.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.az_vn.id
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.az_vn.address_space
}

output "calculated_subnets" {
  description = "Calculated subnet CIDR blocks"
  value = {
    gateway_subnet  = local.gateway_subnet_cidr
    database_subnet = local.database_subnet_cidr
    app_subnet      = local.app_subnet_cidr
  }
}

output "public_ip" {
  description = "The public IP to be used for the VPN gateway"
  value       = azurerm_public_ip.vpn_gateway.id
}


## outputs for AKS test
output "aks_resource_group_name" {
  description = "Name of the AKS resource group"
  value       = azurerm_resource_group.aks_rg.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "kubernetes_version" {
  description = "Kubernetes version of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}
