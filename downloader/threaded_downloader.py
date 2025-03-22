#!/usr/bin/env python3

import os
import requests
import zipfile
import threading
from queue import Queue
from pathlib import Path

# Define the base directory for ROMs and BIOS
roms_base_dir = Path.home() / "roms"

# Dictionary mapping system names to their archive.org URLs and target directories
systems = {
    1: {"name": "Nintendo NES", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20NES.zip", "dir": "nes"},
    2: {"name": "Nintendo SNES", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20SNES.zip", "dir": "snes"},
    3: {"name": "Nintendo Game Boy", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20Game%20Boy.zip", "dir": "gb"},
    4: {"name": "Nintendo Game Boy Color", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20Game%20Boy%20Color.zip", "dir": "gbc"},
    5: {"name": "Nintendo Game Boy Advance", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20Game%20Boy%20Advance.zip", "dir": "gba"},
    6: {"name": "Nintendo N64", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20N64.zip", "dir": "n64"},
    7: {"name": "Nintendo DS", "url": "https://archive.org/download/retro-roms-best-set/Nintendo%20-%20DS.zip", "dir": "nds"},
    8: {"name": "Sega Genesis", "url": "https://archive.org/download/retro-roms-best-set/Sega%20-%20Genesis.zip", "dir": "genesis"},
    9: {"name": "Sega Master System", "url": "https://archive.org/download/retro-roms-best-set/Sega%20-%20Master%20System.zip", "dir": "sms"},
    10: {"name": "Sega Game Gear", "url": "https://archive.org/download/retro-roms-best-set/Sega%20-%20Game%20Gear.zip", "dir": "gg"},
    11: {"name": "Sony PlayStation 1 (A-L)", "url": "https://archive.org/download/retro-roms-best-set/Sony%20-%20PS1%20%28A-L%29.zip", "dir": "psx"},
    12: {"name": "Sony PlayStation 1 (L-Z)", "url": "https://archive.org/download/retro-roms-best-set/Sony%20-%20PS1%20%28L-Z%29.zip", "dir": "psx"},
    13: {"name": "Arcade (MAME 2003 Plus)", "url": "https://archive.org/download/retro-roms-best-set/Arcade%20-%20Mame%202003%20Plus.zip", "dir": "mame"},
    14: {"name": "Download All BIOS", "url": "https://archive.org/download/retroarch-bios-pack/Retroarch%20Bios%20Pack.zip", "dir": "bios"},
    15: {"name": "Exit", "url": None, "dir": None}
}

def display_menu():
    print("\n=== RetroArch ROM and BIOS Downloader (Multi-Threaded) ===")
    for key, value in systems.items():
        print(f"{key}. {value['name']}")
    print("Select systems to download ROMs/BIOS for (or '15' to exit). Enter multiple numbers separated by spaces:")

def download_file(url, target_path, filename):
    """Download a file from a URL to the target path."""
    zip_file = target_path / filename
    print(f"Starting download: {filename} from {url}")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(zip_file, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"Download completed: {filename}")
        return zip_file
    except requests.RequestException as e:
        print(f"Error downloading {filename}: {e}")
        return None

def extract_file(zip_file, target_path):
    """Extract a downloaded zip file to the target path."""
    print(f"Extracting: {zip_file.name} to {target_path}")
    try:
        with zipfile.ZipFile(zip_file, "r") as zip_ref:
            zip_ref.extractall(target_path)
        os.remove(zip_file)
        print(f"Extraction completed: {zip_file.name}")
    except zipfile.BadZipFile as e:
        print(f"Error extracting {zip_file.name}: {e}")

def process_download(url, target_dir, filename):
    """Handle the download and extraction process for a single file."""
    target_path = roms_base_dir / target_dir
    target_path.mkdir(parents=True, exist_ok=True)

    # Download the file
    zip_file = download_file(url, target_path, filename)
    if zip_file:
        # Extract in a separate thread
        extract_thread = threading.Thread(target=extract_file, args=(zip_file, target_path))
        extract_thread.start()
        extract_thread.join()  # Wait for extraction to complete before proceeding

def download_multiple(choices):
    """Manage multi-threaded downloads for multiple selections."""
    threads = []
    for choice in choices:
        system = systems[choice]
        filename = f"{system['name'].replace(' ', '_')}.zip"
        thread = threading.Thread(target=process_download, args=(system["url"], system["dir"], filename))
        threads.append(thread)
        thread.start()

    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    print("All selected downloads and extractions completed!")

def main():
    while True:
        display_menu()
        try:
            user_input = input("Enter your choices (1-15, multiple allowed, e.g., '1 2 14'): ")
            choices = [int(x) for x in user_input.split() if x.isdigit()]
            
            if not choices or any(c not in systems for c in choices):
                print("Invalid choice(s). Please select numbers between 1 and 15.")
                continue
            
            if 15 in choices:  # Exit option
                print("Exiting the downloader. Enjoy your games!")
                break
            
            print(f"Selected systems: {[systems[c]['name'] for c in choices]}")
            confirm = input("Would you like to proceed with the downloads? (yes/no): ").lower()
            if confirm == "yes":
                download_multiple(choices)
            else:
                print("Downloads cancelled.")
        
        except ValueError:
            print("Please enter valid numbers separated by spaces.")

if __name__ == "__main__":
    main()
