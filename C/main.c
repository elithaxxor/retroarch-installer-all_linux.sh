Here is the complete script for the `main.c` file that integrates the `bios_downloader.sh` functionality:

```c
/**************************************************************
 * RetroArch Auto-Installer and Configuration Script in C
 * 
 * Compilation:
 *    gcc -o retroarch_setup retroarch_setup.c
 *
 * Usage:
 *    sudo ./retroarch_setup
 **************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

/* 
 * Steps:
 * 1) check_root
 * 2) detect_package_manager
 * 3) install_retroarch
 * 4) setup_directories
 * 5) install_cores
 * 6) configure_retroarch
 * --- Interactive Menu for Optional Steps ---
 * 7) download_bios (placeholder)
 * 8) enable_autostart
 * 9) create_desktop_shortcut
 */

/* Color Codes */
#define RED     "\033[0;31m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[0;33m"
#define BLUE    "\033[0;34m"
#define NC      "\033[0m"  /* No Color */

/* Global variables for package manager commands */
static char PKG_MANAGER[32]   = {0};
static char PKG_UPDATE[128]   = {0};
static char PKG_INSTALL[128]  = {0};

/* Global for user info (home dir, etc.) */
static char  g_userName[128] = {0};
static char  g_homeDir[512]  = {0};
static uid_t g_uid           = 0;
static gid_t g_gid           = 0;

/*======================================================================
 * Helper Functions
 *======================================================================*/

/* Print colored messages */
void print_msg(const char *type, const char *message) {
    if (strcmp(type, "info") == 0) {
        fprintf(stdout, BLUE "[INFO]" NC " %s\n", message);
    } else if (strcmp(type, "success") == 0) {
        fprintf(stdout, GREEN "[SUCCESS]" NC " %s\n", message);
    } else if (strcmp(type, "warning") == 0) {
        fprintf(stdout, YELLOW "[WARNING]" NC " %s\n", message);
    } else if (strcmp(type, "error") == 0) {
        fprintf(stderr, RED "[ERROR]" NC " %s\n", message);
    } else {
        fprintf(stdout, "%s\n", message);
    }
}

/* Ensure script is run as root */
void check_root() {
    if (geteuid() != 0) {
        print_msg("error", "This script requires root privileges. Please run with sudo.");
        exit(EXIT_FAILURE);
    }
}

/*
   Utility to detect if a command exists:
   Returns 0 if found, non-zero otherwise.
*/
int command_exists(const char* cmd) {
    char buf[256];
    snprintf(buf, sizeof(buf), "command -v %s > /dev/null 2>&1", cmd);
    return system(buf);
}

/*
   Identify the user who invoked sudo (or fallback to current),
   store details in global variables for consistent usage.
*/
void identify_user() {
    char *sudo_user = getenv("SUDO_USER");
    struct passwd *pw = NULL;

    if (sudo_user && strlen(sudo_user) > 0) {
        pw = getpwnam(sudo_user);
    }
    else {
        /* Fall back to current user if SUDO_USER not set */
        uid_t uid = getuid();
        pw = getpwuid(uid);
    }
    if (!pw) {
        print_msg("error", "Could not determine user home directory.");
        exit(EXIT_FAILURE);
    }
    snprintf(g_userName, sizeof(g_userName), "%s", pw->pw_name);
    snprintf(g_homeDir, sizeof(g_homeDir), "%s", pw->pw_dir);
    g_uid = pw->pw_uid;
    g_gid = pw->pw_gid;
}

/* Determine the package manager and set global strings */
void detect_package_manager() {
    print_msg("info", "Detecting package manager...");

    if (command_exists("apt") == 0) {
        strcpy(PKG_MANAGER, "apt");
        strcpy(PKG_UPDATE,  "apt update -y");
        strcpy(PKG_INSTALL, "apt install -y");
    } else if (command_exists("dnf") == 0) {
        strcpy(PKG_MANAGER, "dnf");
        strcpy(PKG_UPDATE,  "dnf check-update -y");
        strcpy(PKG_INSTALL, "dnf install -y");
    } else if (command_exists("yum") == 0) {
        strcpy(PKG_MANAGER, "yum");
        strcpy(PKG_UPDATE,  "yum check-update -y");
        strcpy(PKG_INSTALL, "yum install -y");
    } else if (command_exists("pacman") == 0) {
        strcpy(PKG_MANAGER, "pacman");
        strcpy(PKG_UPDATE,  "pacman -Sy");
        strcpy(PKG_INSTALL, "pacman -S --noconfirm");
    } else if (command_exists("zypper") == 0) {
        strcpy(PKG_MANAGER, "zypper");
        strcpy(PKG_UPDATE,  "zypper refresh");
        strcpy(PKG_INSTALL, "zypper install -y");
    } else if (command_exists("xbps-install") == 0) {
        strcpy(PKG_MANAGER, "xbps");
        strcpy(PKG_UPDATE,  "xbps-install -Su");
        strcpy(PKG_INSTALL, "xbps-install -y");
    } else {
        print_msg("error", "No supported package manager found (apt, dnf, yum, pacman, zypper, xbps).");
        exit(EXIT_FAILURE);
    }

    char msg[128];
    snprintf(msg, sizeof(msg), "Detected package manager: %s", PKG_MANAGER);
    print_msg("info", msg);
}

/*======================================================================
 * Steps 1–6 (Essential)
 *======================================================================*/

void install_retroarch() {
    print_msg("info", "Updating package lists...");
    if (system(PKG_UPDATE) != 0) {
        print_msg("warning", "Update command failed, continuing...");
    }

    print_msg("info", "Installing RetroArch and dependencies...");

    /* Build the install command based on package manager */
    char cmd[512];
    if (strcmp(PKG_MANAGER, "apt") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "%s retroarch libretro-* mesa-utils", 
                 PKG_INSTALL);
    } else if ((strcmp(PKG_MANAGER, "dnf") == 0) 
            || (strcmp(PKG_MANAGER, "yum") == 0)) {
        snprintf(cmd, sizeof(cmd),
                 "%s retroarch mesa-libGL mesa-dri-drivers", 
                 PKG_INSTALL);
    } else if (strcmp(PKG_MANAGER, "pacman") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "%s retroarch libretro mesa", 
                 PKG_INSTALL);
    } else if (strcmp(PKG_MANAGER, "zypper") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "%s retroarch libretro-core", 
                 PKG_INSTALL);
    } else if (strcmp(PKG_MANAGER, "xbps") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "%s retroarch libretro-core", 
                 PKG_INSTALL);
    } else {
        print_msg("error", "Unsupported package manager for RetroArch installation.");
        exit(EXIT_FAILURE);
    }

    if (system(cmd) != 0) {
        print_msg("error", "RetroArch installation failed.");
        exit(EXIT_FAILURE);
    }

    print_msg("success", "RetroArch installation completed!");
}

void create_directory(const char *path) {
    /* Create if missing, set permission to 0755 */
    struct stat st;
    if (stat(path, &st) == -1) {
        if (mkdir(path, 0755) != 0) {
            char err_buf[256];
            snprintf(err_buf, sizeof(err_buf), "Failed to create directory: %s", path);
            print_msg("error", err_buf);
            exit(EXIT_FAILURE);
        }
    }
    /* chown the directory to the user */
    if (chown(path, g_uid, g_gid) != 0) {
        char warn_buf[256];
        snprintf(warn_buf, sizeof(warn_buf), "Warning: Failed to chown directory: %s", path);
        print_msg("warning", warn_buf);
    }
}

/* Set up RetroArch directories */
void setup_directories() {
    print_msg("info", "Setting up RetroArch directories...");

    /* Base RetroArch folder */
    char base_dir[512];
    snprintf(base_dir, sizeof(base_dir), "%s/RetroArch", g_homeDir);

    /* Create subdirectories */
    /* e.g.: /roms/nes, /roms/snes, /system, /saves, /states, etc. */
    char path[1024];

    /* Main RetroArch folder */
    create_directory(base_dir);

    /* List of subdirectories: */
    const char *folders[] = {
        "/roms/nes",
        "/roms/snes",
        "/roms/genesis",
        "/roms/gba",
        "/roms/n64",
        "/roms/psx",
        "/roms/arcade",
        "/roms/mame",
        "/roms/gb",
        "/roms/gbc",
        "/system",
        "/saves",
        "/states",
        NULL
    };

    for (int i = 0; folders[i] != NULL; i++) {
        snprintf(path, sizeof(path), "%s%s", base_dir, folders[i]);
        create_directory(path);
    }

    print_msg("success", "Directories created successfully.");
}

void install_cores() {
    print_msg("info", "Installing common RetroArch cores...");

    char cmd[512];
    if (strcmp(PKG_MANAGER, "apt") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "%s libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba",
                 PKG_INSTALL);
    } else if ((strcmp(PKG_MANAGER, "dnf") == 0) 
            || (strcmp(PKG_MANAGER, "yum") == 0)) {
        snprintf(cmd, sizeof(cmd),
                 "%s libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba",
                 PKG_INSTALL);
    } else if (strcmp(PKG_MANAGER, "pacman") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "%s libretro-snes9x libretro-nestopia libretro-mupen64plus libretro-mgba",
                 PKG_INSTALL);
    } else if (strcmp(PKG_MANAGER, "zypper") == 0) {
        /* Adjust if needed for openSUSE naming. Using placeholder. */
        snprintf(cmd, sizeof(cmd),
                 "%s libretro-core-snes9x libretro-core-nestopia",
                 PKG_INSTALL);
    } else if (strcmp(PKG_MANAGER, "xbps") == 0) {
        /* Adjust if needed for Void naming. Using placeholder. */
        snprintf(cmd, sizeof(cmd),
                 "%s libretro-core-snes9x libretro-core-nestopia",
                 PKG_INSTALL);
    } else {
        print_msg("warning", "No known RetroArch core packages for this manager. Skipping...");
        return;
    }

    if (system(cmd) != 0) {
        print_msg("warning", "Core installation encountered errors. Check logs.");
    } else {
        print_msg("success", "Core installation completed.");
    }
}

/* 
   Configure RetroArch:
   - Generate default config if missing
   - Update key directories 
*/
void configure_retroarch() {
    print_msg("info", "Configuring RetroArch...");

    /* Ensure config path exists */
    char config_path[512];
    snprintf(config_path, sizeof(config_path), "%s/.config/retroarch", g_homeDir);

    char mkdir_cmd[512];
    snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p '%s'", config_path);
    system(mkdir_cmd);

    /* Build absolute path to retroarch.cfg */
    char config_file[512];
    snprintf(config_file, sizeof(config_file), "%s/retroarch.cfg", config_path);

    /*
      Launch RetroArch once to generate config if it doesn’t exist.
      We wrap with `|| true` (or `; exit 0`) so we don't bail on error.
    */
    char ra_cmd[512];
    snprintf(ra_cmd, sizeof(ra_cmd),
             "sudo -u %s retroarch --config '%s' --menu --quit || true", 
             g_userName, config_file);
    system(ra_cmd);

    /* If config file still does not exist, create a minimal one. */
    FILE *fp = fopen(config_file, "r");
    if (!fp) {
        print_msg("warning", "RetroArch config file not found. Creating a basic one.");

        fp = fopen(config_file, "w");
        if (!fp) {
            print_msg("error", "Failed to create retroarch.cfg");
            return;
        }
        fprintf(fp,
            "video_driver = \"gl\"\n"
            "audio_driver = \"alsa\"\n"
            "menu_driver = \"xmb\"\n"
            "content_directory = \"%s/RetroArch/roms\"\n"
            "system_directory = \"%s/RetroArch/system\"\n"
            "savefile_directory = \"%s/RetroArch/saves\"\n"
            "savestate_directory = \"%s/RetroArch/states\"\n",
            g_homeDir, g_homeDir, g_homeDir, g_homeDir
        );
        fclose(fp);
    } else {
        fclose(fp);
        /* 
         * If you want to forcibly overwrite existing lines, do so with sed:
         * We update content/system/savefile/savestate directories 
         */
        char sed_cmd[512];
        snprintf(sed_cmd, sizeof(sed_cmd),
                 "sed -i 's|^content_directory =.*|content_directory = \"%s/RetroArch/roms\"|' '%s'",
                 g_homeDir, config_file);
        system(sed_cmd);

        snprintf(sed_cmd, sizeof(sed_cmd),
                 "sed -i 's|^system_directory =.*|system_directory = \"%s/RetroArch/system\"|' '%s'",
                 g_homeDir, config_file);
        system(sed_cmd);

        snprintf(sed_cmd, sizeof(sed_cmd),
                 "sed -i 's|^savefile_directory =.*|savefile_directory = \"%s/RetroArch/saves\"|' '%s'",
                 g_homeDir, config_file);
        system(sed_cmd);

        snprintf(sed_cmd, sizeof(sed_cmd),
                 "sed -i 's|^savestate_directory =.*|savestate_directory = \"%s/RetroArch/states\"|' '%s'",
                 g_homeDir, config_file);
        system(sed_cmd);
    }

    /* Fix ownership of config dir */
    chown(config_path, g_uid, g_gid);
    chown(config_file, g_uid, g_gid);

    print_msg("success", "RetroArch configured successfully.");
}

/*======================================================================
 * Steps 7–9 (Optional, via Interactive Menu)
 *======================================================================*/

/* Function to execute shell script */
void execute_shell_script() {
    print_msg("info", "Executing BIOS downloader shell script...");

    /* Command to execute the shell script */
    const char *script_path = "./C/bios_downloader.sh";
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "bash %s", script_path);

    if (system(cmd) != 0) {
        print_msg("error", "Failed to execute BIOS downloader shell script.");
    } else {
        print_msg("success", "BIOS downloader shell script executed successfully.");
    }
}

/* Placeholder for BIOS download/placement */
void download_bios() {
    execute_shell_script();
}

void enable_autostart() {
    print_msg("info", "Setting RetroArch to launch at startup...");

    /* 
       Create /etc/xdg/autostart/retroarch.desktop 
       for XDG-based environments.
    */
    const char *autostart_file = "/etc/xdg/autostart/retroarch.desktop";
    FILE *fp = fopen(autostart_file, "w");
    if (!fp) {
        print_msg("error", "Failed to create autostart file. Check permissions.");
        return;
    }
    fprintf(fp,
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Exec=retroarch\n"
        "Hidden=false\n"
        "NoDisplay=false\n"
        "X-GNOME-Autostart-enabled=true\n"
        "Name=RetroArch\n"
    );
    fclose(fp);

    print_msg("success", "RetroArch will now start automatically on login.");
}

/* Create a desktop shortcut (on the user’s Desktop) */
void create_desktop_shortcut() {
    print_msg("info", "Creating desktop shortcut...");

    char desktop_file[512];
    snprintf(desktop_file, sizeof(desktop_file),
             "%s/Desktop/retroarch.desktop", g_homeDir);

    /* Ensure the Desktop folder exists (in case it doesn't) */
    char desktop_dir[512];
    snprintf(desktop_dir, sizeof(desktop_dir), "%s/Desktop", g_homeDir);
    create_directory(desktop_dir);

    FILE *fp = fopen(desktop_file, "w");
    if (!fp) {
        print_msg("error", "Failed to create desktop shortcut. Check permissions or directory existence.");
        return;
    }
    fprintf(fp,
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Name=RetroArch\n"
        "Exec=retroarch\n"
        "Icon=retroarch\n"
        "Terminal=false\n"
        "Categories=Game;Emulator;\n"
    );
    fclose(fp);

    /* Make it executable */
    chmod(desktop_file, 0755);

    /* Adjust owner to the user */
    chown(desktop_file, g_uid, g_gid);

    print_msg("success", "Desktop shortcut created on your Desktop.");
}

/*======================================================================
 * Interactive Menu (for steps 7–9)
 *======================================================================*/
void interactive_menu() {
    int choice = 0;
    do {
        printf("\n=============================================\n");
        printf("  RetroArch - Optional Features Menu (7–9)\n");
        printf("=============================================\n");
        printf("  1) Download/Place BIOS Files (Step 7)\n");
        printf("  2) Enable Auto-Start  (Step 8)\n");
        printf("  3) Create Desktop Shortcut (Step 9)\n");
        printf("  0) Exit Menu\n");
        printf("---------------------------------------------\n");
        printf("Enter your choice: ");

        /* Read user input. If not numeric, it defaults to 
