#!/bin/bash
set -e

# Multi-Platform Release Builder for Lingua
# Generates releases for Linux, macOS, and Windows

echo "🏗️  Building Lingua releases for all platforms..."
echo "=============================================="

# Clean previous builds
echo "🧹 Cleaning previous builds..."
mix clean
rm -rf _build/releases/

# Create releases directory
mkdir -p _build/releases

# Get version from mix.exs
VERSION=$(grep 'version:' mix.exs | sed 's/.*version: "\(.*\)".*/\1/')
echo "📦 Building version: $VERSION"

# Function to build release for specific target
build_release() {
    local target=$1
    local os=$2
    local arch=$3
    
    echo ""
    echo "🔨 Building for $target ($os-$arch)..."
    
    # Set target environment
    export MIX_TARGET=$target
    export TARGET_OS=$os
    export TARGET_ARCH=$arch
    
    # Build release
    MIX_ENV=prod mix release --overwrite --quiet
    
    # Create platform-specific archive name
    local archive_name="lingua-${os}-${arch}-${VERSION}.tar.gz"
    local archive_path="_build/releases/${archive_name}"
    
    # Copy and rename the release archive
    cp "_build/prod/lingua-${VERSION}.tar.gz" "$archive_path"
    
    echo "✅ Created: $archive_path"
    
    # Create install script for this platform
    create_install_script "$os" "$arch" "$VERSION"
}

# Function to create platform-specific install script
create_install_script() {
    local os=$1
    local arch=$2  
    local version=$3
    
    local script_name="_build/releases/install-${os}-${arch}.sh"
    
    cat > "$script_name" << EOF
#!/bin/bash
set -e

# Lingua Installation Script for $os-$arch
echo "🌯 Installing Lingua ${version} for $os-$arch"

# Detect if running on correct platform
CURRENT_OS="unknown"
CURRENT_ARCH="unknown"

if [[ "\$OSTYPE" == "darwin"* ]]; then
    CURRENT_OS="macos"
elif [[ "\$OSTYPE" == "linux-gnu"* ]]; then
    CURRENT_OS="linux"
elif [[ "\$OSTYPE" == "msys" ]] || [[ "\$OSTYPE" == "win32" ]]; then
    CURRENT_OS="windows"
fi

if [[ \$(uname -m) == "x86_64" ]]; then
    CURRENT_ARCH="x64"
elif [[ \$(uname -m) == "arm64" ]] || [[ \$(uname -m) == "aarch64" ]]; then
    CURRENT_ARCH="arm64"
fi

if [[ "\$CURRENT_OS" != "$os" ]] || [[ "\$CURRENT_ARCH" != "$arch" ]]; then
    echo "⚠️  Warning: This installer is for $os-$arch, but detected \$CURRENT_OS-\$CURRENT_ARCH"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Set install directory
INSTALL_DIR="/usr/local/lingua"
BIN_DIR="/usr/local/bin"

# Create install directory
echo "📦 Creating installation directory..."
sudo mkdir -p "\$INSTALL_DIR"

# Download release if not provided
if [ -n "\$LINGUA_RELEASE_FILE" ] && [ -f "\$LINGUA_RELEASE_FILE" ]; then
    echo "📁 Using provided release file: \$LINGUA_RELEASE_FILE"
    sudo tar -xzf "\$LINGUA_RELEASE_FILE" -C "\$INSTALL_DIR"
else
    RELEASE_URL="https://github.com/middleFiddle/lingua/releases/download/v${version}/lingua-${os}-${arch}-${version}.tar.gz"
    echo "⬇️  Downloading Lingua release..."
    echo "   \$RELEASE_URL"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "\$RELEASE_URL" | sudo tar -xzf - -C "\$INSTALL_DIR"
    elif command -v wget >/dev/null 2>&1; then
        wget -O - "\$RELEASE_URL" | sudo tar -xzf - -C "\$INSTALL_DIR"
    else
        echo "❌ Neither curl nor wget found. Cannot download release."
        exit 1
    fi
fi

# Create CLI wrapper
echo "🔧 Creating CLI wrapper..."
sudo tee "\$BIN_DIR/lingua" > /dev/null << 'CLI_EOF'
#!/bin/bash
LINGUA_HOME="/usr/local/lingua"
COMMAND="\$1"
shift

case "\$COMMAND" in
    "extract"|"translate"|"generate"|"setup")
        exec "\$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\\\"\$COMMAND\\\"] ++ System.argv())" -- "\$@"
        ;;
    "--help"|"-h"|"help")
        exec "\$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\\\"--help\\\"])"
        ;;
    "--version"|"-v"|"version")
        exec "\$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\\\"--version\\\"])"
        ;;
    "")
        exec "\$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([])"
        ;;
    *)
        echo "Unknown command: \$COMMAND"
        exec "\$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\\\"--help\\\"])"
        ;;
esac
CLI_EOF

# Make wrapper executable
sudo chmod +x "\$BIN_DIR/lingua"

# Test installation
echo "✅ Testing installation..."
if "\$BIN_DIR/lingua" --version; then
    echo ""
    echo "🎉 Lingua installed successfully!"
    echo ""
    echo "🚀 Quick Start:"
    echo "   cd your-project"
    echo "   lingua setup"
    echo "   lingua extract --source-dir src --pattern-type i18n"
    echo "   lingua translate --to es,fr,de"
    echo "   lingua generate --output-template \\\"public/locales/{lang}/{filename}.json\\\""
else
    echo "❌ Installation test failed"
    exit 1
fi
EOF

    chmod +x "$script_name"
    echo "📝 Created installer: $script_name"
}

echo ""
echo "🚀 Building releases for all platforms..."

# Build for different platforms
# Note: Elixir releases are portable within the same OS family
build_release "host" "linux" "x64"
build_release "host" "linux" "arm64" 
build_release "host" "macos" "x64"
build_release "host" "macos" "arm64"
build_release "host" "windows" "x64"

echo ""
echo "✅ All releases built successfully!"
echo ""
echo "📦 Available releases:"
ls -la _build/releases/*.tar.gz

echo ""
echo "📝 Install scripts:"  
ls -la _build/releases/install-*.sh

echo ""
echo "🎯 To test locally:"
echo "   LINGUA_RELEASE_FILE=_build/releases/lingua-linux-x64-${VERSION}.tar.gz _build/releases/install-linux-x64.sh"