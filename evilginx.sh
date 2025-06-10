#!/bin/bash
set -e

# Function to print error messages and exit
error_exit() {
  echo "❌ Error: $1" >&2
  exit 1
}

# Function to print success messages
success_msg() {
  echo "✅ $1"
}

# Function to print info messages
info_msg() {
  echo "🔄 $1"
}

# Function to print warning messages
warn_msg() {
  echo "⚠️  $1"
}

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to get Go version
get_go_version() {
  if command_exists go; then
    go version | awk '{print $3}' | sed 's/go//'
  else
    echo "not_installed"
  fi
}

# Configuration
EVILGINX_REPO="https://github.com/kgretzky/evilginx2.git"
DEFAULT_INSTALL_DIR="$HOME/evilginx"
LOG_FILE="$HOME/evilginx_install.log"

# Parse command line arguments
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
FORCE_REINSTALL=false
BUILD_BINARY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--directory)
      INSTALL_DIR="$2"
      shift 2
      ;;
    -f|--force)
      FORCE_REINSTALL=true
      shift
      ;;
    -b|--build)
      BUILD_BINARY=true
      shift
      ;;
    -h|--help)
      echo "Evilginx Installation Script"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -d, --directory DIR   Install to specific directory (default: $DEFAULT_INSTALL_DIR)"
      echo "  -f, --force          Force reinstall even if directory exists"
      echo "  -b, --build          Build the binary after download"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                           # Install to default directory"
      echo "  $0 -d /opt/evilginx         # Install to /opt/evilginx"
      echo "  $0 -f -b                    # Force reinstall and build binary"
      exit 0
      ;;
    *)
      error_exit "Unknown option: $1. Use -h for help."
      ;;
  esac
done

# Set up logging
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "========================================="
echo "🎯 Evilginx Installation Script"
echo "========================================="
echo "📝 Log file: $LOG_FILE"
echo "📁 Install directory: $INSTALL_DIR"
echo ""

# Check required dependencies
info_msg "Checking system dependencies..."
for cmd in git curl; do
  if ! command_exists "$cmd"; then
    error_exit "$cmd is required but not installed. Please install it first."
  fi
done
success_msg "System dependencies check passed"

# Check Go installation
info_msg "Checking Go installation..."
GO_VERSION=$(get_go_version)
if [ "$GO_VERSION" = "not_installed" ]; then
  error_exit "Go is not installed or not in PATH. Please install Go first."
fi
success_msg "Go $GO_VERSION is installed"

# Check Go version compatibility (Evilginx requires Go 1.19+)
GO_MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
GO_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)
if [ "$GO_MAJOR" -lt 1 ] || ([ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 19 ]); then
  warn_msg "Go version $GO_VERSION detected. Evilginx may require Go 1.19 or higher."
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error_exit "Installation cancelled by user"
  fi
fi

# Check if installation directory exists
if [ -d "$INSTALL_DIR" ]; then
  if [ "$FORCE_REINSTALL" = true ]; then
    warn_msg "Removing existing installation at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR" || error_exit "Failed to remove existing installation"
  else
    error_exit "Directory $INSTALL_DIR already exists. Use -f to force reinstall or choose a different directory with -d"
  fi
fi

# Create parent directory if it doesn't exist
PARENT_DIR=$(dirname "$INSTALL_DIR")
if [ ! -d "$PARENT_DIR" ]; then
  info_msg "Creating parent directory: $PARENT_DIR"
  mkdir -p "$PARENT_DIR" || error_exit "Failed to create parent directory"
fi

# Clone Evilginx repository
info_msg "Cloning Evilginx repository..."
git clone "$EVILGINX_REPO" "$INSTALL_DIR" || error_exit "Failed to clone Evilginx repository"

# Change to installation directory
cd "$INSTALL_DIR" || error_exit "Failed to change to installation directory"

# Get available versions
info_msg "Fetching available versions..."
git fetch --tags >/dev/null 2>&1

# Get latest release tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
CURRENT_BRANCH=$(git branch --show-current)

if [ -n "$LATEST_TAG" ]; then
  info_msg "Latest release: $LATEST_TAG"
  info_msg "Current branch: $CURRENT_BRANCH"
  
  # Ask user which version to use
  echo ""
  echo "Available options:"
  echo "1) Latest release ($LATEST_TAG) - Recommended"
  echo "2) Development branch ($CURRENT_BRANCH) - Latest features but potentially unstable"
  echo ""
  read -p "Choose version (1 or 2, default: 1): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[2]$ ]]; then
    info_msg "Using development branch: $CURRENT_BRANCH"
  else
    info_msg "Checking out latest release: $LATEST_TAG"
    git checkout "$LATEST_TAG" >/dev/null 2>&1 || error_exit "Failed to checkout latest release"
  fi
else
  info_msg "No releases found, using main branch"
fi

# Get final version info
CURRENT_COMMIT=$(git rev-parse --short HEAD)
CURRENT_REF=$(git describe --tags --exact-match 2>/dev/null || git branch --show-current)

success_msg "Evilginx downloaded successfully"
success_msg "Version: $CURRENT_REF ($CURRENT_COMMIT)"

# Build binary if requested
if [ "$BUILD_BINARY" = true ]; then
  info_msg "Building Evilginx binary..."
  
  # Check if go.mod exists and run go mod tidy
  if [ -f "go.mod" ]; then
    info_msg "Updating Go modules..."
    go mod tidy || error_exit "Failed to update Go modules"
  fi
  
  # Build the binary
  go build -o evilginx -ldflags "-s -w" . || error_exit "Failed to build Evilginx binary"
  
  # Make binary executable
  chmod +x evilginx || error_exit "Failed to make binary executable"
  
  success_msg "Binary built successfully: $INSTALL_DIR/evilginx"
  
  # Test the binary
  info_msg "Testing binary..."
  if ./evilginx -h >/dev/null 2>&1; then
    success_msg "Binary test passed"
  else
    warn_msg "Binary test failed, but binary was created"
  fi
fi

echo ""
echo "========================================="
echo "🎉 Installation Complete!"
echo "========================================="
echo "📁 Installation directory: $INSTALL_DIR"
echo "🏷️  Version: $CURRENT_REF ($CURRENT_COMMIT)"

if [ "$BUILD_BINARY" = true ]; then
  echo "🔧 Binary: $INSTALL_DIR/evilginx"
  echo ""
  echo "🚀 Quick start:"
  echo "   cd $INSTALL_DIR"
  echo "   ./evilginx"
else
  echo ""
  echo "🔧 To build Evilginx:"
  echo "   cd $INSTALL_DIR"
  echo "   go build -o evilginx ."
  echo ""
  echo "🚀 To run after building:"
  echo "   ./evilginx"
fi

echo ""
echo "📚 Documentation: https://help.evilginx.com/"
echo "🐛 Issues: https://github.com/kgretzky/evilginx2/issues"
echo "📋 Log file: $LOG_FILE"

# Optional: Add to PATH suggestion
if [ "$BUILD_BINARY" = true ]; then
  echo ""
  echo "💡 Tip: To use evilginx from anywhere, add to your PATH:"
  echo "   echo 'export PATH=\$PATH:$INSTALL_DIR' >> ~/.bashrc"
  echo "   source ~/.bashrc"
fi

echo ""
success_msg "Installation completed successfully!"

exit 0