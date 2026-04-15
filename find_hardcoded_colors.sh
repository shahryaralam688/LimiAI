#!/bin/bash

# Script to find hardcoded colors in Swift files
# Run: ./find_hardcoded_colors.sh

echo "🔍 Finding hardcoded colors in Swift files..."
echo ""

# Define the search directory
SEARCH_DIR="LimiExhibition"

# Patterns to search for
PATTERNS=(
    "Color\.white"
    "Color\.black"
    "Color\.gray"
    "Color\.red"
    "Color\.green"
    "Color\.blue"
    "Color\.yellow"
    "Color\.orange"
    "Color\.pink"
    "Color\.purple"
    "Color(hex:"
    "Color(red:"
    "Color(\.sRGB"
    "#colorLiteral"
)

echo "📊 Summary of hardcoded colors by file:"
echo "=========================================="

for pattern in "${PATTERNS[@]}"; do
    echo ""
    echo "Pattern: $pattern"
    echo "----------------------------------------"
    find "$SEARCH_DIR" -name "*.swift" -exec grep -l "$pattern" {} \; 2>/dev/null | while read file; do
        count=$(grep -c "$pattern" "$file" 2>/dev/null)
        echo "  $file ($count occurrences)"
    done
done

echo ""
echo "=========================================="
echo "📁 Files with most violations (top 20):"
echo "=========================================="

# Count all violations per file
find "$SEARCH_DIR" -name "*.swift" -exec grep -Hn "Color\.white\|Color\.black\|Color\.gray\|Color\.red\|Color\.green\|Color\.blue\|Color\.yellow\|Color\.orange\|Color\.pink\|Color\.purple\|Color(hex:\|Color(red:\|#colorLiteral" {} \; 2>/dev/null | \
    cut -d: -f1 | \
    sort | \
    uniq -c | \
    sort -rn | \
    head -20

echo ""
echo "✅ To migrate: Replace these with theme colors from Color.swift"
echo "📖 See THEME_GUIDE.md for the migration reference"
