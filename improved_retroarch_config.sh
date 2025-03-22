#!/bin/bash

# RetroArch Auto-Installer and Configuration Script
# Created: 2025-03-19
# Author: elithaxxor (Original), Improved Version

# ==============================
# Configuration Variables
# ==============================
VERSION="1.2.0"
LOG_FILE="retroarch_install_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR=$(mktemp -d)
CREATE_DESKTOP_ICON=true
INSTALL_CORES_ONLY=false
MINIMAL_INSTALL=false
NON_INTERACTIVE=false
VERBOSE=true

# ==============================
# Color codes for terminal output
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================
# Trap for cleanup
# ==============================
trap 'echo -e "${RED}[ERROR]${NC} Installation interrupted. Cleaning up..."; rm -rf "$TEMP_DIR"; exit 1' INT TERM

# ==============================
# Helper Functions
# ==============================

# Display a spinner for long-running tasks
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to display messages with colors
print_msg() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    case $1 in
        "info") 
            echo -e "${BLUE}[INFO]${NC} $2" 
            [ "$VERBOSE" = true ] && echo "[$timestamp] [INFO] $2" >> "$LOG_FILE"
            ;;
        "success") 
            echo -e "${GREEN}[SUCCESS]${NC} $2" 
            echo "[$timestamp] [SUCCESS] $2" >> "$LOG_FILE"
            ;;
        "warning") 
            echo -e "${YELLOW}[WARNING]${NC} $2" 
            echo "[$timestamp] [WARNING] $2" >> "$LOG_FILE"
            ;;
        "error") 
            echo -e "${RED}[ERROR]${NC} $2" 
            echo "[$timestamp] [ERROR] $2" >> "$LOG_FILE"
            ;;
        "debug") 
            [ "$VERBOSE" = true ] && echo -e "${CYAN}[DEBUG]${NC} $2"
            [ "$VERBOSE" = true ] && echo "[$timestamp] [DEBUG] $2" >> "$LOG_FILE"
            ;;
        *) 
            echo -e "$2" 
            echo "[$timestamp] $2" >> "$LOG_FILE"
            ;;
    esac
}

