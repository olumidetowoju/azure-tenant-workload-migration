#!/bin/bash
# Safe cost export script
az consumption usage list \
  --start-date "$(date -I -d '30 days ago')" \
  --end-date "$(date -I)" \
  -o json > ../reports/cost-summary.json
echo "✅ Cost summary exported safely."
