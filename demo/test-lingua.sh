#!/bin/bash
set -e

echo "🔍 Testing Lingua Installation"
echo "=============================="

# Extract and check what we actually have
mkdir -p /tmp/test-lingua
tar -xzf demo/lingua-0.1.0.tar.gz -C /tmp/test-lingua
echo "Contents after extraction:"
ls -la /tmp/test-lingua/

echo ""
echo "Binary location:"
find /tmp/test-lingua -name "lingua" -type f

echo ""
echo "Bin directory contents:"
ls -la /tmp/test-lingua/bin/ 2>/dev/null || echo "No bin directory found"