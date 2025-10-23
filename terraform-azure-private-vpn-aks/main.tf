# ============================================
# FILE: main.tf
# Purpose: Resource definitions
# ===========================================

# Local values for calculated subnets
locals {
  # Calculate subnet CIDRs automatically from VNet address space
  gateway_subnet_cidr  = cidrsubnet(var.vnet_address_space, var.subnet_newbits, 0) # 10.50.0.0/24
  database_subnet_cidr = cidrsubnet(var.vnet_address_space, var.subnet_newbits, 1) # 10.50.1.0/24
  app_subnet_cidr      = cidrsubnet(var.vnet_address_space, var.subnet_newbits, 2) # 10.50.2.0/24 (future use)

  # Subnet naming convention
  gateway_subnet_name  = var.snet_name_gateway # Must be exactly this name for VPN Gateway
  database_subnet_name = var.snet_name_database
  app_subnet_name      = var.snet_name_application

  common_tags = merge(var.tags, { Environment = var.environment })
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

resource "azurerm_virtual_network" "az_vn" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_address_space]

  tags = local.common_tags
}

resource "azurerm_subnet" "az_subnet_gateway" {
  name                 = local.gateway_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.az_vn.name
  address_prefixes     = [local.gateway_subnet_cidr]
}

resource "azurerm_subnet" "az_subnet_database" {
  name                 = local.database_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.az_vn.name
  address_prefixes     = [local.database_subnet_cidr]

  delegation {
    name = "delegation-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "az_subnet_application" {
  name                 = local.app_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.az_vn.name
  address_prefixes     = [local.app_subnet_cidr]
}

resource "azurerm_public_ip" "vpn_gateway" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard" # Necessary, Basic or whatever is default won't work
  tags                = local.common_tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  name                = var.vng_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = var.vpn_gateway_sku

  tags = local.common_tags

  ip_configuration {
    name                 = "vnet-gateway-config"
    public_ip_address_id = azurerm_public_ip.vpn_gateway.id
    subnet_id            = azurerm_subnet.az_subnet_gateway.id
  }

  vpn_client_configuration {
    address_space        = [var.vpn_client_address_space]
    vpn_client_protocols = ["OpenVPN"]

    root_certificate {
      name             = var.vpn_root_cert_name
      public_cert_data = file(var.vpn_root_cert_path)
    }
  }
}

resource "azurerm_private_dns_zone" "psql" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "psql" {
  name                  = var.dns_link_name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.psql.name
  virtual_network_id    = azurerm_virtual_network.az_vn.id

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.centralus.azmk8s.io"
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "aks-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.az_vn.id

  tags = local.common_tags
}

resource "azurerm_postgresql_flexible_server" "psql_tiny" {
  name                = var.psql_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  version                       = var.psql_version
  administrator_login           = var.psql_admin_username
  administrator_password        = var.psql_admin_password
  delegated_subnet_id           = azurerm_subnet.az_subnet_database.id
  public_network_access_enabled = false
  private_dns_zone_id           = azurerm_private_dns_zone.psql.id
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms" # tiny 1vCore 2GiB mem 640 max iops
}
