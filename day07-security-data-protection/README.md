# **Day 7 – Security & Data Protection (Key Vault, Encryption & Access Policies)**

Welcome to the security hardening phase.  
If Day 6 was about *moving the valuables into the new building*, Day 7 is about **locking the vault and setting up guards**.

---

## 🎯 Learning Objectives
By the end of this lab, you will:

- Protect secrets and credentials in **Azure Key Vault**  
- Enable **Transparent Data Encryption (TDE)** for SQL Databases  
- Use **Managed Identities** to access secrets without storing passwords  
- Implement **Access Policies** and **Private Link** for Key Vault  
- Understand **customer-managed keys (CMK)** vs. service-managed keys (SMK)

---

⚙️ Section 1 – Create Key Vault and Secure Secrets

source scripts/cli/vars.sh
export KV_NAME="kv-tgt-olumi"

az keyvault create \
  --name "$KV_NAME" \
  --resource-group "$RG_TARGET" \
  --location "$LOCATION"

# Add a sample secret (SQL connection string)
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "SqlConnString" \
  --value "Server=tcp:$TGT_SQL_SERVER.database.windows.net,1433;Database=sqldb01;User ID=sqladmin-learner;Password=$SQL_PASSWORD;Encrypt=True;"

⚙️ Section 2 – Enable Transparent Data Encryption (TDE)
Azure SQL automatically uses a Microsoft-managed key, but you can bring your own CMK from Key Vault.

# Create a Key Vault Key
az keyvault key create \
  --vault-name "$KV_NAME" \
  --name "sql-tde-key" \
  --protection software

# Associate with SQL Server
az sql server tde-key set \
  --server "$TGT_SQL_SERVER" \
  --resource-group "$RG_TARGET" \
  --kid "$(az keyvault key show --vault-name "$KV_NAME" --name sql-tde-key --query id -o tsv)"

# Verify TDE status
az sql db tde show -g "$RG_TARGET" -s "$TGT_SQL_SERVER" -d sqldb01 -o table

⚙️ Section 3 – Enable Managed Identity and Grant Access

# Enable system-assigned identity on the App Service
az webapp identity assign \
  --name "$WEBAPP_NAME" \
  --resource-group "$RG_TARGET"

# Get the principal ID
APP_ID=$(az webapp show -n "$WEBAPP_NAME" -g "$RG_TARGET" --query identity.principalId -o tsv)

# Grant Key Vault access to that identity
az keyvault set-policy \
  --name "$KV_NAME" \
  --object-id "$APP_ID" \
  --secret-permissions get list
Your web app can now fetch secrets directly from Key Vault without embedding credentials.

⚙️ Section 4 – Private Link for Key Vault (Optional)

az network private-endpoint create \
  --name kv-plink-endpoint \
  --resource-group "$RG_TARGET" \
  --vnet-name vnet-tgt-app \
  --subnet snet-tgt-app \
  --private-connection-resource-id $(az keyvault show -n "$KV_NAME" -g "$RG_TARGET" --query id -o tsv) \
  --group-id vault \
  --connection-name kv-plink-conn
This restricts access to internal VNet traffic only.

🧩 Sequence Diagram
```mermaid
sequenceDiagram
    participant WebApp
    participant ManagedIdentity
    participant KeyVault
    participant SQLDB
    participant EncryptionKey

    WebApp->>ManagedIdentity: Request token
    ManagedIdentity->>KeyVault: Get SqlConnString secret
    KeyVault-->>ManagedIdentity: Secret value (returned securely)
    WebApp->>SQLDB: Connect using secret
    SQLDB->>EncryptionKey: Use TDE key for at-rest encryption
    EncryptionKey-->>SQLDB: Encryption OK
    WebApp-->>User: Encrypted data served securely
```

---

🧠 Analogy
Think of Key Vault as the bank vault and Managed Identity as the authorized keycard.
TDE acts like automatic encryption on every hard drive in the bank — even if someone steals a drive, they can’t read it without the vault key.

✅ Checkpoint
Task	Verification
Key Vault exists	az keyvault list -g "$RG_TARGET" -o table
Secret stored	az keyvault secret list --vault-name "$KV_NAME" -o table
Managed Identity assigned	az webapp identity show -n "$WEBAPP_NAME" -g "$RG_TARGET" -o table
TDE enabled	az sql db tde show -g "$RG_TARGET" -s "$TGT_SQL_SERVER" -d sqldb01 -o table

📝 Assessment Questions
What advantage does Managed Identity have over storing secrets in app settings?

What is the difference between service-managed and customer-managed keys for TDE?

How does Private Link enhance Key Vault security?

Which Azure CLI command grants a web app access to Key Vault secrets?

Next → Day 8 – Monitoring & Compliance Policies

## 🧩 RBAC vs Access Policy Troubleshooting Appendix

If you encounter a **“Caller is not authorized to perform action on resource”** error when running:

az keyvault secret set --vault-name kv-tgt-olumi --name SqlConnString --value "<value>"
It means your Key Vault is using RBAC-based access control and your Azure CLI user does not yet have permission to perform the setSecret action.

🧭 1. Identify Your Current User and Vault Access Model

az account show -o table
az ad signed-in-user show --query "{displayName:displayName,objectId:id}"
az keyvault show -n kv-tgt-olumi --query "{name:name,enableRbacAuthorization:properties.enableRbacAuthorization}" -o jsonc
If enableRbacAuthorization = true, the vault is RBAC-controlled.

🧰 2. Fix Option A — Assign “Key Vault Administrator” Role (Recommended)
Grant your signed-in user full permissions on the vault:

MYID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --assignee "$MYID" \
  --role "Key Vault Administrator" \
  --scope $(az keyvault show -n kv-tgt-olumi --query id -o tsv)
⏱ Wait 2–5 minutes for propagation, then retry your secret creation:

az keyvault secret set \
  --vault-name kv-tgt-olumi \
  --name "SqlConnString" \
  --value "Server=tcp:$TGT_SQL_SERVER.database.windows.net,1433;Database=sqldb01;User ID=sqladmin-learner;Password=$SQL_PASSWORD;Encrypt=True;"

🧰 3. Fix Option B — Switch to Legacy Access Policy Mode (Quick Workaround)
If RBAC propagation is delayed or your environment doesn’t allow role assignment changes:

az keyvault update -n kv-tgt-olumi --enable-rbac-authorization false

MYID=$(az ad signed-in-user show --query id -o tsv)
az keyvault set-policy \
  -n kv-tgt-olumi \
  --object-id "$MYID" \
  --secret-permissions get list set delete
Then retry the same az keyvault secret set command.

🧾 4. Verify the Fix

az keyvault secret list --vault-name kv-tgt-olumi -o table
az keyvault secret show --vault-name kv-tgt-olumi --name SqlConnString -o jsonc
If these commands return your secret successfully, the issue is resolved.

🧱 5. Optional – Revert to RBAC Mode (After Testing)
Once your tests are complete and access policies are no longer needed:

az keyvault update -n kv-tgt-olumi --enable-rbac-authorization true

🧠 Key Takeaways
Mode	Control Model	Permissions Managed By	Best For
RBAC (enableRbacAuthorization=true)	Azure Role-Based Access Control	Azure Roles (e.g., Key Vault Administrator)	Enterprise-scale governance
Access Policy (false)	Legacy per-object permissioning	Access policies (per user/app)	Quick lab/test scenarios

💡 Tip: For enterprise production, always prefer RBAC mode for Key Vault — it scales better and integrates cleanly with Managed Identities and CI/CD automation.

