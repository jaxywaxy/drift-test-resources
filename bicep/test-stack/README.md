# Bicep Drift Test Stack

This subscription-scoped Bicep stack creates a resource group and a small set of resources useful for drift testing:

- Resource Group
- Virtual Network + Subnet
- Storage Account
- Key Vault (with Private Endpoint)
- Azure SQL Server + Database
- App Service Plan + Web App


Deployment (resource-group scoped example):

```bash
# create or choose a resource group first
RG=my-test-rg
az group create --name $RG --location australiaeast

az deployment group create \
  --resource-group $RG \
  --template-file main.bicep \
  --parameters @parameters.dev.json
```

Notes:
- The `adminPassword` in `parameters.dev.json` is a placeholder — replace with a secure value or supply at deployment time.
- For iterative testing you can change `rgName` to deploy multiple stacks.
- This template is intentionally minimal to produce testable resources for a drift agent.