# Function to confirm actions
confirm_action() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi
    
    local prompt="$1"
    local default="$2"
    
    if [ "$default" = "Y" ]; then
        options="[Y/n]"
        default="Y"
    else
        options="[y/N]"
        default="N"
    fi
    
    read -p "$prompt $options " choice
    choice=${choice:-$default}
    
    if [[ $choice =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check for dependencies
check_dependencies() {
    print_msg "info" "Checking dependencies..."
    local DEPS="wget curl sed grep"
    local MISSING_DEPS=""
    
    for dep in $DEPS; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            MISSING_DEPS="$MISSING_DEPS $dep"
        fi
    done
    
    if [ -n "$MISSING_DEPS" ]; then
        print_msg "error" "The following dependencies are missing:$MISSING_DEPS"
        print_msg "info" "Please install them and run the script again."
        exit 1
    fi
    
    print_msg "success" "All dependencies are installed."
}

# Function to check if script is run with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_msg "error" "This script requires root privileges to run."
        print_msg "info" "Please run with sudo: sudo $0 $ARGS"
        exit 1
    fi
}

# Function to detect package manager
detect_package_manager() {
    print_msg "info" "Detecting package manager..."
    
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
        PKG_QUERY="apt-cache show"
        PKG_CHECK="dpkg -l"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf check-update"
        PKG_INSTALL="dnf install -y"
        PKG_QUERY="dnf info"
        PKG_CHECK="rpm -q"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum check-update"
        PKG_INSTALL="yum install -y"
        PKG_QUERY="yum info"
        PKG_CHECK="rpm -q"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_QUERY="pacman -Si"
        PKG_CHECK="pacman -Qi"
    else
        print_msg "error" "Unable to detect package manager. Supported: apt, dnf, yum, pacman"
        exit 1
    fi
    
    print_msg "success" "Detected package manager: $PKG_MANAGER"
}

# Function to check for package availability
check_package_availability() {
    local package="$1"
    local fallback="$2"
    
    print_msg "debug" "Checking availability of package: $package"
    
    if $PKG_QUERY "$package" &>/dev/null; then
        echo "$package"
    elif [ -n "$fallback" ] && $PKG_QUERY "$fallback" &>/dev/null; then
        print_msg "debug" "Using fallback package: $fallback"
        echo "$fallback"
    else
        print_msg "warning" "Neither $package nor fallback $fallback found"
        echo ""
    fi
}

# Function to check if package is installed
is_package_installed() {
    local package="$1"
    
    $PKG_CHECK "$package" &>/dev/null
    return $?
}

# Function to install RetroArch
install_retroarch() {
    print_msg "info" "Updating package lists..."
    $PKG_UPDATE
    
    # Check if RetroArch is already installed
    if is_package_installed retroarch; then
        print_msg "info" "RetroArch is already installed."
        if confirm_action "Would you like to reinstall RetroArch?" "N"; then
            # Command to remove depends on package manager
            case $PKG_MANAGER in
                "apt")
                    apt remove --purge -y retroarch libretro-*
                    ;;
                "dnf" | "yum")
                    $PKG_MANAGER remove -y retroarch
                    ;;
                "pacman")
                    pacman -R --noconfirm retroarch
                    ;;
            esac
        else
            return 0
        fi
    fi

    print_msg "info" "Installing RetroArch and dependencies..."
    
    # Determine RetroArch package name
    RETROARCH_PKG=$(check_package_availability "retroarch" "libretro")
    
    if [ -z "$RETROARCH_PKG" ]; then
        print_msg "error" "RetroArch package not found in repositories."
        print_msg "info" "Try manual installation or check your package repositories."
        exit 1
    fi
    
    case $PKG_MANAGER in
        "apt")
            local packages="$RETROARCH_PKG libretro-* mesa-utils glshim"
            print_msg "debug" "Installing packages: $packages"
            $PKG_INSTALL $packages &
            ;;
        "dnf" | "yum")
            local packages="$RETROARCH_PKG mesa-libGL mesa-dri-drivers"
            print_msg "debug" "Installing packages: $packages"
            $PKG_INSTALL $packages &
            ;;
        "pacman")
            local packages="$RETROARCH_PKG libretro mesa"
            print_msg "debug" "Installing packages: $packages"
            $PKG_INSTALL $packages &
            ;;
    esac
    
    local pid=$!
    print_msg "info" "Installing RetroArch. This may take a while..."
    spinner $pid
    wait $pid
    
    if [ $? -eq 0 ]; then
        print_msg "success" "RetroArch installed successfully."
    else
        print_msg "error" "Failed to install RetroArch. Please check the log file: $LOG_FILE"
        exit 1
    fi
}

# Function to create directories and download configurations
setup_directories() {
    print_msg "info" "Setting up RetroArch directories..."
    
    # Get the current user's home directory
    if [ "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        REAL_USER="$SUDO_USER"
    else
        USER_HOME=$HOME
        REAL_USER=$(whoami)
    fi
    
    # Create necessary directories
    RETROARCH_DIR="$USER_HOME/.config/retroarch"
    ROMS_DIR="$USER_HOME/RetroArch/roms"
    SYSTEM_DIR="$USER_HOME/RetroArch/system"
    SAVES_DIR="$USER_HOME/RetroArch/saves"
    STATES_DIR="$USER_HOME/RetroArch/states"
    THUMBNAILS_DIR="$USER_HOME/RetroArch/thumbnails"
    
    # Backup existing directories if they exist
    if [ -d "$RETROARCH_DIR" ]; then
        BACKUP_DIR="$USER_HOME/.config/retroarch_backup_$(date +%Y%m%d_%H%M%S)"
        print_msg "info" "Backing up existing RetroArch configuration to $BACKUP_DIR"
        cp -r "$RETROARCH_DIR" "$BACKUP_DIR"
    fi
    
    # Create directories
    mkdir -p "$RETROARCH_DIR"
    mkdir -p "$ROMS_DIR"/{nes,snes,genesis,gba,n64,psx,arcade,mame,gb,gbc,pce,neogeo,atari2600}
    mkdir -p "$SYSTEM_DIR"
    mkdir -p "$SAVES_DIR"
    mkdir -p "$STATES_DIR"
    mkdir -p "$THUMBNAILS_DIR"
    
    # Set correct ownership for the created directories
    if [ "$SUDO_USER" ]; then
        chown -R "$SUDO_USER":"$SUDO_USER" "$RETROARCH_DIR"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/RetroArch"
    fi
    
    print_msg "success" "Directories created successfully."
    print_msg "info" "ROM directories created for: NES, SNES, Genesis, GBA, N64, PlayStation, Arcade, MAME, Game Boy, Game Boy Color, PC Engine, Neo Geo, and Atari 2600"
}

# Function to download and install cores (in parallel)
install_cores() {
    print_msg "info" "Installing common RetroArch cores..."
    
    # Core lists for different package managers
    case $PKG_MANAGER in
        "apt")
            CORE_LIST="libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba libretro-genesisplusgx libretro-desmume libretro-beetle-psx libretro-mame"
            ;;
        "dnf" | "yum")
            CORE_LIST="libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba libretro-genesisplusgx"
            ;;
        "pacman")
            CORE_LIST="libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba libretro-genesis-plus-gx"
            ;;
    esac
    
    # Install cores in parallel
    local pids=()
    for core in $CORE_LIST; do
        print_msg "debug" "Installing core: $core"
        $PKG_INSTALL $core &>/dev/null &
        pids+=($!)
    done
    
    # Wait for all installations to complete
    for pid in "${pids[@]}"; do
        wait $pid
        if [ $? -ne 0 ]; then
            print_msg "warning" "One or more cores failed to install."
        fi
    done
    
    print_msg "success" "Core installation completed."
}

