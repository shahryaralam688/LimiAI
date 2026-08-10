#!/bin/bash

# Find hardcoded SwiftUI colors outside Color.swift
# Run from repo root: ./find_hardcoded_colors.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SEARCH_DIRS=("Features" "Core" "Shared")

PATTERN='Color\.(white|black|gray|red|green|blue|yellow|orange|pink|purple|cyan)|Color\(hex:|Color\(red:|#colorLiteral'

echo "🔍 Hardcoded color audit — Limi AI App"
echo "   Scanning: ${SEARCH_DIRS[*]}"
echo ""

total=0
while IFS= read -r file; do
  [[ "$file" == *"/Color.swift" ]] && continue
  [[ "$file" == *"/RainbowSlider.swift" ]] && continue
  count=$(grep -cE "$PATTERN" "$file" 2>/dev/null || true)
  if [[ "$count" -gt 0 ]]; then
    echo "  $file ($count)"
    total=$((total + count))
  fi
done < <(find "${SEARCH_DIRS[@]/#/$ROOT/}" -name '*.swift' 2>/dev/null)

echo ""
echo "=========================================="
if [[ "$total" -eq 0 ]]; then
  echo "✅ No hardcoded color violations found (excluding Color.swift + RainbowSlider)."
else
  echo "⚠️  $total violation(s) — see files above."
  echo "   Allowed exceptions: WLED Color(hex:) for user lamp picks, AR UIColor RGB."
fi
echo "📖 Migration reference: THEME_GUIDE.md + BRAND_QA.md"
