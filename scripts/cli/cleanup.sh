#!/usr/bin/env bash
set -euo pipefail

# ===== Config (edit if you changed names) =====
SUB_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
RG_SOURCE="${RG_SOURCE:-rg-01-eus-src}"
RG_TARGET="${RG_TARGET:-rg-01-eus-tgt}"
LOCATION="${LOCATION:-eastus2}"
KV_NAME="${KV_NAME:-kv-tgt-olumi}"
LAW_NAME="${LAW_NAME:-law-migrate-eus2}"
DIAG_NAME="${DIAG_NAME:-sub-activity-to-law}"
DCR_NAME="${DCR_NAME:-dcr-vmperf-syslog}"
PA_TAG="require-owner-tag"
PA_LINUX="audit-linux-password-auth"
PA_DIAG="audit-missing-diagnostics"

# ===== Guard =====
STATE="$(az account show --query state -o tsv 2>/dev/null || echo Unknown)"
if [[ "$STATE" != "Enabled" ]]; then
  echo "⛔ Subscription is '$STATE'. Re-enable first."
  exit 90
fi

echo "✅ Subscription enabled. Starting teardown..."

# ===== Immediate cost stoppers =====
for RG in "$RG_SOURCE" "$RG_TARGET"; do
  az vm list -g "$RG" --query "[].name" -o tsv 2>/dev/null | while read -r VM; do
    [[ -z "$VM" ]] && continue
    echo "Deallocating VM $VM in $RG..."
    az vm deallocate -g "$RG" -n "$VM" --no-wait || true
  done
done

# ===== Remove subscription-scope diagnostic setting =====
if [[ -n "$SUB_ID" ]]; then
  echo "Removing subscription diagnostic setting: $DIAG_NAME"
  az monitor diagnostic-settings delete \
    --resource "/subscriptions/$SUB_ID" \
    --name "$DIAG_NAME" 2>/dev/null || true
fi

# ===== Remove policy assignments (RG scope) =====
SCOPE="/subscriptions/$SUB_ID/resourceGroups/$RG_TARGET"
echo "Removing policy assignments in $SCOPE"
az policy assignment delete --name "$PA_TAG"   --scope "$SCOPE" 2>/dev/null || true
az policy assignment delete --name "$PA_LINUX" --scope "$SCOPE" 2>/dev/null || true
az policy assignment delete --name "$PA_DIAG"  --scope "$SCOPE" 2>/dev/null || true

# ===== DCR association + DCR delete =====
VM_IDS=$(az vm list -g "$RG_TARGET" --query "[].id" -o tsv 2>/dev/null || true)
for VM_ID in $VM_IDS; do
  az monitor data-collection rule association delete \
    --resource "$VM_ID" \
    --association-name "vm-dcr" 2>/dev/null || true
done

az resource delete \
  -g "$RG_TARGET" \
  --resource-type "Microsoft.Insights/dataCollectionRules" \
  -n "$DCR_NAME" 2>/dev/null || true

# ===== Key Vault delete + purge (avoid soft-delete retention) =====
if az keyvault show -n "$KV_NAME" -g "$RG_TARGET" >/dev/null 2>&1; then
  echo "Deleting Key Vault $KV_NAME..."
  az keyvault delete -n "$KV_NAME" -g "$RG_TARGET" || true
  echo "Purging Key Vault $KV_NAME..."
  az keyvault purge -n "$KV_NAME" || true
fi

# ===== Remove resource locks if any (they block RG delete) =====
for RG in "$RG_SOURCE" "$RG_TARGET"; do
  az lock list -g "$RG" --query "[].name" -o tsv 2>/dev/null | while read -r L; do
    [[ -z "$L" ]] && continue
    echo "Deleting lock $L in $RG..."
    az lock delete -g "$RG" -n "$L" || true
  done
done

# ===== Delete the resource groups (async) =====
for RG in "$RG_SOURCE" "$RG_TARGET"; do
  if az group show -n "$RG" >/dev/null 2>&1; then
    echo "Deleting resource group: $RG"
    az group delete -n "$RG" --yes --no-wait || true
  fi
done

echo "▶ Deletes dispatched. Check progress with 'az group list -o table'."
echo "Remaining resources snapshot:"
az resource list --query "[].{name:name,type:type,rg:resourceGroup,loc:location}" -o table
echo "✅ Cleanup script finished."
