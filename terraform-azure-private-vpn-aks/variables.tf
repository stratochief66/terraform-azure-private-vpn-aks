# ============================================
# FILE: variables.tf
# Purpose: Define all input variables (schema)
# ============================================

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "centralus"

  validation {
    condition     = contains(["eastus", "westus", "centralus", "canadacentral", "canadaeast"], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group to contain all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.resource_group_name))
    error_message = "Resource group name can only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-vpn-demo"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network in CIDR notation"
  type        = string
  default     = "10.50.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "Address space must be a valid CIDR block."
  }
}

variable "subnet_newbits" {
  description = "Number of bits to add to VNet prefix for subnets (e.g., 8 makes /16 -> /24)"
  type        = number
  default     = 8
}

variable "vpn_client_address_space" {
  description = "Address space for VPN clients (Point-to-Site)"
  type        = string
  default     = "172.20.0.0/24"

  validation {
    condition     = can(cidrhost(var.vpn_client_address_space, 0))
    error_message = "VPN client address space must be a valid CIDR block."
  }
}

variable "snet_name_gateway" {
  description = "Name of the gateway subnet (must be 'GatewaySubnet' for Azure VPN Gateway)"
  type        = string
  default     = "GatewaySubnet"
}

variable "snet_name_database" {
  description = "Name of the database subnet"
  type        = string
  default     = "DatabaseSubnet"
}

variable "snet_name_application" {
  description = "Name of the application subnet"
  type        = string
  default     = "ApplicationSubnet"
}

# adding along with LLM, to check over
variable "public_ip_name" {
  description = "Name for the VPN Gateway public IP"
  type        = string
  default     = "pip-vpn-gateway"
}

variable "vpn_gateway_name" {
  description = "Name for the VPN Gateway"
  type        = string
  default     = "vgw-vpn-demo"
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway (VpnGw1, VpnGw2, etc.)"
  type        = string
  default     = "VpnGw1"
}

variable "vpn_root_cert_name" {
  description = "Name for the VPN root certificate"
  type        = string
  default     = "root-cert"
}

variable "vpn_root_cert_path" {
  description = "Path to root certificate PEM file"
  type        = string
  default     = "certs/rootCA.pem"
}

variable "private_dns_zone_name" {
  description = "Name for PostgreSQL private DNS zone"
  type        = string
  default     = "private.postgres.database.azure.com"
}

variable "dns_link_name" {
  description = "Name for DNS zone to VNet link"
  type        = string
  default     = "psql-vnet-link"
}

variable "psql_name" {
  description = "Name for PostgreSQL Flexible Server"
  type        = string
}

variable "psql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "psql_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "psqladmin"
}

variable "psql_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "psql_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "psql_sku" {
  description = "SKU for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}


variable "vng_name" {
  description = ""
  type        = string
  default     = "vnet-demo-vpn-gateway"
}

## For AKS test
variable "service_cidr" {
  description = "CIDR for Kubernetes services (must not overlap with VNet)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service (must be within service_cidr)"
  type        = string
  default     = "10.0.0.10"
}

variable "aks_resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-simple"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-simple-cluster"
}

variable "aks_nodepool_name" {
  description = "Name of the AKS nodepool"
  type        = string
  default     = "override"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "akssimple"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.32.7"
}

variable "sku_tier" {
  description = "SKU tier for the AKS cluster (Free, Standard, Premium)"
  type        = string
  default     = "Free"
}

variable "automatic_upgrade_channel" {
  description = "Automatic upgrade channel for the AKS cluster (none, patch, stable, rapid, node-image)"
  type        = string
  default     = ""
}

variable "node_os_upgrade_channel" {
  description = "Node OS upgrade channel (None, Unmanaged, SecurityPatch, NodeImage)"
  type        = string
  default     = "None"
}

variable "node_resource_group" {
  description = "Name of the resource group for AKS-managed resources"
  type        = string
  default     = "aks-node-rg-simple"
}

variable "cost_analysis_enabled" {
  description = "Enable cost analysis for the AKS cluster"
  type        = bool
  default     = false
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "Size of the VMs in the node pool"
  type        = string
  default     = "Standard_B4as_v2"
}

variable "auto_scaling_enabled" {
  description = "Enable auto-scaling for the default node pool"
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Minimum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 3
}

variable "max_pods" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 110
}

variable "os_disk_type" {
  description = "OS disk type (Managed, Ephemeral)"
  type        = string
  default     = "Managed"
}

variable "kubelet_disk_type" {
  description = "Kubelet disk type (OS, Temporary)"
  type        = string
  default     = "OS"
}

variable "node_pool_type" {
  description = "Type of node pool (VirtualMachineScaleSets, AvailabilitySet)"
  type        = string
  default     = "VirtualMachineScaleSets"
}

variable "node_public_ip_enabled" {
  description = "Enable public IP for nodes"
  type        = bool
  default     = false
}

variable "scale_down_mode" {
  description = "Scale down mode (Delete, Deallocate)"
  type        = string
  default     = "Delete"
}

variable "drain_timeout_in_minutes" {
  description = "Drain timeout in minutes during upgrades"
  type        = number
  default     = 6
}

variable "node_soak_duration_in_minutes" {
  description = "Node soak duration in minutes after upgrade"
  type        = number
  default     = 2
}

variable "max_surge" {
  description = "Maximum surge of nodes during upgrade"
  type        = string
  default     = "10%"
}