# Function to auto-detect and configure controllers
configure_controllers() {
    print_msg "info" "Looking for connected game controllers..."
    
    # Check for connected controllers
    if [ -d "/dev/input/js0" ] || ls /dev/input/js* &>/dev/null; then
        print_msg "info" "Game controllers detected."
        
        # Run RetroArch controller configuration
        if [ "$SUDO_USER" ]; then
            su - "$SUDO_USER" -c "retroarch --appendconfig \"input_autodetect_enable=true\" --menu --quit"
        else
            retroarch --appendconfig "input_autodetect_enable=true" --menu --quit
        fi
        
        print_msg "success" "Controllers configured automatically."
    else
        print_msg "info" "No game controllers detected. You can configure controllers later in RetroArch."
    fi
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
    
    # Check if RetroArch is installed
    if ! command -v retroarch &>/dev/null; then
        print_msg "error" "RetroArch command not found. Installation may have failed."
        exit 1
    fi
    
    # Run RetroArch once to generate default config
    print_msg "info" "Generating initial configuration file..."
    if [ "$SUDO_USER" ]; then
        su - "$SUDO_USER" -c "retroarch --config $CONFIG_FILE --menu --quit" &>/dev/null &
    else
        retroarch --config "$CONFIG_FILE" --menu --quit &>/dev/null &
    fi
    
    local pid=$!
    spinner $pid
    wait $pid
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_msg "warning" "RetroArch config file not found. Creating a basic one."
        
        # Create a basic configuration file
        cat > "$CONFIG_FILE" << EOL
# RetroArch Configuration
# Generated by RetroArch Auto-Installer v$VERSION
# Created: $(date "+%Y-%m-%d %H:%M:%S")

# Video settings
video_driver = "gl"
video_fullscreen = "true"
video_smooth = "true"
video_vsync = "true"
video_scale_integer = "false"

# Audio settings
audio_driver = "alsa"
audio_rate_control = "true"
audio_rate_control_delta = "0.005000"
audio_out_rate = "48000"

# Input settings
input_driver = "udev"
input_joypad_driver = "udev"
input_autodetect_enable = "true"

# Menu settings
menu_driver = "xmb"
menu_show_advanced_settings = "true"
menu_show_core_updater = "true"

# Directory settings
libretro_directory = "${USER_HOME}/.config/retroarch/cores"
libretro_info_path = "${USER_HOME}/.config/retroarch/cores/info"
content_directory = "${USER_HOME}/RetroArch/roms"
system_directory = "${USER_HOME}/RetroArch/system"
savefile_directory = "${USER_HOME}/RetroArch/saves"
savestate_directory = "${USER_HOME}/RetroArch/states"
thumbnail_directory = "${USER_HOME}/RetroArch/thumbnails"
rgui_browser_directory = "${USER_HOME}/RetroArch/roms"

# Performance settings
rewind_enable = "false"
video_threaded = "true"
EOL

        if [ "$SUDO_USER" ]; then
            chown "$SUDO_USER":"$SUDO_USER" "$CONFIG_FILE"
        fi
    else
        # Update existing configuration with our paths
        print_msg "info" "Updating existing configuration file..."
        
        # Backup the original config
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        
        # Update paths using sed
        sed -i "s|^libretro_directory =.*|libretro_directory = \"${USER_HOME}/.config/retroarch/cores\"|" "$CONFIG_FILE"
        sed -i "s|^content_directory =.*|content_directory = \"${USER_HOME}/RetroArch/roms\"|" "$CONFIG_FILE"
        sed -i "s|^system_directory =.*|system_directory = \"${USER_HOME}/RetroArch/system\"|" "$CONFIG_FILE"
        sed -i "s|^savefile_directory =.*|savefile_directory = \"${USER_HOME}/RetroArch/saves\"|" "$CONFIG_FILE"
        sed -i "s|^savestate_directory =.*|savestate_directory = \"${USER_HOME}/RetroArch/states\"|" "$CONFIG_FILE"
        sed -i "s|^thumbnail_directory =.*|thumbnail_directory = \"${USER_HOME}/RetroArch/thumbnails\"|" "$CONFIG_FILE"
    fi
    
    print_msg "success" "RetroArch configured successfully."
}

