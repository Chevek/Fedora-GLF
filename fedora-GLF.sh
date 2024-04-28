#!/usr/bin/env bash
#===================================================================================
#
# FILE : fedora-GLF.sh
#
# USAGE : ./fedora-GLF.sh
#
# DESCRIPTION : Post installation script for Fedora Linux as a gaming/content creator station.
#
# BUGS: 
# GameMode Gnome Shell Extension is broken on Fedora 39 https://bugzilla.redhat.com/show_bug.cgi?id=2259979
# gamemode-1.8.1 is available https://bugzilla.redhat.com/show_bug.cgi?id=2253403
# NOTES: ---
# CONTRUBUTORS: Chevek, Cardiac
# CREATED: april 2024
# REVISION: april 13th 2024
#
# LICENCE:
# Copyright (C) 2024 Yannick Defais aka Chevek, Cardiac
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#===================================================================================

#===================================================================================
# TODO:
# - add LC_ALL=C to all commands as we need to understand the logs
# - split the script into installation logic and functions to handle those datas. 
# - Add secure boot support for NVIDIA ( https://rpmfusion.org/Howto/Secure%20Boot )
# - Add Xbox Gamepad support (xpadneo ?)
# - Add translation support (gettext)
# - Add options to the script (VERBOSE...)
# - add GUI
# - Add ZLUDA support ( https://github.com/vosen/ZLUDA ), if still relevant...

# Set shell options
#FIXME: remove this set -e and manage error for each cammand call
set -e

# Color and Formatting Definitions
color_text() {
    local color_code=$1
    local text=$2
    echo "$(tput setaf $color_code)$text$(tput sgr0)"
}

check_network_connection() {
#FIXME: nolog, and add log if success
    if ! ping -c 1 google.com &> /dev/null; then
        echo "No network connection. Please check your internet connection and try again."
        exit 1
    fi
}


#===================================================================================
# Log Setup and configuration
# Source : https://github.com/Gaming-Linux-FR/Architect/blob/main/src/cmd.sh
#===================================================================================

# Set default configuration
#use verbose=true as default as long as this script is not stabilised
VERBOSE=false
LOG_FILE="$(dirname "$(realpath "$0")")/logfile_Fedora_GLF_$(date "+%Y%m%d-%H%M%S").log"

# Function to log messages
log() {
    local level=$1
    local message=$2
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $level: $message" >> "$LOG_FILE"
}

# Function to display and log messages
log_msg() {
    local message=$1
    echo "$message"
    log INFO "$message"
}

# Function to execute and log commands
exec_command() {
    local command="$1"
    local log_command="Executing: $command"
    if [ "$VERBOSE" = true ]; then
        log_command+=" (Verbose)"
    fi
    log INFO "$log_command" 
    if [ "$VERBOSE" = true ]; then
#FIXME: add LC_ALL=C at the beginning of each command, as we want to be able to understand the logs, no matter the lang configuration
        eval "$command" 2>&1 | tee -a "$LOG_FILE" || { log ERROR "Failed command: $command"; return 1; }
    else
        eval "$command" >> "$LOG_FILE" 2>&1 || { log ERROR "Failed command: $command"; return 1; }
    fi
}

# Function to initialize log file
init_log() {
    touch "$LOG_FILE" || { log ERROR "Failed to create log file"; exit 1; }
    local git_hash=$(git rev-parse HEAD 2>/dev/null || echo "Git not available")
    echo -e "Commit hash: $git_hash" >> "$LOG_FILE"
    echo -e "Log file: $LOG_FILE\n" >> "$LOG_FILE"
}

# Function to set up logging
log_setup() {
    init_log
}

#===================================================================================
# Check for system updates
# Source : https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/package-management/DNF/#sec-Checking_For_and_Updating_Packages
#===================================================================================
# We need an up to date system !
updates() {
    log_msg "Checking for system updates:"
    if dnf check-update --refresh; then
        log_msg "System is up to date."
    else
        local errmsg=$(color_text 1 "[X] The script requires an updated system. Please update and reboot, then rerun the script.")
        log_msg "$errmsg"
        exit 1
    fi
}


