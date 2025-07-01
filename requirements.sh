#!/bin/bash

# requirements.sh - Automated setup script for Web Security Scanner Toolkit Prerequisites

# --- Configuration ---
GO_VERSION_REQUIRED="1.18" # Minimum Go version required for tools like Nuclei/Subfinder

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_sudo() {
    if ! command -v sudo &> /dev/null; then
        print_error "sudo is not installed. Please install sudo or run this script as root directly."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|kali)
                OS_TYPE="DEBIAN"
                PACKAGE_MANAGER="apt"
                ;;
            centos|rhel|fedora)
                OS_TYPE="REDHAT"
                PACKAGE_MANAGER="yum" # or dnf for newer Fedora/RHEL
                ;;
            *)
                OS_TYPE="UNKNOWN"
                ;;
        esac
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        OS_TYPE="MACOS"
        PACKAGE_MANAGER="brew"
    else
        OS_TYPE="UNKNOWN"
    fi

    if [[ "$OS_TYPE" == "UNKNOWN" ]]; then
        print_error "Unsupported operating system. This script supports Debian/Ubuntu/Kali, CentOS/RHEL, and macOS."
        exit 1
    fi
    print_info "Detected OS: ${OS_TYPE} using ${PACKAGE_MANAGER}"
}

install_package() {
    PACKAGE_NAME=$1
    TOOL_NAME=$2 # User-friendly name for the tool/package
    print_info "Installing ${TOOL_NAME}..."
    case "$PACKAGE_MANAGER" in
        apt)
            sudo apt update && sudo apt install -y "$PACKAGE_NAME"
            ;;
        yum)
            sudo yum install -y "$PACKAGE_NAME"
            ;;
        brew)
            brew install "$PACKAGE_NAME"
            ;;
        *)
            print_error "Unsupported package manager for installing ${TOOL_NAME}."
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        print_success "${TOOL_NAME} installed successfully."
        return 0
    else
        print_error "Failed to install ${TOOL_NAME}."
        return 1
    fi
}

# --- Main Script Execution ---
check_sudo
detect_os

# --- Go Installation Check and Setup ---
print_info "Checking Go installation and environment..."
if ! command -v go &> /dev/null; then
    print_error "Go is not installed. Please install Go ${GO_VERSION_REQUIRED}+ manually first."
    print_error "Refer to https://golang.org/doc/install for instructions."
    print_error "Exiting. Please run this script again after Go is installed."
    exit 1
fi

GO_CURRENT_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
if printf '%s\n' "$GO_VERSION_REQUIRED" "$GO_CURRENT_VERSION" | sort -V -C; then
    print_success "Go version ${GO_CURRENT_VERSION} is installed and meets the minimum requirement (${GO_VERSION_REQUIRED})."
else
    print_warning "Go version ${GO_CURRENT_VERSION} is installed, but it's older than the recommended ${GO_VERSION_REQUIRED}. Some tools might not work correctly."
    print_warning "Consider updating Go: https://golang.org/doc/install"
fi

# Set persistent Go environment variables in ~/.bashrc for the root user
BASHRC_FILE="/root/.bashrc" # Assuming you're running as root
if [ ! -f "$BASHRC_FILE" ]; then
    print_warning "Could not find ${BASHRC_FILE}. Go environment variables might not be persistent."
    print_warning "Please ensure your shell's config file (e.g., ~/.bashrc) is correctly set up for Go."
else
    # Check if Go env vars are already in .bashrc
    if ! grep -q "export GOROOT" "$BASHRC_FILE" || \
       ! grep -q "export GOPATH" "$BASHRC_FILE" || \
       ! grep -q "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" "$BASHRC_FILE"; then
        print_info "Adding Go environment variables to ${BASHRC_FILE}..."
        echo "" >> "$BASHRC_FILE"
        echo "# Go Language Environment Variables (Added by requirements.sh)" >> "$BASHRC_FILE"
        echo "export GOROOT=/usr/local/go" >> "$BASHRC_FILE" # Standard Go installation path
        echo "export GOPATH=\$HOME/go" >> "$BASHRC_FILE"
        echo "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" >> "$BASHRC_FILE"
        print_success "Go environment variables added to ${BASHRC_FILE}."
        print_info "Please run 'source ${BASHRC_FILE}' or restart your terminal for changes to take effect."
        # Source it for the current session immediately
        source "$BASHRC_FILE"
    else
        print_info "Go environment variables already present in ${BASHRC_FILE}."
        # Ensure it's sourced for the current session
        source "$BASHRC_FILE"
    fi
fi

# --- Install Go-based Tools ---
print_info "Installing Go-based security tools..."

# subfinder
if ! command -v subfinder &> /dev/null; then
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    if [ $? -eq 0 ]; then
        print_success "subfinder installed successfully."
    else
        print_error "Failed to install subfinder."
    fi
else
    print_info "subfinder is already installed."
fi

# nuclei
if ! command -v nuclei &> /dev/null; then
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    if [ $? -eq 0 ]; then
        print_success "nuclei installed successfully."
    else
        print_error "Failed to install nuclei."
    fi
else
    print_info "nuclei is already installed."
fi

# --- Install System-level Tools ---
print_info "Installing system-level tools (dig, whois)..."

# dig (dnsutils/bind-utils)
if ! command -v dig &> /dev/null; then
    if [[ "$OS_TYPE" == "DEBIAN" ]]; then
        install_package "dnsutils" "dig (dnsutils)"
    elif [[ "$OS_TYPE" == "REDHAT" ]]; then
        install_package "bind-utils" "dig (bind-utils)"
    elif [[ "$OS_TYPE" == "MACOS" ]]; then
        install_package "dnsutils" "dig (dnsutils)" # Homebrew package name
    fi
else
    print_info "dig is already installed."
fi

# whois
if ! command -v whois &> /dev/null; then
    if [[ "$OS_TYPE" == "DEBIAN" ]]; then
        install_package "whois" "whois"
    elif [[ "$OS_TYPE" == "REDHAT" ]]; then
        install_package "whois" "whois"
    elif [[ "$OS_TYPE" == "MACOS" ]]; then
        install_package "whois" "whois"
    fi
else
    print_info "whois is already installed."
fi

# --- Update Nuclei Templates ---
print_info "Updating Nuclei templates (this may take a while)..."
if command -v nuclei &> /dev/null; then
    nuclei -update-templates
    if [ $? -eq 0 ]; then
        print_success "Nuclei templates updated successfully."
    else
        print_error "Failed to update Nuclei templates. Please try running 'nuclei -update-templates' manually."
    fi
else
    print_warning "Nuclei not found, skipping template update."
fi

print_success "All specified prerequisites checked/installed. You should now be ready to run your scanner."
print_info "Remember to restart your terminal or run 'source ~/.bashrc' if prompted earlier."
print_info "Also, ensure ParamSpider and WhatWaf Python tools are correctly cloned and their Python dependencies installed."
print_info "For WhatWaf, remember the manual step: 'sudo mkdir -p /root/.whatwaf/files/ && sudo cp /home/kali/Desktop/Project1/tools/WhatWaf/files/default_payloads.lst /root/.whatwaf/files/'"
