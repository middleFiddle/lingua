#!/bin/bash
set -e

# LinguaCore Installation Script for React/React Native Developers
# This installs the full AI-powered translation pipeline

echo "🌯 Installing LinguaCore - The AI-Powered Translation Build Tool"
echo ""

# Detect OS
OS="unknown"
ARCH="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
fi

# Detect architecture  
if [[ $(uname -m) == "x86_64" ]]; then
    ARCH="x64"
elif [[ $(uname -m) == "arm64" ]] || [[ $(uname -m) == "aarch64" ]]; then
    ARCH="arm64"
fi

echo "Detected: $OS-$ARCH"

# Set install directory
INSTALL_DIR="/usr/local/lingua"
BIN_DIR="/usr/local/bin"

# Create install directory
echo "📦 Creating installation directory..."
sudo mkdir -p "$INSTALL_DIR"

# Download and extract release
if [ -n "$LINGUA_RELEASE_FILE" ] && [ -f "$LINGUA_RELEASE_FILE" ]; then
    echo "📁 Using provided release file: $LINGUA_RELEASE_FILE"
    sudo tar -xzf "$LINGUA_RELEASE_FILE" -C "$INSTALL_DIR" 
elif [ -f "_build/prod/lingua-0.1.0.tar.gz" ]; then
    echo "📁 Using local build..."
    sudo tar -xzf "_build/prod/lingua-0.1.0.tar.gz" -C "$INSTALL_DIR" 
else
    RELEASE_URL="https://github.com/middleFiddle/lingua/releases/download/v0.1.0/lingua-$OS-$ARCH.tar.gz"
    echo "⬇️  Downloading Lingua release..."
    echo "   $RELEASE_URL"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "$RELEASE_URL" | sudo tar -xzf - -C "$INSTALL_DIR" 
    elif command -v wget >/dev/null 2>&1; then
        wget -O - "$RELEASE_URL" | sudo tar -xzf - -C "$INSTALL_DIR" 
    else
        echo "❌ Neither curl nor wget found. Cannot download release."
        exit 1
    fi
fi

# Create wrapper script
echo "🔧 Creating CLI wrapper..."
sudo tee "$BIN_DIR/lingua" > /dev/null << 'EOF'
#!/bin/bash
# LinguaCore CLI Wrapper
# This makes the Elixir release work like a native CLI tool

LINGUA_HOME="/usr/local/lingua"
COMMAND="$1"
shift

case "$COMMAND" in
    "extract"|"translate"|"generate"|"setup")
        # Use eval to run our CLI with the command
        exec "$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\"$COMMAND\"] ++ System.argv())" -- "$@"
        ;;
    "--help"|"-h"|"help")
        exec "$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\"--help\"])"
        ;;
    "--version"|"-v"|"version")
        exec "$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\"--version\"])"
        ;;
    "")
        exec "$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([])"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        exec "$LINGUA_HOME/bin/lingua" eval "Lingua.CLI.main([\"--help\"])"
        ;;
esac
EOF

# Make wrapper executable
sudo chmod +x "$BIN_DIR/lingua"

# Test installation
echo "✅ Testing installation..."
if "$BIN_DIR/lingua" --version; then
    echo ""
    echo "🎉 LinguaCore installed successfully!"
    echo ""
    echo "🚀 Quick Start for React/React Native:"
    echo "   cd your-react-project"
    echo "   lingua setup                                    # Download AI models (one-time)"
    echo "   lingua extract --source-dir src --pattern-type i18n"
    echo "   lingua translate --to es,fr,de"
    echo "   lingua generate --output-template \"public/locales/{lang}/{filename}.json\""
    echo ""
    echo "📚 Full documentation: https://github.com/yourorg/lingua-core"
else
    echo "❌ Installation test failed"
    exit 1
fi