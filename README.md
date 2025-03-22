# RetroArch Auto-Installer

![image](https://github.com/user-attachments/assets/f39aebe9-8002-4117-9faa-467c9bcbc0d9)

A robust, automated installer and configuration script for RetroArch emulation software on Linux systems.

![RetroArch Logo](https://www.retroarch.com/images/logo.png)

## Overview

This script automates the installation and configuration of RetroArch on Linux. It detects your system's package manager, installs RetroArch along with common emulator cores, sets up proper directories, and configures RetroArch for immediate use.

## Features

- **Cross-Distribution Support**: Works with apt (Debian/Ubuntu), dnf (Fedora), yum (CentOS/RHEL), and pacman (Arch Linux)
- **Parallel Installation**: Faster installation with parallel package download and installation
- **Smart Configuration**: Creates optimal configurations for RetroArch
- **Structured Directory Setup**: Creates organized directories for ROMs, saves, states, and more
- **Desktop Integration**: Creates a desktop shortcut for easy access
- **Automatic Controller Detection**: Identifies and configures attached game controllers
- **Backup & Recovery**: Automatically backs up existing configurations
- **Detailed Logging**: Comprehensive logging for troubleshooting
- **Interactive & Non-Interactive Modes**: Full customization or automated deployment options
- **Uninstall Capability**: Clean removal option included

## System Requirements

- Linux distribution using apt, dnf, yum, or pacman package managers
- Root/sudo privileges
- Basic dependencies: wget, curl, sed, grep

## Installation

### Quick Install (Default Options)

```bash
sudo bash install_retroarch.sh
```

### Non-Interactive Installation

```bash
sudo bash install_retroarch.sh --yes
```

### Minimal Installation (No Desktop Icon)

```bash
sudo bash install_retroarch.sh --minimal
```

### Install or Update Cores Only

```bash
sudo bash install_retroarch.sh --cores-only
```

### Uninstall RetroArch

```bash
sudo bash install_retroarch.sh --uninstall
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --version` | Show version information |
| `-y, --yes` | Non-interactive mode, assume yes for all questions |
| `-q, --quiet` | Minimal output |
| `-c, --cores-only` | Only install/update cores |
| `-m, --minimal` | Minimal installation (no desktop icon, etc.) |
| `-u, --uninstall` | Uninstall RetroArch |

## Directory Structure

After installation, the following directory structure will be created:

```
~/RetroArch/
├── roms/
│   ├── nes/
│   ├── snes/
│   ├── genesis/
│   ├── gba/
│   ├── n64/
│   ├── psx/
│   ├── arcade/
│   ├── mame/
│   └── ...
├── saves/
├── states/
├── system/
└── thumbnails/

~/.config/retroarch/
├── retroarch.cfg
└── cores/
```

## Supported Emulator Cores

The script installs various libretro cores based on your system's package manager:

- SNES (snes9x)
- NES (nestopia)
- Nintendo 64 (mupen64plus)
- Game Boy Advance (mgba)
- Sega Genesis/Mega Drive (genesis-plus-gx)
- Nintendo DS (desmume) *where available*
- PlayStation (beetle-psx) *where available*
- Arcade/MAME *where available*

## Troubleshooting

### Common Issues

1. **Installation fails with package not found**
   - Some distributions may have different package names for RetroArch or cores
   - Try manually installing RetroArch first, then run with the `--cores-only` option

2. **RetroArch launches but shows a black screen**
   - This may be a graphics driver issue
   - Try running RetroArch with a different video driver: `retroarch --video_driver gl`

3. **Controllers not detected**
   - Run RetroArch and configure controllers manually through Settings → Input
   - Ensure your controller is compatible with your system

### Logs

The script creates detailed logs in the current directory with filename pattern `retroarch_install_[DATE]_[TIME].log`. Check these logs for troubleshooting information.

## Advanced Usage

### Installing Additional Cores

To install additional cores after initial setup:

```bash
sudo bash install_retroarch.sh --cores-only
```

### Customizing Configuration

The RetroArch configuration file is located at `~/.config/retroarch/retroarch.cfg`. You can edit this file directly or through RetroArch's interface.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This script is released under the MIT License. See the LICENSE file for details.

## Acknowledgments

- The RetroArch team for their amazing emulation frontend
- The libretro team for their extensive core library
- All contributors to this installer script

[NOTE: I built a version in C just incase your on some obscure iOT (C th C file]




