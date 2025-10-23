# Azure Kubernetes Infrastructure with OpenVPN

This Terraform project provisions a secure, production-ready Kubernetes environment in Azure with multiple layers of security through network isolation and VPN access.

## Overview

This infrastructure deploys:
- **Azure Virtual Network** with dedicated subnets for gateway, database, and applications
- **Azure VPN Gateway** with OpenVPN for secure Point-to-Site access
- **Private AKS Cluster** accessible only through the VPN
- **PostgreSQL Flexible Server** with private networking
- **Private DNS Zones** for internal service resolution

### Why This Architecture?

This design provides **defense-in-depth security** compared to a standard AKS deployment:

1. **No public endpoints**: The AKS cluster API server is completely private with no public IP
2. **VPN authentication layer**: Access requires both Azure OAuth authentication AND a valid VPN client certificate
3. **Network segmentation**: Resources are isolated in dedicated subnets with appropriate network policies
4. **Private DNS**: All internal resources resolve through private DNS zones

While a standard AKS deployment with public access is simpler, this architecture is appropriate for:
- Important workloads handling sensitive data
- Helping towards compliance requirements (HIPAA, PCI-DSS, SOC 2)
- Organizations requiring multiple authentication factors
- Environments where network-level access control is mandatory
- Small teams or solo developers, where spinning up or revoking VPN certificates semi-manually is reasonable.

## Prerequisites

