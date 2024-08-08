#!/bin/bash
# https://github.com/juliokochhann 2024

function dotfiles {
    /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $@

    # https://www.atlassian.com/git/tutorials/dotfiles
}

function dconf_set() {
    schema="$1"
    key="$2"
    val="$3"

    gsettings set "$schema" "$key" "$val"
}

# --- Log errors ---------------------------------------------------------------

log_file='err.log'

# Redirect stderr to log file and stdout+stderr to terminal
exec 2> >(tee -a $log_file)

# ------------------------------------------------------------------------------

sudo --validate # elevate privileges

# --- Configure AlsaMixer ------------------------------------------------------

amixer set -c 0 Headphone 0db unmute    # unmute front panel headphone

alsactl --file $HOME/.config/asound.state store

# https://askubuntu.com/questions/50067/how-to-save-alsamixer-settings

# ------------------------------------------------------------------------------

# --- Network configuration ----------------------------------------------------

# Use Cloudflare's DNS resolver:
profile=$(nmcli -t -f name c show --active | grep '1')  # get ethernet profile name

nmcli c modify "$profile" ipv4.ignore-auto-dns yes
nmcli c modify "$profile" ipv6.ignore-auto-dns yes
nmcli c modify "$profile" ipv4.dns '1.1.1.1 1.0.0.1'
nmcli c modify "$profile" ipv6.dns '2606:4700:4700::1111 2606:4700:4700::1001'

sudo nmcli c reload
sudo systemctl restart NetworkManager

# ------------------------------------------------------------------------------

# --- Manage apt database ------------------------------------------------------

# Install Code apt repo and signing key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg

sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

echo 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

# Install Proton vpn apt repo and signing key
pkg='protonvpn-stable-release_1.0.3-3_all.deb'

wget -q https://repo.protonvpn.com/debian/dists/stable/main/binary-all/$pkg

sudo dpkg -i $pkg

rm -f packages.microsoft.gpg *.deb

# ------------------------------------------------------------------------------

# --- Install packages ---------------------------------------------------------

pkg='apt-transport-https git neofetch xclip audacity code gimp proton-vpn-gnome-desktop'

# Update apt cache
sudo apt-get update  --quiet    # apt-get is more suitable than apt for CLI
sudo apt-get install --assume-yes --quiet $pkg

# ------------------------------------------------------------------------------

# --- Remove packages ----------------------------------------------------------

sudo apt-get remove  --assume-yes --quiet --auto-remove brltty # causes issues with TTY ports

# ------------------------------------------------------------------------------

# --- Configure /home ----------------------------------------------------------

git clone --bare https://github.com/juliokochhann/dotfiles.git $HOME/.dotfiles

dotfiles checkout -f --quiet
dotfiles config status.showUntrackedFiles no

mkdir -p $HOME/Aplicativos $HOME/Arduino $HOME/Projetos

# ------------------------------------------------------------------------------

# --- Install debian packages --------------------------------------------------

api_url='https://api.github.com/repos'

# Install Git Credential Manager
repo='git-ecosystem/git-credential-manager'

url=$(curl -s $api_url/$repo/releases/latest | grep -Eo 'https.*amd64.*\.deb')

f='gcm-linux.deb'

curl -L --silent -o $f "$url"
sudo dpkg -i $f
git-credential-manager configure

# Install Emby server
repo='MediaBrowser/Emby.Releases'

url=$(curl -s $api_url/$repo/releases/latest | grep -Eo 'https.*deb.*amd64.*\.deb')

f='emby-server.deb'

curl -L --silent -o $f "$url"
sudo dpkg -i $f

rm -f *.deb

# ------------------------------------------------------------------------------

# --- Install AppImage applications --------------------------------------------

# Install Arduino IDE
repo='arduino/arduino-ide'

url=$(curl -s $api_url/$repo/releases/latest | grep -Eo 'https.*64bit.*\.AppImage')

f='arduino-ide.AppImage'

curl -L --silent -o $f "$url"

install -D -o $USER -g $USER -m 744 $f $HOME/Aplicativos/$f

# Post-install: add $USER to dialout group (for full and direct access to serial ports)
sudo usermod -a -G dialout $USER

# ------------------------------------------------------------------------------

# --- Install flatpak applications ---------------------------------------------

# flatpak install --noninteractive com.obsproject.Studio
# flatpak install --noninteractive org.fritzing.Fritzing
# flatpak install --noninteractive org.inkscape.Inkscape
# flatpak install --noninteractive org.kde.kdenlive

# ------------------------------------------------------------------------------

# --- Install bash-git-prompt --------------------------------------------------

git clone https://github.com/magicmonty/bash-git-prompt.git $HOME/.bash-git-prompt --depth=1 --quiet

# ------------------------------------------------------------------------------

# --- Mount partitions ---------------------------------------------------------

# Edit fstab to automount a fat32 partition:
partition='/dev/sdb1'
mount_point='/mnt/data'
emby_gid=$(id -g emby) # get emby group id
uuid=$(blkid $partition -s UUID -o value)
opt="rw,nosuid,nodev,relatime,uid=$UID,gid=$emby_gid,dmask=0002,fmask=0113,iocharset=utf8,codepage=850,x-gvfs-show,flush,uhelper=udisks2"
# codepage=850 (Brazil) is used for compatibility on legacy fat systems

