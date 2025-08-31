#!/bin/bash
set -e

echo "🌯 Building Lingua Demo Container"
echo "================================"

# Build the release if it doesn't exist
if [ ! -f "../_build/prod/lingua-0.1.0.tar.gz" ]; then
    echo "📦 Building Lingua release..."
    cd ..
    MIX_ENV=prod mix release --overwrite
    cd demo
fi

# Build Docker image
echo "🐳 Building Docker demo image..."
docker build -t lingua-demo .

echo ""
echo "🚀 Running Lingua Demo..."
echo "========================"
echo "This will:"
echo "  1. Create a React TypeScript app with i18n patterns"
echo "  2. Install Lingua using the install.sh script"
echo "  3. Run the complete extract → translate → generate pipeline"
echo "  4. Show the generated translation files"
echo ""

# Run the container
docker run -it --rm -p 3000:3000 lingua-demo