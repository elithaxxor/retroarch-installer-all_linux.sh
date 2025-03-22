#!/bin/bash

# Check if Flatpak is installed; if not, install it (assumes Debian-based system like Ubuntu)
if ! command -v flatpak &> /dev/null; then
    echo "Flatpak not found. Installing Flatpak..."
    sudo apt update
    sudo apt install -y flatpak
fi

# Add the Flathub repository if not already added
echo "Ensuring Flathub repository is added..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install RetroArch from Flathub
echo "Installing RetroArch..."
flatpak install -y flathub org.libretro.RetroArch

# Install Pegasus from Flathub
echo "Installing Pegasus..."
flatpak install -y flathub org.pegasusfrontend.Pegasus

# Create ROM directories for common systems
echo "Creating ROM directories..."
mkdir -p ~/roms/nes ~/roms/snes ~/roms/genesis

# Create Pegasus configuration directory and files
echo "Configuring Pegasus..."
mkdir -p ~/.config/pegasus-frontend

# Specify the ROM directory in game_dirs.txt
echo "~/roms" > ~/.config/pegasus-frontend/game_dirs.txt

# Create metadata.pegasus.txt with basic configuration for NES, SNES, and Genesis
cat > ~/.config/pegasus-frontend/metadata.pegasus.txt << EOL
collection: NES
extension: nes
launch: flatpak run org.libretro.RetroArch -L /app/lib/libretro/nestopia_libretro.so {file.path}

collection: SNES
extension: sfc smc
launch: flatpak run org.libretro.RetroArch -L /app/lib/libretro/snes9x_libretro.so {file.path}

collection: Genesis
extension: md bin
launch: flatpak run org.libretro.RetroArch -L /app/lib/libretro/genesis_plus_gx_libretro.so {file.path}
EOL

# Inform the user that the setup is complete
echo "Setup complete! Place your ROMs in the respective directories under ~/roms (e.g., ~/roms/nes for NES games)."
echo "To start playing, launch Pegasus using: flatpak run org.pegasusfrontend.Pegasus"
