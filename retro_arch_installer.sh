#!/bin/bash

# RetroArch Auto-Installer and Configuration Script
#does not discriminate on the version of linux yuou are using 

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display messages with colors
print_msg() {
    case $1 in
        "info") echo -e "${BLUE}[INFO]${NC} $2" ;;
        "success") echo -e "${GREEN}[SUCCESS]${NC} $2" ;;
        "warning") echo -e "${YELLOW}[WARNING]${NC} $2" ;;
        "error") echo -e "${RED}[ERROR]${NC} $2" ;;
        *) echo -e "$2" ;;
    esac
}

# Function to check if script is run with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_msg "error" "This script requires root privileges to run."
        print_msg "info" "Please run with sudo: sudo $0"
        exit 1
    fi
}

# Function to detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf check-update"
        PKG_INSTALL="dnf install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum check-update"
        PKG_INSTALL="yum install -y"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_INSTALL="pacman -S --noconfirm"
    else
        print_msg "error" "Unable to detect package manager. Supported: apt, dnf, yum, pacman"
        exit 1
    fi
    print_msg "info" "Detected package manager: $PKG_MANAGER"
}

# Function to install RetroArch
install_retroarch() {
    print_msg "info" "Updating package lists..."
    $PKG_UPDATE

    print_msg "info" "Installing RetroArch and dependencies..."
    
    case $PKG_MANAGER in
        "apt")
            $PKG_INSTALL retroarch libretro-* mesa-utils glshim
            ;;
        "dnf" | "yum")
            $PKG_INSTALL retroarch mesa-libGL mesa-dri-drivers
            ;;
        "pacman")
            $PKG_INSTALL retroarch libretro mesa
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_msg "success" "RetroArch installed successfully."
    else
        print_msg "error" "Failed to install RetroArch. Please check the error messages above."
        exit 1
    fi
}

# Function to create directories and download configurations
setup_directories() {
    print_msg "info" "Setting up RetroArch directories..."
    
    # Get the current user's home directory
    if [ "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME=$HOME
    fi
    
    # Create necessary directories
    RETROARCH_DIR="$USER_HOME/.config/retroarch"
    ROMS_DIR="$USER_HOME/RetroArch/roms"
    SYSTEM_DIR="$USER_HOME/RetroArch/system"
    SAVES_DIR="$USER_HOME/RetroArch/saves"
    STATES_DIR="$USER_HOME/RetroArch/states"
    
    mkdir -p "$RETROARCH_DIR"
    mkdir -p "$ROMS_DIR"/{nes,snes,genesis,gba,n64,psx,arcade,mame,gb,gbc}
    mkdir -p "$SYSTEM_DIR"
    mkdir -p "$SAVES_DIR"
    mkdir -p "$STATES_DIR"
    
    # Set correct ownership for the created directories
    if [ "$SUDO_USER" ]; then
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/retroarch"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/RetroArch"
    fi
    
    print_msg "success" "Directories created successfully."
}

# Function to download and install cores
install_cores() {
    print_msg "info" "Installing common RetroArch cores..."
    
    # Use package manager to install cores if supported
    case $PKG_MANAGER in
        "apt")
            $PKG_INSTALL libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba libretro-genesisplusgx libretro-desmume
            ;;
        "dnf" | "yum")
            $PKG_INSTALL libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba libretro-genesisplusgx
            ;;
        "pacman")
            $PKG_INSTALL libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba libretro-genesis-plus-gx
            ;;
    esac
    
    print_msg "success" "Core installation completed."
}

# Function to configure RetroArch
configure_retroarch() {
    print_msg "info" "Configuring RetroArch..."
    
    if [ "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME=$HOME
    fi
    
    CONFIG_FILE="$USER_HOME/.config/retroarch/retroarch.cfg"
    
    # Run RetroArch once to generate default config
    if [ "$SUDO_USER" ]; then
        su - "$SUDO_USER" -c "retroarch --config $CONFIG_FILE --menu --quit"
    else
        retroarch --config "$CONFIG_FILE" --menu --quit
    fi
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_msg "warning" "RetroArch config file not found. Creating a basic one."
        
        # Create a basic configuration file
        cat > "$CONFIG_FILE" << EOL
# RetroArch Configuration
video_driver = "gl"
audio_driver = "alsa"
input_driver = "udev"
menu_driver = "xmb"
libretro_directory = "${USER_HOME}/.config/retroarch/cores"
libretro_info_path = "${USER_HOME}/.config/retroarch/cores/info"
content_directory = "${USER_HOME}/RetroArch/roms"
system_directory = "${USER_HOME}/RetroArch/system"
savefile_directory = "${USER_HOME}/RetroArch/saves"
savestate_directory = "${USER_HOME}/RetroArch/states"
rgui_browser_directory = "${USER_HOME}/RetroArch/roms"
video_fullscreen = "true"
video_smooth = "true"
audio_rate_control = "true"
EOL

        if [ "$SUDO_USER" ]; then
            chown "$SUDO_USER":"$SUDO_USER" "$CONFIG_FILE"
        fi
    else
        # Update existing configuration with our paths
        sed -i "s|^content_directory =.*|content_directory = \"${USER_HOME}/RetroArch/roms\"|" "$CONFIG_FILE"
        sed -i "s|^system_directory =.*|system_directory = \"${USER_HOME}/RetroArch/system\"|" "$CONFIG_FILE"
        sed -i "s|^savefile_directory =.*|savefile_directory = \"${USER_HOME}/RetroArch/saves\"|" "$CONFIG_FILE"
        sed -i "s|^savestate_directory =.*|savestate_directory = \"${USER_HOME}/RetroArch/states\"|" "$CONFIG_FILE"
    fi
    
    print_msg "success" "RetroArch configured successfully."
}

# Create a desktop shortcut
create_desktop_shortcut() {
    print_msg "info" "Creating desktop shortcut..."
    
    if [ "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME=$HOME
    fi
    
    DESKTOP_FILE="$USER_HOME/Desktop/retroarch.desktop"
    
    cat > "$DESKTOP_FILE" << EOL
[Desktop Entry]
Type=Application
Name=RetroArch
Comment=Frontend for emulators, game engines and media players
Exec=retroarch
Icon=retroarch
Terminal=false
Categories=Game;Emulator;
EOL

    if [ "$SUDO_USER" ]; then
        chown "$SUDO_USER":"$SUDO_USER" "$DESKTOP_FILE"
    fi
    
    chmod +x "$DESKTOP_FILE"
    
    print_msg "success" "Desktop shortcut created."
}

# Main function
main() {
    print_msg "info" "RetroArch Auto-Installer and Configuration Script"
    print_msg "info" "Starting installation process..."
    
    check_root
    detect_package_manager
    install_retroarch
    setup_directories
    install_cores
    configure_retroarch
    create_desktop_shortcut
    
    print_msg "success" "RetroArch has been successfully installed and configured!"
    print_msg "info" "You can now launch RetroArch from your applications menu or desktop shortcut."
    print_msg "info" "Your ROM files should be placed in the following directory:"
    if [ "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME=$HOME
    fi
    print_msg "info" "$USER_HOME/RetroArch/roms/<system>/"
}

# Execute main function
main