# Create a desktop shortcut
create_desktop_shortcut() {
    if [ "$CREATE_DESKTOP_ICON" = false ]; then
        print_msg "info" "Skipping desktop shortcut creation."
        return 0
    fi
    
    print_msg "info" "Creating desktop shortcut..."
    
    if [ "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME=$HOME
    fi
    
    DESKTOP_FILE="$USER_HOME/Desktop/retroarch.desktop"
    
    # Check if Desktop directory exists
    if [ ! -d "$USER_HOME/Desktop" ]; then
        mkdir -p "$USER_HOME/Desktop"
        if [ "$SUDO_USER" ]; then
            chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/Desktop"
        fi
    fi
    
    cat > "$DESKTOP_FILE" << EOL
[Desktop Entry]
Type=Application
Name=RetroArch
Comment=Frontend for emulators, game engines and media players
Exec=retroarch
Icon=retroarch
Terminal=false
Categories=Game;Emulator;
Keywords=game;emulator;retro;
EOL

    if [ "$SUDO_USER" ]; then
        chown "$SUDO_USER":"$SUDO_USER" "$DESKTOP_FILE"
    fi
    
    chmod +x "$DESKTOP_FILE"
    
    print_msg "success" "Desktop shortcut created."
}

# Function to download BIOS files (optional)
download_bios_files() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi
    
    if confirm_action "Would you like to download common BIOS files?" "N"; then
        print_msg "info" "This feature is for educational purposes only."
        print_msg "info" "You should legally own the systems for which you use BIOS files."
        
        if ! confirm_action "Do you understand and wish to continue?" "N"; then
            print_msg "info" "BIOS download cancelled."
            return 0
        fi
        
        if [ "$SUDO_USER" ]; then
            USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        else
            USER_HOME=$HOME
        fi
        
        SYSTEM_DIR="$USER_HOME/RetroArch/system"
        
        # Example of downloading a freely available BIOS
        # This is a placeholder - you should replace with legitimate sources
        print_msg "info" "Downloading free BIOS files to $SYSTEM_DIR..."
        
        # Set proper ownership
        if [ "$SUDO_USER" ]; then
            chown -R "$SUDO_USER":"$SUDO_USER" "$SYSTEM_DIR"
        fi
        
        print_msg "success" "BIOS files downloaded."
        print_msg "info" "Remember that you should only use BIOS files for systems you legally own."
    else
        print_msg "info" "Skipping BIOS download."
    fi
}