#===================================================================================
# DNF configuration
# Source : https://linuxtricks.fr/wiki/fedora-script-post-installation
#===================================================================================
#FIXME: do not use instruction from the command line as name for function. -> rename function "dnf" to e.g. "config_dnf"
#line 121: "if dnf check-update --refresh; then"
#will trigger the function "dnf" and not the command
#log exemple: There is 2 times "Optimizing DNF:"
#[2024-04-28 09:14:44] INFO: Checking for system updates:
#[2024-04-28 09:14:44] INFO: Optimizing DNF:
#[2024-04-28 09:14:44] INFO: System is up to date.
#[2024-04-28 09:14:44] INFO: Optimizing DNF:
#[2024-04-28 09:14:44] INFO: Firmwares update:
dnf() {
    log_msg "Optimizing DNF:"
    #FIXME: no log from the instructions below -> log the msg from the echos
    {
        grep -Fq "fastestmirror=" /etc/dnf/dnf.conf || echo 'fastestmirror=true' | sudo tee -a /etc/dnf/dnf.conf
        grep -Fq "max_parallel_downloads=" /etc/dnf/dnf.conf || echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
        grep -Fq "countme=" /etc/dnf/dnf.conf || echo 'countme=true' | sudo tee -a /etc/dnf/dnf.conf
#FIXME: if run 2 times, there is no ERROR msg in the log
    } || { log ERROR "Failed to configure DNF"; exit 1; }
}


#===================================================================================
# Firmwares configuration
# Source : https://github.com/fwupd/fwupd#basic-usage-flow-command-line
#===================================================================================
firmwares() {
    log_msg "Firmwares update:"
    exec_command "sudo fwupdmgr get-devices"
    exec_command "sudo fwupdmgr refresh --force"
    #FIXME: we need to log those 2 command outputs. As of now this will break with set -e
    RC=0
    sudo fwupdmgr get-updates || RC=$?
    sudo fwupdmgr update || RC=$?
#FIXME: the exit satus are wrong, from "man fwupdmgr":
#EXIT STATUS
#Commands that successfully execute will return “0”, with generic failure as “1”.
#There are also several other exit codes used: A return code of “2” is used for commands that have no actions but were successfully executed, and “3” is used when a resource was not found.
    if [[ $RC -eq 0 ]]; then
        log_msg "Firmware updated successfully."
    elif [[ $RC -eq 1 ]]; then
        log_msg "No firmware updates available."
    else
        log_msg "Failed to update firmware."
    fi
}

system_setup() {
updates
dnf
firmwares
}

#===================================================================================
# RPM Fusion configuration
# Source : https://rpmfusion.org/Configuration
#===================================================================================
rpmfusion() {
    log_msg "Setting up RPM Fusion repositories:"
    exec_command "sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    exec_command "sudo dnf config-manager -y --enable fedora-cisco-openh264"
    exec_command "sudo dnf install -y rpmfusion-nonfree-release-tainted"

}

#===================================================================================
# Flathub configuration
# Source : https://flatpak.org/setup/Fedora
#===================================================================================
#FIXME: do not use instruction from the command line as name for function. -> rename function "flatpak" to e.g. "flatpak_install"
#line 333: exec_command "flatpak install -y flatseal"
#will trigger the function "flatpak" and not the command
#log exemple: 
#[2024-04-28 09:15:21] INFO: Executing: flatpak install -y flatseal
#Adding Flathub repository:
#[2024-04-28 09:15:21] INFO: Adding Flathub repository:
#[2024-04-28 09:15:21] INFO: Executing: sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak() {
#FIXME: rename this function to fedora_third_party
# this is broken, for some reason it does not activate Flathub
# change the command to "sudo fedora-third-party enable"
# this will enable flathub and also some dnf repositories, namely: "copr for pycharm", "google-chrome", "RPM fusion NVIDIA driver" and "RPM Fusion Steam". The last 2 are unecessary if RPM fusion is fully enabled...
# Source: https://fedoraproject.org/wiki/Changes/Third_Party_Software_Mechanism
# /var/lib/fedora-third-party/state gives the current state for each third party
# We could enable custom repositories using /usr/lib/fedora-third-party/conf.d (with either dnf or flatpak)
    log_msg "Adding Flathub repository:"
    exec_command "sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"

}

