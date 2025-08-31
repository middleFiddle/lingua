#!/bin/bash
set -e

echo "🌯 Lingua Demo Workflow - Testing Complete AI Translation Pipeline"
echo "================================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

step() {
    echo -e "${BLUE}==>${NC} ${1}"
}

success() {
    echo -e "${GREEN}✅${NC} ${1}"
}

info() {
    echo -e "${YELLOW}ℹ️${NC} ${1}"
}

# Test Lingua installation
step "Testing Lingua Installation"
if command -v lingua &> /dev/null; then
    lingua --version
    success "Lingua CLI is available"
else
    echo "❌ Lingua not found in PATH"
    exit 1
fi

# Show React app structure
step "React App Structure"
info "Source files with i18n patterns:"
find src -name "*.tsx" -exec echo "  📄 {}" \;

# Setup AI models (this would normally download NLLB)
step "Setting up AI Models"
info "In production: lingua setup (downloads NLLB model)"
echo "   Skipping model download in demo container..."

# Extract translatable strings
step "Extracting Translatable Strings"
lingua extract --source-dir src --pattern-type i18n

if [ -f "/tmp/lingua_strings.json" ]; then
    success "Strings extracted successfully"
    info "Found $(jq '.source_strings // 0' /tmp/lingua_strings.json) strings across $(jq '.file_mapping | length' /tmp/lingua_strings.json) files"
else
    echo "❌ String extraction failed"
    exit 1
fi

# AI Translation step (now using the dynamic mock CLI)
step "AI Translation Step"
info "Testing with multiple languages: es,fr,de,pt"
lingua translate --to es,fr,de,pt

success "AI translations generated"

# Generate output files with React i18next template
step "Generating Translation Files"
lingua generate --output-template "public/locales/{lang}/{filename}.json" --format json

if [ -d "public/locales" ]; then
    success "Translation files generated"
    info "Output structure:"
    find public/locales -name "*.json" | head -10 | while read file; do
        echo "  📄 ${file}"
    done
else
    echo "❌ Translation file generation failed"
    exit 1
fi

# Show results
step "Results Summary"
echo ""
success "🎉 Lingua Demo Workflow Complete!"
echo ""
info "What happened:"
echo "  1. ✅ Extracted i18n patterns from React components"
echo "  2. ✅ Generated concurrent AI translations (mocked)"
echo "  3. ✅ Created React i18next compatible output files"
echo "  4. ✅ Maintained 1:1 file mapping with template system"
echo ""
info "In production, you would run:"
echo "  lingua setup                                   # Download NLLB models"
echo "  lingua extract --source-dir src --pattern-type i18n"
echo "  lingua translate --to es,fr,de,pt,ja"
echo "  lingua generate --output-template \"public/locales/{lang}/{filename}.json\""
echo ""
success "🚀 Ready for React i18next integration!"

# Keep container running for inspection
echo ""
info "Container will stay running for inspection. Press Ctrl+C to exit."
echo "You can now:"
echo "  - Inspect generated files: ls -la public/locales/"
echo "  - Run React dev server: npm start"
echo ""

# Start React dev server in background and wait
npm start &
wait