echo "UUID=$uuid $mount_point vfat $opt 0 0" | sudo tee /etc/fstab > /dev/null

sudo mkdir -p $mount_point
sudo mount -a

# mkdir -p /mnt/data/.Trash-1000/{expunged,files,info}
# sudo chown -R $USER /mnt/data/.Trash-1000

# ------------------------------------------------------------------------------

# --- Install Dracula theme for terminal ---------------------------------------

schema='org.gnome.Terminal.ProfilesList'

id=$(gsettings get $schema default | tr -d "'")

schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$id/"

gsettings set $schema visible-name 'Dracula'

git clone https://github.com/dracula/gnome-terminal.git --quiet

/bin/bash gnome-terminal/install.sh --scheme=Dracula --profile 'Dracula' --skip-dircolors

rm -rf gnome-terminal

# ------------------------------------------------------------------------------

# --- Install mono font --------------------------------------------------------

base_url='https://raw.githubusercontent.com/google/fonts/main/apache/robotomono'

curl -L --silent -O $base_url'/RobotoMono\[wght\].ttf'
curl -L --silent -O $base_url'/RobotoMono-Italic\[wght\].ttf'

font_dir="$HOME/.fonts/Roboto Mono"
mkdir -p "$font_dir"
mv *.ttf "$font_dir"

fc-cache -f

# ------------------------------------------------------------------------------

# --- Install cinnamon applets -------------------------------------------------

base_url='https://cinnamon-spices.linuxmint.com/files/applets'

curl --remote-name --silent $base_url'/weather@mockturtl.zip'
curl --remote-name --silent $base_url'/temperature@fevimu.zip'

applets_dir="$HOME/.local/share/cinnamon/applets"

unzip -q '*.zip' -d "$applets_dir"

rm -f *.zip

# ------------------------------------------------------------------------------

# --- Dconf settings -----------------------------------------------------------

# Set default mono font
schema='org.gnome.desktop.interface'

dconf_set $schema monospace-font-name       'Roboto Mono 11'

# Customize gnome terminal
schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$id/"

dconf_set $schema use-theme-transparency            'false'
dconf_set $schema use-transparent-background        'true'
dconf_set $schema background-transparency-percent   10
dconf_set $schema scrollbar-policy                  'never'

# Customize text editor
schema='org.x.editor.preferences.editor'

dconf_set $schema display-line-numbers      true
dconf_set $schema highlight-current-line    true
dconf_set $schema scheme                    'tango'

# Set keyboard shortcuts
schema='org.cinnamon.desktop.keybindings.media-keys'

dconf_set $schema calculator        "['XF86Calculator',  '<Super>c']"
dconf_set $schema terminal          "['<Primary><Alt>t', '<Super>Return']"
dconf_set $schema www               "['HomePage', '<Super>b']"
dconf_set $schema email             "['XF86Mail', '<Super>m']"

schema='org.cinnamon.desktop.keybindings.wm'

dconf_set $schema toggle-maximized  "['F4']"

schema='org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/'

dconf_set $schema name              'Open System Monitor'
dconf_set $schema command           'gnome-system-monitor'
dconf_set $schema binding           "['<Primary><Shift>Escape']"

schema='org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/'

dconf_set $schema name              'Open Code Editor'
dconf_set $schema command           'code'
dconf_set $schema binding           "['<Super>z']"

schema='org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom2/'

dconf_set $schema name              'Open Text Editor'
dconf_set $schema command           'xed -s'
dconf_set $schema binding           "['<Super>t']"

schema='org.cinnamon.desktop.keybindings'

dconf_set $schema custom-list       "['custom0', 'custom1', 'custom2']"

# Customize desktop
schema='org.cinnamon.desktop.a11y.keyboard'

dconf_set $schema togglekeys-enable-osd     true

schema='org.cinnamon'

dconf_set $schema hotcorner-layout "['scale:true:100', 'scale:false:0', 'scale:false:0', 'desktop:false:0']"

schema='org.cinnamon.desktop.interface'

dconf_set $schema cursor-theme      'Bibata-Modern-Ice'
dconf_set $schema gtk-theme         'Mint-Y-Aqua'
dconf_set $schema icon-theme        'Mint-Y-Aqua'

schema='org.gnome.desktop.interface'

dconf_set $schema cursor-theme      'Bibata-Modern-Ice'
dconf_set $schema gtk-theme         'Mint-Y-Aqua'
dconf_set $schema icon-theme        'Mint-Y-Aqua'

schema='org.cinnamon.theme'

dconf_set $schema name              'Mint-Y-Dark-Aqua'

schema='org.cinnamon.sounds'

dconf_set $schema login-enabled             false
dconf_set $schema logout-enabled            false
dconf_set $schema switch-enabled            false
dconf_set $schema tile-enabled              false
dconf_set $schema plug-enabled              false
dconf_set $schema unplug-enabled            false
dconf_set $schema notification-enabled      false

schema='org.cinnamon.desktop.sound'

dconf_set $schema volume-sound-enabled      false

# ------------------------------------------------------------------------------
