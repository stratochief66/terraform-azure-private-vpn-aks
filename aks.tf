# ============================================
# FILE: aks.tf
# Purpose: Resource definitions for AKS
# ===========================================

resource "azurerm_resource_group" "aks_rg" {
  name     = var.aks_resource_group_name
  location = var.location
}

# Create user-assigned identity for AKS
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.aks_cluster_name}-identity"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
}

# Grant DNS zone contributor role to the identity BEFORE creating cluster
resource "azurerm_role_assignment" "aks_dns_contributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Grant network contributor role on the subnet
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.az_subnet_application.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                                = var.aks_cluster_name
  location                            = azurerm_resource_group.aks_rg.location
  resource_group_name                 = azurerm_resource_group.aks_rg.name
  dns_prefix_private_cluster          = var.dns_prefix
  kubernetes_version                  = var.kubernetes_version
  sku_tier                            = var.sku_tier
  node_os_upgrade_channel             = var.node_os_upgrade_channel
  node_resource_group                 = var.node_resource_group
  cost_analysis_enabled               = var.cost_analysis_enabled
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = true
  private_dns_zone_id                 = azurerm_private_dns_zone.aks.id

  default_node_pool {
    name                   = var.aks_nodepool_name
    vm_size                = var.vm_size
    auto_scaling_enabled   = var.auto_scaling_enabled
    min_count              = var.auto_scaling_enabled ? var.min_count : null
    max_count              = var.auto_scaling_enabled ? var.max_count : null
    node_count             = var.auto_scaling_enabled ? null : var.node_count
    max_pods               = var.max_pods
    os_disk_type           = var.os_disk_type
    kubelet_disk_type      = var.kubelet_disk_type
    type                   = var.node_pool_type
    node_public_ip_enabled = var.node_public_ip_enabled
    scale_down_mode        = var.scale_down_mode
    vnet_subnet_id         = azurerm_subnet.az_subnet_application.id

    upgrade_settings {
      drain_timeout_in_minutes      = var.drain_timeout_in_minutes
      node_soak_duration_in_minutes = var.node_soak_duration_in_minutes
      max_surge                     = var.max_surge
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aks.id
    ]
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }
}