add_repositories() {
rpmfusion
flatpak
}

#===================================================================================
# NVIDIA GPU configuration
# Source : https://rpmfusion.org/Howto/NVIDIA
#===================================================================================
nvidia() {
    GPU_TYPE=$(lspci | grep -E "VGA|3D" | cut -d ":" -f3)
    if [[ $GPU_TYPE =~ "NVIDIA" ]]; then
        log_msg "Configuring for NVIDIA GPUs (2014+):"
        exec_command "sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda"
        exec_command "sudo dnf install -y xorg-x11-drv-nvidia-cuda-libs nvidia-vaapi-driver libva-utils vdpauinfo"
    else
        log_msg "No NVIDIA GPU detected, skipping NVIDIA driver installation."
    fi
}
#===================================================================================
# Hardware acceleration
# Sources : https://rpmfusion.org/Howto/Multimedia
#===================================================================================
hardware_acceleration() {
    log_msg "GPU hardware acceleration :"
#FIXME: one can have an integrated Intel GPU and a discret AMD GPU.
# thus we need to test all cases here separatly, as we want all GPU, discret and integrated, to have good support.
# "If test-commands returns a non-zero status, each elif list is executed in turn, and if its exit status is zero, the corresponding more-consequents is executed *and the command completes*."
#Source: https://www.gnu.org/software/bash/manual/bash.html#Conditional-Constructs
# -> replace all elif with several if...fi 
    if [[ $GPU_TYPE =~ "NVIDIA" ]]; then
        log_msg "Déjà configuré pour les GPU NVIDIA."
        # Note: NVIDIA driver configuration is already handled in the NVIDIA GPU configuration function.
        # sudo dnf install nvidia-vaapi-driver
    elif [[ $GPU_TYPE =~ "AMD" ]]; then
        log_msg "AMD GPU detected :"
        log_msg "Codecs for Mesa3D :"
        exec_command "sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld"
        exec_command "sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld"
        # i686 compat for Steam
        exec_command "sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686"
        exec_command "sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686"
        # RocM
        log_msg "Install ROCm :"
        exec_command "sudo dnf -y install rocm-opencl rocminfo rocm-clinfo rocm-hip rocm-runtime rocm-smi"
    elif [[ $GPU_TYPE =~ "INTEL" ]]; then
        log_msg "INTEL GPU detected :"
        log_msg "Codecs for Mesa3D :"
        exec_command "sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld"
        exec_command "sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld"
        # i686 compat for Steam
        exec_command "sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686"
        exec_command "sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686"
        exec_command "sudo dnf install -y intel-media-driver"
    fi
}

gpu() {
nvidia
hardware_acceleration
}

#===================================================================================
# Fonts Microsoft
# Source : https://www.linuxcapable.com/install-microsoft-fonts-on-fedora-linux/
#===================================================================================
microsoft_fonts() {
    log_msg "Install Microsoft fonts :"
    # added mkfontscale mkfontdir xset, as there is errors in the install script
    exec_command "sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig mkfontscale mkfontdir xset"
#FIXME: we should log this and manage error outputs
# "rpm" command exit code: "the exit code equals the number of failed packages, capped at 255"
    RC=0
    sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm || RC=$?
    if [[ $RC -eq 0 ]]; then
        log_msg "Microsoft fonts installed successfully."
    else
        log_msg "Failed to install Microsoft fonts."
    fi
}

# Install various fonts
various_fonts() {
    log_msg "Installing fonts (Google Roboto, Mozilla Fira, dejavu, liberation, Google Noto Emoji-sans-serif, Adobe Source, Awesome, Google Droid):"
    exec_command "sudo dnf install -y 'google-roboto*' 'mozilla-fira*' fira-code-fonts dejavu-fonts-all liberation-fonts google-noto-emoji-fonts google-noto-color-emoji-fonts google-noto-sans-fonts google-noto-serif-fonts 'adobe-source-code*' adobe-source-sans-pro-fonts adobe-source-serif-pro-fonts fontawesome-fonts-all google-droid-fonts-all"
}

fonts() {
microsoft_fonts
various_fonts
}

# Install compression tools
compression_tools() {
    log_msg "Installing compression tools (7zip, rar, ace, lha):"
    exec_command "sudo dnf install -y p7zip p7zip-plugins unrar unace lha"
}

