#!/usr/bin/env bash
# Azure Tenant Workload Migration – Inventory Script
# Lists resources in a resource group and outputs CSV

set -euo pipefail
RG="${1:-$RG_SOURCE}"

echo "resourceId,resourceType,location,tag_Owner,tag_Lab,tag_Scenario"

az resource list -g "$RG" --query '[].{id:id, type:type, location:location, tags:tags}' -o json |
  jq -r '.[] | "\(.id),\(.type),\(.location),\(.tags.Owner // ""),\(.tags.Lab // ""),\(.tags.Scenario // "")"'
