#!/bin/bash

print_msg() {
    local type="$1"
    local message="$2"
    case "$type" in
        "info") echo "[INFO] $message" ;;
        "warning") echo "[WARNING] $message" ;;
        "error") echo "[ERROR] $message" ;;
        *) echo "$message" ;;
    esac
}

check_dependencies() {
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_msg "error" "curl is not installed. Please install it using your package manager."
        exit 1
    fi

    # Check if unrar is installed
    if ! command -v unrar &> /dev/null; then
        print_msg "error" "unrar is not installed. Please install it using your package manager."
        exit 1
    fi
}

download_bios() {
    print_msg "info" "Downloading necessary BIOS files..."
    BIOS_DIR="$USER_HOME/RetroArch/system"
    mkdir -p "$BIOS_DIR"

    # BIOS file and its download URL
    BIOS_FILE="RetroArch_BIOS_System_Files.rar"
    DOWNLOAD_URL="https://archive.org/download/retro-arch-bios-files/RetroArch%20BIOS%20System%20Files.rar"

    print_msg "info" "Downloading $BIOS_FILE from $DOWNLOAD_URL..."
    
    # Download the BIOS file
    if curl -L -o "$BIOS_DIR/$BIOS_FILE" "$DOWNLOAD_URL"; then
        print_msg "info" "$BIOS_FILE downloaded successfully."
    else
        print_msg "error" "Failed to download $BIOS_FILE."
        return 1
    fi

    # Extract the downloaded .rar file
    print_msg "info" "Extracting $BIOS_FILE..."
    unrar x "$BIOS_DIR/$BIOS_FILE" "$BIOS_DIR/"
    print_msg "info" "Extraction completed."

    # Optionally, remove the .rar file after extraction
    rm "$BIOS_DIR/$BIOS_FILE"

    print_msg "warning" "BIOS files must be manually verified and configured if necessary."

    chown -R "${SUDO_USER:-$USER}" "$BIOS_DIR"
}

# Check for required dependencies
check_dependencies

# Call the function
download_bios