# Desktop Tools
various-softwares() {
    log_msg "Installing OpenRGB, Fastfetch, flatseal and uBlock Origin for Firefox:"
    # gamemode is installed by default
    exec_command "sudo dnf install -y openrgb fastfetch mozilla-ublock-origin"
    #FIXME: actualy broken, does not install anything. cf. comments lines 208 & 217. Beside there is a rpm.
    exec_command "flatpak install -y flatseal"
}

#===================================================================================
# Multimedia configuration
# Source : https://rpmfusion.org/Howto/Multimedia
#===================================================================================
setup_multimedia() {
    log_msg "Setting up multimedia support:"
    exec_command "sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing"
    exec_command "sudo dnf groupupdate -y multimedia --setopt='install_weak_deps=False' --exclude=PackageKit-gstreamer-plugin"
    exec_command "sudo dnf groupupdate -y sound-and-video"
}

# Various firmware. Tainted nonfree is dedicated to non-FLOSS packages without a clear redistribution status by the copyright holder. But is allowed as part of hardware inter-operability between operating systems in some countries :
nonfree_firmware() {
    log_msg "Installing various non-free firmware packages (b43, broadcom-bt, dvb, nouveau):"
    exec_command "sudo dnf --repo=rpmfusion-nonfree-tainted install -y '*-firmware'"
}

utilities() {
compression_tools
#FIXME: use underscore
various-softwares
setup_multimedia
nonfree_firmware
}

# Configure GNOME desktop
gnome() {
    if [[ $(pgrep -c gnome-shell) -gt 0 ]]; then
        log_msg "Installing GNOME Tweaks and essential GNOME Shell extensions:"
        exec_command "sudo dnf install -y gnome-tweaks gnome-extensions-app gnome-shell-extension-appindicator gnome-shell-extension-caffeine gnome-shell-extension-gamemode gnome-shell-extension-gsconnect"
        # replace gnome-extensions-app? Does it update extensions as gnome-extensions-app does?
        exec_command "flatpak install flathub com.mattjakeman.ExtensionManager"

        if [[ ! -f /etc/dconf/db/local.d/00-extensions ]]; then
            echo "Setting up system-wide GNOME extensions."
            #FIXME: log all this
            sudo tee /etc/dconf/db/local.d/00-extensions > /dev/null <<EOF
[org/gnome/shell]
enabled-extensions=['gsconnect@andyholmes.github.io', 'appindicatorsupport@rgcjonas.gmail.com', 'gamemode@christian.kellner.me', 'caffeine@patapon.info']
EOF
            sudo dconf update
        else
            log_msg "System-wide GNOME extensions configuration already exists."
        fi
        #FIXME: This is broken for some reason. Tested on F40, should test on F39 and search bugzilla, seems off per documentations...
        #log_msg "enable extensions for the current user"
	#sleep 10
	#exec_command "gnome-extensions enable gsconnect@andyholmes.github.io"
	#exec_command "gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com"
	##FIXME: this will brake as this extension is broken. Need better error management: this should not stop the script, we should find a way to check if an extension is avalaible.
	##exec_command "gnome-extensions enable gamemode@christian.kellner.me"
	#exec_command "gnome-extensions enable caffeine@patapon.info"
    fi
}

desktop_environment() {
gnome
}

tools_to_manage_btrfs() {
# Check if the system is using btrfs for the root partition
lsblk -f |
while IFS= read -r line; do
	if [[ "$line" == */ && "$line" =~ "btrfs" ]]; then #root filesystem && it's using btrfs?
		log_msg "Btrfs format detected for root partition."
		# btrfs-assistant run its GUI in root, this is really bad. Any replacement?
		log_msg "Installing btrfs-assistant :"
		exec_command "sudo dnf install -y btrfs-assistant"
	fi
done
}

btrfs_management() {
tools_to_manage_btrfs
}

# Main function to run all tasks
main() {
    log_setup
    check_network_connection
    system_setup
    add_repositories
    gpu
    fonts
    utilities
    desktop_environment
    btrfs_management
    log_msg "$(color_text 2 "[X] Script completed. Please reboot.")"
}

# Run the script
main
