# Azure IaC (Bicep)

Bicep infrastructure-as-code for: VNet, 4 VMs, 2 App Services, 1 Function App, 1 Key Vault,
1 Data Factory, Storage Account + Azure Files, and Private Endpoints for every PaaS service.

## Structure

```
azure-iac/
├── main.bicep                          # orchestrator — wires up all modules
├── parameters/
│   └── main.dev.bicepparam             # sample dev parameter file
└── modules/                            # reusable, independently-testable modules
    ├── network/
    │   ├── vnet.bicep                  # VNet + subnets (array-driven)
    │   ├── nsg.bicep                   # NSG + security rules (array-driven)
    │   ├── private-dns-zone.bicep      # Private DNS zone + VNet link
    │   └── private-endpoint.bicep      # Generic PE, works for any target resource
    ├── compute/
    │   └── vm.bicep                    # Windows/Linux VM + NIC (no public IP)
    ├── web/
    │   ├── app-service-plan.bicep
    │   ├── app-service.bicep           # Web App, VNet-integrated, PE-ready
    │   └── function-app.bicep          # Function App, VNet-integrated, PE-ready
    ├── storage/
    │   ├── storage-account.bicep
    │   └── file-share.bicep            # Azure Files share (child of storage account)
    ├── keyvault/
    │   └── key-vault.bicep             # RBAC-authorized, PE-ready
    └── data/
        └── data-factory.bicep          # PE-ready, optional managed VNet
```

Each module takes plain parameters and returns outputs (resource id, name, principal id,
etc.), so it can be reused across environments or other repos without changes.
`main.bicep` is the only file that knows how they fit together.

## What main.bicep builds

- **VNet** (`10.10.0.0/16`) with 3 subnets: `snet-vm`, `snet-appsvc` (delegated to
  `Microsoft.Web/serverFarms`, used for regional VNet integration), `snet-pe` (private
  endpoints).
- **4 VMs** from the `vmConfigs` array param (edit the array to change count/sizes/OS).
- **2 App Services** on a shared Premium v3 Linux plan, from `appServiceConfigs`.
- **1 Function App** on its own Elastic Premium plan, backed by the shared storage account.
- **1 Storage Account** with blob + file services, and **1 Azure Files share**.
- **1 Key Vault** (RBAC auth, soft delete + purge protection on).
- **1 Data Factory** with a managed VNet.
- **Private endpoints + private DNS zones** for Key Vault (`vault`), Storage (`blob`,
  `file`), and Data Factory (`dataFactory`). App Services/Function reach out via regional
  VNet integration rather than a PE (PE is for inbound; add one under `modules/network`
  if you also need inbound-private access to the sites).

All PaaS resources default `publicNetworkAccess` to **Disabled** — everything is reached
through the VNet.

## Deploy

```bash
az group create -n rg-contoso-dev -l eastus2

az deployment group create \
  -g rg-contoso-dev \
  -f main.bicep \
  -p parameters/main.dev.bicepparam \
  -p vmAdminPassword=$VM_ADMIN_PASSWORD
```

Don't commit real passwords/keys into `.bicepparam` files — pass secrets at deploy time
(CLI param, CI/CD secret, or Key Vault reference).

## Notes / things to double-check before production use

- **Windows computer names** are capped at 15 chars. `vmName` is built as
  `<namePrefix><environment><suffix>` — keep `namePrefix` short if any VMs are Windows.
- **RBAC role assignments** aren't included (e.g. Key Vault Secrets User for the VMs/apps,
  Storage Blob Data Contributor for the Function App). Add a `modules/security/` (or
  similar) role-assignment module once you know which identities need which roles.
- **App Service / Function private inbound access**: currently reached via VNet
  integration for *outbound*. If you need inbound private access too, add a Private
  Endpoint (groupId `sites`) using the existing generic `private-endpoint.bicep` module.
- No CLI was available in this environment to run `bicep build`/`bicep lint` — the code
  was written and manually reviewed for correctness, but run `az bicep build --file
  main.bicep` (or `bicep lint`) before your first real deployment.