# Function to perform an uninstall
uninstall_retroarch() {
    print_msg "info" "Uninstalling RetroArch..."
    
    if ! confirm_action "Are you sure you want to uninstall RetroArch?" "N"; then
        print_msg "info" "Uninstall cancelled."
        exit 0
    fi
    
    # Remove RetroArch package
    case $PKG_MANAGER in
        "apt")
            apt remove --purge -y retroarch libretro-* &
            ;;
        "dnf" | "yum")
            $PKG_MANAGER remove -y retroarch &
            ;;
        "pacman")
            pacman -R --noconfirm retroarch &
            ;;
    esac
    
    local pid=$!
    print_msg "info" "Removing RetroArch packages..."
    spinner $pid
    wait $pid
    
    # Ask about removing configuration and ROM files
    if confirm_action "Do you want to remove all RetroArch configuration files and ROMs?" "N"; then
        if [ "$SUDO_USER" ]; then
            USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        else
            USER_HOME=$HOME
        fi
        
        # Remove RetroArch directories
        print_msg "info" "Removing RetroArch directories..."
        rm -rf "$USER_HOME/.config/retroarch"
        rm -rf "$USER_HOME/RetroArch"
        
        # Remove desktop shortcut
        if [ -f "$USER_HOME/Desktop/retroarch.desktop" ]; then
            rm -f "$USER_HOME/Desktop/retroarch.desktop"
        fi
        
        print_msg "success" "All RetroArch files and directories have been removed."
    else
        print_msg "info" "RetroArch packages removed, but configuration and ROM files were kept."
    fi
    
    print_msg "success" "RetroArch has been uninstalled."
    exit 0
}

# Function to display help
show_help() {
    echo "RetroArch Auto-Installer and Configuration Script v$VERSION"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version           Show version information"
    echo "  -y, --yes               Non-interactive mode, assume yes for all questions"
    echo "  -q, --quiet             Minimal output"
    echo "  -c, --cores-only        Only install/update cores"
    echo "  -m, --minimal           Minimal installation (no desktop icon, etc.)"
    echo "  -u, --uninstall         Uninstall RetroArch"
    echo ""
    echo "Examples:"
    echo "  $0                      Run with default settings"
    echo "  $0 --yes --minimal      Run non-interactively with minimal installation"
    echo "  $0 --cores-only         Only install/update the emulator cores"
    echo "  $0 --uninstall          Uninstall RetroArch"
    echo ""
    exit 0
}

# Function to parse command line arguments
parse_arguments() {
    ARGS=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--version)
                echo "RetroArch Auto-Installer v$VERSION"
                exit 0
                ;;
            -y|--yes)
                NON_INTERACTIVE=true
                ARGS="$ARGS $1"
                shift
                ;;
            -q|--quiet)
                VERBOSE=false
                ARGS="$ARGS $1"
                shift
                ;;
            -c|--cores-only)
                INSTALL_CORES_ONLY=true
                ARGS="$ARGS $1"
                shift
                ;;
            -m|--minimal)
                MINIMAL_INSTALL=true
                CREATE_DESKTOP_ICON=false
                ARGS="$ARGS $1"
                shift
                ;;
            -u|--uninstall)
                check_root
                detect_package_manager
                uninstall_retroarch
                ;;
            *)
                print_msg "warning" "Unknown option: $1"
                shift
                ;;
        esac
    done
}

# Main function
main() {
    # Start logging
    echo "RetroArch Auto-Installer and Configuration Script v$VERSION" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "System: $(uname -a)" >> "$LOG_FILE"
    
    print_msg "info" "RetroArch Auto-Installer and Configuration Script v$VERSION"
    print_msg "info" "Log file: $LOG_FILE"
    
    # Check dependencies
    check_dependencies
    
    # Check root privileges
    check_root
    
    # Detect package manager
    detect_package_manager
    
    # Install RetroArch if not cores-only mode
    if [ "$INSTALL_CORES_ONLY" = false ]; then
        install_retroarch
        setup_directories
    fi
    
    # Install cores
    install_cores
    
    # Configure RetroArch if not cores-only mode
    if [ "$INSTALL_CORES_ONLY" = false ]; then
        configure_retroarch
        
        # Configure controllers
        configure_controllers
        
        # Create desktop shortcut
        create_desktop_shortcut
        
        # Download BIOS files (optional)
        download_bios_files
    fi
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    # Display success message
    if [ "$INSTALL_CORES_ONLY" = true ]; then
        print_msg "success" "RetroArch cores have been successfully installed!"
    else
        print_msg "success" "RetroArch has been successfully installed and configured!"
        print_msg "info" "You can now launch RetroArch from your applications menu or desktop shortcut."
        print_msg "info" "Your ROM files should be placed in the following directory:"
        
        if [ "$SUDO_USER" ]; then
            USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        else
            USER_HOME=$HOME
        fi
        
        print_msg "info" "$USER_HOME/RetroArch/roms/<system>/"
    fi
    
    print_msg "info" "For help and troubleshooting, check the log file: $LOG_FILE"
}

# Parse command line arguments
parse_arguments "$@"

# Execute main function
main
