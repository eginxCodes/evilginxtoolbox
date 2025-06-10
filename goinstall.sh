#!/bin/bash
set -e

# Function to print error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Check if required commands are available
for cmd in curl tar; do
  command -v "$cmd" >/dev/null 2>&1 || error_exit "$cmd is required but not installed. Please install it and rerun the script."
done

# Fetch the latest version of Go dynamically
LATEST_GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1 | sed 's/go//') \
  || error_exit "Failed to fetch the latest Go version."
GO_URL="https://go.dev/dl/go${LATEST_GO_VERSION}.linux-amd64.tar.gz"

# Log output of script
LOG_FILE="$HOME/install_go.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# Update package list and install required dependencies
echo "Updating package manager and installing necessary packages..."
sudo apt update && sudo apt install -y curl tar || error_exit "Failed to update packages or install dependencies."

# Download Go
echo "Downloading Go ${LATEST_GO_VERSION}..."
curl -OL "${GO_URL}" || error_exit "Failed to download Go binary."

# Remove existing Go installation if it exists
if [ -d "/usr/local/go" ]; then
  echo "Removing existing Go installation..."
  sudo rm -rf /usr/local/go || error_exit "Failed to remove existing Go installation."
fi

# Extract the tarball
echo "Extracting Go tarball..."
sudo tar -C /usr/local -xzf "go${LATEST_GO_VERSION}.linux-amd64.tar.gz" || error_exit "Failed to extract Go tarball."

# Clean up downloaded files
echo "Cleaning up downloaded files..."
rm "go${LATEST_GO_VERSION}.linux-amd64.tar.gz" || error_exit "Failed to clean up downloaded files."

# Set up Go environment PATH
if [ -d /etc/profile.d ]; then
  echo "Setting up system-wide Go environment..."
  sudo bash -c 'echo "export PATH=\$PATH:/usr/local/go/bin" > /etc/profile.d/go.sh'
  # Source the file so the current session picks it up immediately.
  source /etc/profile.d/go.sh || error_exit "Failed to source /etc/profile.d/go.sh."
else
  echo "Setting up user-specific Go environment..."
  PROFILE_FILE="$HOME/.profile"
  if [ ! -f "$PROFILE_FILE" ]; then
    touch "$PROFILE_FILE" || error_exit "Failed to create .profile file."
  fi
  if ! grep -q 'export PATH=\$PATH:/usr/local/go/bin' "$PROFILE_FILE"; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$PROFILE_FILE" || error_exit "Failed to update PATH in .profile."
  fi
  export PATH=$PATH:/usr/local/go/bin || error_exit "Failed to export PATH."
fi

# Verify installation
echo "Verifying Go installation..."
go version || error_exit "Go installation failed."

echo "Go ${LATEST_GO_VERSION} has been installed successfully."

exit 0