Before starting, ensure you have:
- An active Azure subscription with appropriate permissions to create resources
- [Terraform](https://www.terraform.io/downloads) installed (version 1.0+)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed for Kubernetes management
- [OpenVPN client](https://openvpn.net/community-downloads/) for VPN connectivity

## Step 0: Initial Setup

### 1. Install Terraform

Download and install Terraform from [terraform.io](https://www.terraform.io/downloads). Verify installation:

```bash
terraform --version
```

### 2. Configure Azure Authentication

Set your Azure subscription and tenant IDs as environment variables. Add these to your `~/.zshrc` (or `~/.bashrc` for bash users):

```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id-here"
export ARM_TENANT_ID="your-tenant-id-here"
```

Apply the changes:

```bash
source ~/.zshrc
```

To find your subscription and tenant IDs:

```bash
az login
az account show --query "{subscriptionId:id, tenantId:tenantId}" -o table
```

### 3. VPN Certificate Setup

This infrastructure requires a root certificate for the VPN Gateway. You'll need to generate this **before** running Terraform.

Create a directory for certificates:

```bash
mkdir -p certs
```

Generate the root certificate (example using OpenSSL):

```bash
# Generate root CA private key
openssl genrsa -out certs/rootCA.key 4096

# Generate root CA certificate
openssl req -x509 -new -nodes -key certs/rootCA.key \
  -sha256 -days 3650 -out certs/rootCA.crt \
  -subj "/CN=VPN Root CA"
# Change into the form needed for Azure terraform
openssl x509 -in certs/rootCA.crt -outform der | base64 -w0 > certs/rootCA.pem
```

**Note**: Keep `rootCA.key` secure and never commit it to version control. The Terraform configuration only uses the public certificate (`rootCA.pem`).

### 4. Initialize Terraform

Clone this repository and navigate to the project directory:

```bash
git clone <your-repo-url>
cd <project-directory>
terraform init
```

This downloads the required Azure provider and prepares your working directory.

## Step 1: Configure and Deploy Core Infrastructure

### 1. Create terraform.tfvars

Copy the template below and create a `terraform.tfvars` file in your project root:

```hcl
# Required Variables
resource_group_name     = "rg-your-project-name"
psql_name              = "psql-your-unique-name"
psql_admin_password    = ""  # Set this!

# Optional: Customize as needed
location               = "centralus"
environment            = "dev"
vnet_name             = "vnet-vpn-demo"
vnet_address_space    = "10.50.0.0/16"
vpn_root_cert_path    = "certs/rootCA.pem"

# AKS Configuration
aks_cluster_name      = "aks-simple-cluster"
aks_nodepool_name     = "default"
kubernetes_version    = "1.32.7"
vm_size               = "Standard_B4as_v2"
node_count            = 1
```

**Important**: 
- Change `psql_admin_password` to a strong, unique password
- The `psql_name` must be globally unique across Azure
- Do not commit `terraform.tfvars` to version control (it should be in `.gitignore`)

### 2. Deploy Core Infrastructure

For the first deployment, you'll apply the infrastructure in **two phases** to make it easy to debug any issues that might crop up, and to reduce how much you need to understand at once.

**Phase 1**: Deploy networking, VPN, and database infrastructure:

```bash
# Comment out the AKS resources temporarily
# Open aks.tf and comment out all resources, or rename it to aks.tf.backup

terraform plan
terraform apply
```

Review the plan carefully, then type `yes` to proceed. This will take more than 15 minutes, less than an hour as the VPN Gateway is slow to provision.

### 3. Verify Core Infrastructure

After the first apply completes, verify the resources in the Azure Portal:
- Resource group exists with VNet, subnets, and VPN Gateway
- VPN Gateway shows a public IP address
- PostgreSQL server is created and accessible only within the VNet (TODO, note how to get the IP)

## Step 2: Complete your VPN certificate and test

Part of why we spun up the PostgreSQL server was to have something within the VNet we can use to test the VPN.

### 1. Download generic VPN client

In the Azure portal, visit your Virtual network gateway. Navigate to "Point-to-site configuration" under the "Settings" sidebar.

Download the VPN client via the "Download VPN client" button

Take the `vpnconfig.ovpn` file from the `OpenVPN` folder and place it in your certs folder.

### 2. Crafting a personal VPN profile

I find that I have to remove or comment out the log openvpn.log line. Place the file into the `certs` folder. Once you've done this, run `generate.sh` and use it to generate your personal VPN profile

```bash
bash ./generate.sh my_name
```

Your personal cert should now be present in the `ovpn_output` folder within `certs`. Use this with your OpenVPN client to continue. If you cannot connect at all, something has gone wrong.

### 3. Test The VPN client

Use your new VPN client, confirm it connects. Your internal network allocated IP should appear on the same page you downloaded the VPN client from Azure. (optional check)

Find the IP address of the PSQL server, and connect to it. If you can do this while the OVPN client is active but cannot when it is not, you have confirmed that the network is working as expected, as is your personal VPN client.

I generally do this by visiting the Private DNS zone for the psql instance and looking at DNS Management > Recordsets. The Ip is presented there.

Connect to psql:

```bash
psql -h <your-psql-ip-here> -p 5432 postgres psqladmin
```

**NOTE**
Because a Point-to-site VPN connection is not considered 'within' the network in the same way that VMs or k8s assets are, you cannot use Azure DNS. So you will have to find the PSQL IP to connect.

## Step 3: Deploy Kubernetes Infrastructure

### 1. Enable AKS Resources

Uncomment the AKS resources in `aks.tf` (or rename `aks.tf.backup` back to `aks.tf`).

### 2. Apply Full Configuration

```bash
terraform plan
terraform apply
```

This will deploy:
- AKS cluster with private API server
- User-assigned managed identity with appropriate permissions
- Private DNS zone for AKS
- Network integration between AKS and the VNet

This deployment takes approximately 10-15 minutes.

### 3. Verify AKS Deployment

```bash
# Check outputs
terraform output aks_cluster_name
terraform output cluster_fqdn

# Verify in Azure Portal
# Navigate to your AKS cluster and confirm:
# - Networking shows "Private cluster: Enabled"
# - Node pools are running
```

## Connecting to Your Infrastructure

Retrieve your kubeconfig credentials:

```bash
# Get kubeconfig (this requires VPN connection)
az aks get-credentials \
  --resource-group <your resource group name> \
  --name <name of your aks> --public-fqdn
```

**NOTE**
I found using the public fqdn setting as an effective way to allow VPN users to use AKS when configured this way.

# Test connection
```bash
kubectl get nodes
kubectl get pods -A
```

You should now see your AKS nodes. If you disconnect from the VPN, `kubectl` commands will fail, demonstrating the security model.

## Project Structure

```
.
├── main.tf           # Core infrastructure: VNet, subnets, VPN Gateway, PostgreSQL
├── aks.tf            # AKS cluster and related resources
├── variables.tf      # Variable definitions with validation rules
├── outputs.tf        # Output values displayed after apply
├── providers.tf      # Terraform and provider configuration
├── terraform.tfvars  # Your configuration values (do not commit!)
└── certs/            # VPN certificates (do not commit!)
    ├── rootCA.pem    # Root CA certificate (used by Terraform)
    └── rootCA.key    # Root CA private key (keep secure!)
```

## Important Notes

- **VPN Gateway SKU**: The default `VpnGw1` SKU takes a while to provision
- **Private AKS**: The cluster API server is only accessible via VPN
- **PostgreSQL**: Configured with private networking only, no public access
- **Costs**: Be aware that the VPN Gateway and AKS cluster incur ongoing charges even when idle
- **Certificate Security**: Never commit private keys (`.key` files) to version control

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` to confirm. This will take several minutes to complete.

**Note**: Ensure you've saved any data from your PostgreSQL database before destroying resources.

## Troubleshooting

### Common Issues

**VPN Connection Fails**:
- Verify your client certificate is signed by the root CA uploaded to Azure
- Check that the VPN Gateway shows as "Succeeded" in the Azure Portal
- Ensure your OpenVPN client configuration includes the correct certificates

**kubectl Cannot Connect**:
- Verify you're connected to the VPN
- Run `az aks get-credentials` again while connected to VPN
- Check that the AKS cluster private DNS zone is properly linked to the VNet

**Terraform Apply Fails**:
- Ensure your Azure credentials are configured correctly
- Verify you have sufficient permissions in the subscription
- Check that resource names (especially `psql_name`) are globally unique

## Next Steps

After deploying this infrastructure, you can:
- Deploy applications to your AKS cluster using `kubectl` or Helm
- Configure additional node pools for different workload types
- Set up Azure Container Registry (ACR) integration
- Configure monitoring with Azure Monitor and Container Insights
- Add additional security controls like Azure Policy or Pod Security Standards

## Contributing

Feedback and contributions are welcome! Please open an issue or submit a pull request with improvements.

## License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
