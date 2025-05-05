#!/bin/bash

# RedScorpion OS Build Script
# Dieses Skript erstellt RedScorpion OS mit Home und Security Edition
# using Debian Live Build

set -e  # Beendet das Skript bei Fehlern

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# GitHub Repository URL
GITHUB_REPO="https://github.com/noKrypton/image"
GITHUB_RAW="https://raw.githubusercontent.com/noKrypton/image/main"

# Funktionen
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Prüfen, ob notwendige Tools installiert sind
check_dependencies() {
    log "Prüfe Abhängigkeiten..."
    
    # Live build benötigte Pakete - Plymouth entfernt
    packages=("live-build" "live-config" "live-boot" "debootstrap" "git" "curl" "wget")
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "ii  $pkg"; then
            warn "$pkg nicht gefunden. Wird installiert..."
            sudo apt-get update || error "Fehler beim Aktualisieren der Paketlisten"
            sudo apt-get install -y "$pkg" || error "Fehler bei der Installation von $pkg"
        fi
    done
    
    log "Alle Abhängigkeiten vorhanden."
}

# Arbeitsverzeichnisse erstellen
create_directory_structure() {
    log "Erstelle Verzeichnisstruktur für RedScorpion OS..."
    
    # Hauptverzeichnisse
    mkdir -p ./redscorpion-os/{home,security}
    
    # Gemeinsame Assets - Plymouth-Theme entfernt
    mkdir -p ./redscorpion-os/common/artwork
    mkdir -p ./redscorpion-os/common/grub-theme
    
    log "Verzeichnisstruktur erstellt."
}

# Herunterladen von Ressourcen von GitHub
download_github_resources() {
    log "Lade Ressourcen von GitHub herunter..."
    
    # Temporäres Verzeichnis für den Git-Clone
    mkdir -p ./temp_github
    cd ./temp_github
    
    # Clone das Repository
    git clone --depth 1 $GITHUB_REPO .
    
    if [ $? -ne 0 ]; then
        # Alternativer Ansatz mit direkten Downloads, falls Git nicht funktioniert
        warn "Git clone fehlgeschlagen, versuche direkten Download der Dateien..."
        mkdir -p gruby
        
        # Herunterladen der GRUB-Theme Dateien
        wget -P gruby/ $GITHUB_RAW/gruby/background.png
        wget -P gruby/ $GITHUB_RAW/gruby/install.sh
        wget -P gruby/ $GITHUB_RAW/gruby/item_c.png
        wget -P gruby/ $GITHUB_RAW/gruby/selected_item_c.png
        wget -P gruby/ $GITHUB_RAW/gruby/terminal_box_c.png
        wget -P gruby/ $GITHUB_RAW/gruby/theme.txt
        wget -P gruby/ $GITHUB_RAW/gruby/unifont-regular-16.pf2
        
        # Weitere Dateien herunterladen
        wget $GITHUB_RAW/scorp-1.png
        wget $GITHUB_RAW/scorp-index.png
    fi
    
    # Prüfen wir, welches Verzeichnis existiert
    if [ -d "gruby" ]; then
        log "GRUB-Theme-Verzeichnis 'gruby' gefunden..."
        
        # Kopiere die Dateien in die entsprechenden Verzeichnisse
        log "Kopiere GRUB-Theme Dateien..."
        cp -r gruby/* ../redscorpion-os/common/grub-theme/
    else
        warn "Weder 'grub' noch 'gruby' Verzeichnis gefunden. Versuche zu bestimmen, was verfügbar ist..."
        ls -la
        warn "Versuche mit find den richtigen Ordner zu finden..."
        find . -name "*grub*" -type d
    fi
    
    # Prüfe die vorhandenen Bild-Dateien
    if [ -f "scorp-1.png" ]; then
        log "Kopiere Hintergrund- und Icon-Dateien..."
        cp scorp-1.png ../redscorpion-os/common/artwork/scorp-background.png
    else
        warn "scorp-1.png nicht gefunden. Suche nach Alternativen..."
        find . -name "*.png" | grep -i "scorp\|background"
    fi
    
    if [ -f "scorp-index.png" ]; then
        cp scorp-index.png ../redscorpion-os/common/artwork/scorp-icon.png
    else
        warn "scorp-index.png nicht gefunden. Suche nach Alternativen..."
        find . -name "*.png" | grep -i "icon\|logo"
    fi
    
    # Zurück zum Hauptverzeichnis
    cd ..
    
    # Bereinigen des temporären Verzeichnisses
    rm -rf ./temp_github
    
    log "Ressourcen erfolgreich heruntergeladen."
}

# Konfiguriere live-build für Home Edition
configure_home_edition() {
    log "Konfiguriere Home Edition..."
    
    cd ./redscorpion-os/home
    
    # Grundkonfiguration
    lb config \
        --apt-indices false \
        --apt-recommends false \
        --debian-installer live \
        --debian-installer-gui false \
        --distribution bullseye \
        --archive-areas "main contrib non-free" \
        --binary-images iso-hybrid \
        --iso-application "RedScorpion OS Home Edition" \
        --iso-publisher "RedScorpion OS" \
        --iso-volume "RedScorpionHome" \
        --memtest none
    
    # Verzeichnisstruktur für Anpassungen - Plymouth-Verzeichnisse entfernt
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
    mkdir -p config/includes.chroot/boot/grub/themes/redscorpion
    mkdir -p config/includes.chroot/usr/share/backgrounds/redscorpion
    mkdir -p config/includes.chroot/usr/share/icons/redscorpion
    mkdir -p config/package-lists
    
    # Paketlisten - Plymouth entfernt
    cat > config/package-lists/desktop.list.chroot << 'EOF'
task-xfce-desktop
xfce4
xfce4-terminal
xfce4-goodies
lightdm
EOF
    
    cat > config/package-lists/redscorpion-home.list.chroot << 'EOF'
libreoffice
libreoffice-calc
libreoffice-writer
libreoffice-impress
libreoffice-draw
firefox-esr
curl
wget
git
sudo
bash-completion
build-essential
python3
python3-pip
python3-venv
EOF
    
    # Create the directory before writing to the file
    mkdir -p config/includes.chroot/usr/local/bin/
    
    # VS Code und weitere Software benötigen nicht-freie Repos oder manuelle Installation
    cat > config/includes.chroot/usr/local/bin/redscorpion-setup << 'EOF'
#!/bin/bash
# Skript zur Installation von zusätzlicher Software für RedScorpion OS Home Edition

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
sudo install -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft-archive-keyring.gpg
sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'

# Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Aktualisieren und Installieren
sudo apt-get update
sudo apt-get install -y code docker-ce docker-ce-cli containerd.io

# PyCharm (Snap oder Flatpak benötigt)
# Hier könnte ein Download-Skript für PyCharm und Eclipse hinzugefügt werden
EOF
    
    chmod +x config/includes.chroot/usr/local/bin/redscorpion-setup
  
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
    
    # XFCE-Konfiguration für rotes Farbschema
    cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Default-red"/>
    <property name="title_font" type="string" value="Sans Bold 9"/>
    <property name="button_layout" type="string" value="O|HMC"/>
  </property>
</channel>
EOF
    
    cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="redscorpion"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="ColorScheme" type="string" value="selected_bg_color:#cc0000\nselected_fg_color:#ffffff"/>
  </property>
</channel>
EOF

    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/
    
    # Panel-Konfiguration
    cat > config/includes.chroot/etc/skel/.config/xfce4/panel/default.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="0"/>
    <property name="panel-0" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-icon" type="string" value="/usr/share/icons/redscorpion/scorp-icon.png"/>
    </property>
    <property name="plugin-2" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="firefox-esr.desktop"/>
      </property>
    </property>
    <property name="plugin-3" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="xfce4-terminal.desktop"/>
      </property>
    </property>
    <property name="plugin-4" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="code.desktop"/>
      </property>
    </property>
    <property name="plugin-5" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="libreoffice-writer.desktop"/>
      </property>
    </property>
    <property name="plugin-6" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="libreoffice-calc.desktop"/>
      </property>
    </property>
    <property name="plugin-7" type="string" value="separator"/>
  </property>
</channel>
EOF

    # GRUB-Konfiguration für Dual-Boot-Optionen
    mkdir -p config/includes.chroot/etc/default/
    cat > config/includes.chroot/etc/default/grub << 'EOF'
# RedScorpion OS GRUB configuration
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_BACKGROUND="/boot/grub/themes/redscorpion/background.png"
GRUB_THEME="/boot/grub/themes/redscorpion/theme.txt"
EOF
    
    cd ..
    log "Home Edition konfiguriert."
}

# Konfiguriere live-build für Security Edition
configure_security_edition() {
    log "Konfiguriere Security Edition..."
    
    mkdir -p ./redscorpion-os/security

    cd ./redscorpion-os/security
    
    # Grundkonfiguration
    lb config \
        --apt-indices false \
        --apt-recommends false \
        --debian-installer live \
        --debian-installer-gui false \
        --distribution bullseye \
        --archive-areas "main contrib non-free" \
        --binary-images iso-hybrid \
        --iso-application "RedScorpion OS Security Edition" \
        --iso-publisher "RedScorpion OS" \
        --iso-volume "RedScorpionSec" \
        --memtest none
    
    # Verzeichnisstruktur für Anpassungen - Plymouth-Verzeichnisse entfernt
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
    mkdir -p config/includes.chroot/boot/grub/themes/redscorpion
    mkdir -p config/includes.chroot/usr/share/backgrounds/redscorpion
    mkdir -p config/includes.chroot/usr/share/icons/redscorpion
    mkdir -p config/package-lists
    
    # Paketlisten - Plymouth entfernt
    cat > config/package-lists/desktop.list.chroot << 'EOF'
task-xfce-desktop
xfce4
xfce4-terminal
xfce4-goodies
lightdm
EOF
    
    cat > config/package-lists/redscorpion-security.list.chroot << 'EOF'
# Basis-Tools
firefox-esr
python3
python3-pip
python3-venv
curl
wget
git
sudo
bash-completion
build-essential

# Security-Tools
nmap
wireshark
tshark
aircrack-ng
nikto
hydra
john
tor
thunderbird
kleopatra
EOF

    mkdir -p config/includes.chroot/usr/local/bin/
    # Skript für zusätzliche Security-Tools
    cat > config/includes.chroot/usr/local/bin/redscorpion-security-setup << 'EOF'
#!/bin/bash
# Skript zur Installation von zusätzlichen Security-Tools für RedScorpion OS

# Metasploit Framework Repository
curl -fsSL https://apt.metasploit.com/metasploit-framework.gpg | sudo gpg --dearmor -o /usr/share/keyrings/metasploit-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/metasploit-archive-keyring.gpg] https://apt.metasploit.com buster main" | sudo tee /etc/apt/sources.list.d/metasploit.list > /dev/null

# Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
sudo install -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft-archive-keyring.gpg
sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'

# Aktualisieren und Installieren
sudo apt-get update
sudo apt-get install -y metasploit-framework docker-ce docker-ce-cli containerd.io code

# Burp Suite (Community Edition)
wget -O /tmp/burpsuite.sh "https://portswigger.net/burp/releases/download?product=community&version=latest&type=Linux"
chmod +x /tmp/burpsuite.sh
/tmp/burpsuite.sh

# PyCharm (Snap oder Flatpak benötigt)
# Hier könnte ein Download-Skript für PyCharm hinzugefügt werden
EOF
    
    chmod +x config/includes.chroot/usr/local/bin/redscorpion-security-setup
    
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
    # XFCE-Konfiguration für rotes Farbschema
    cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Default-red"/>
    <property name="title_font" type="string" value="Sans Bold 9"/>
    <property name="button_layout" type="string" value="O|HMC"/>
  </property>
</channel>
EOF
    
    cat > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="redscorpion"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="ColorScheme" type="string" value="selected_bg_color:#cc0000\nselected_fg_color:#ffffff"/>
  </property>
</channel>
EOF
    
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/
    # Panel-Konfiguration für Security Edition
    cat > config/includes.chroot/etc/skel/.config/xfce4/panel/default.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="0"/>
    <property name="panel-0" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-icon" type="string" value="/usr/share/icons/redscorpion/scorp-icon.png"/>
    </property>
    <property name="plugin-2" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="tor-browser.desktop"/>
      </property>
    </property>
    <property name="plugin-3" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="xfce4-terminal.desktop"/>
      </property>
    </property>
    <property name="plugin-4" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="pycharm.desktop"/>
      </property>
    </property>
    <property name="plugin-5" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="metasploit.desktop"/>
      </property>
    </property>
    <property name="plugin-6" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="nmap.desktop"/>
      </property>
    </property>
    <property name="plugin-7" type="string" value="separator"/>
  </property>
</channel>
EOF
    
    # GRUB-Konfiguration - 'splash' removed from parameters
    mkdir -p config/includes.chroot/etc/default
    cat > config/includes.chroot/etc/default/grub << 'EOF'
# RedScorpion OS GRUB configuration
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_BACKGROUND="/boot/grub/themes/redscorpion/background.png"
GRUB_THEME="/boot/grub/themes/redscorpion/theme.txt"
EOF
    
    cd ..
    log "Security Edition konfiguriert."
}

# Funktion zum Kopieren der Assets in beide Editionen
copy_assets() {
    log "Kopiere Assets in beide Editionen..."
    
    # Kopiere GRUB-Theme in beide Editionen
    cp -r ./redscorpion-os/common/grub-theme/* ./redscorpion-os/home/config/includes.chroot/boot/grub/themes/redscorpion/
    cp -r ./redscorpion-os/common/grub-theme/* ./redscorpion-os/security/config/includes.chroot/boot/grub/themes/redscorpion/
    
    # Kopiere Hintergrundbilder in beide Editionen
    mkdir -p ./redscorpion-os/home/config/includes.chroot/usr/share/backgrounds/redscorpion/
    mkdir -p ./redscorpion-os/security/config/includes.chroot/usr/share/backgrounds/redscorpion/
    cp ./redscorpion-os/common/artwork/scorp-background.png ./redscorpion-os/home/config/includes.chroot/usr/share/backgrounds/redscorpion/
    cp ./redscorpion-os/common/artwork/scorp-background.png ./redscorpion-os/security/config/includes.chroot/usr/share/backgrounds/redscorpion/
    
    # Kopiere Icons in beide Editionen
    mkdir -p ./redscorpion-os/home/config/includes.chroot/usr/share/icons/redscorpion/
    mkdir -p ./redscorpion-os/security/config/includes.chroot/usr/share/icons/redscorpion/
    cp ./redscorpion-os/common/artwork/scorp-icon.png ./redscorpion-os/home/config/includes.chroot/usr/share/icons/redscorpion/
    cp ./redscorpion-os/common/artwork/scorp-icon.png ./redscorpion-os/security/config/includes.chroot/usr/share/icons/redscorpion/
    
    log "Assets kopiert."
}

# Funktion zum Erstellen von ISO-Images
create_iso_images() {
    log "Erstelle ISO-Images..."
    
    # Erstelle zuerst beide ISOs
    cd ./redscorpion-os/home
    log "Baue Home Edition..."
    lb build 2>&1 | tee ../home-build.log || { error "Fehler beim Erstellen der Home Edition"; }
    cd ../security
    log "Baue Security Edition..."
    lb build 2>&1 | tee ../security-build.log || { error "Fehler beim Erstellen der Security Edition"; }
    cd ..
    
    # Kopiere die fertigen ISOs in das Hauptverzeichnis
    cp ./home/live-image-amd64.hybrid.iso ../redscorpion-os-home.iso
    cp ./security/live-image-amd64.hybrid.iso ../redscorpion-os-security.iso
    
    log "Build abgeschlossen. Die ISOs befinden sich im Hauptverzeichnis:"
    log "  - redscorpion-os-home.iso (Home Edition)"
    log "  - redscorpion-os-security.iso (Security Edition)"
}

# Haupt-Skript
main() {
    log "RedScorpion OS Build-Skript gestartet."
    
    # Prüfe Abhängigkeiten
    check_dependencies
    
    # Erstelle Verzeichnisstruktur
    create_directory_structure
    
    # Lade Ressourcen von GitHub herunter
    download_github_resources
    
    # Konfiguriere beide Editionen
    configure_home_edition
    configure_security_edition
    
    # Kopiere Assets
    copy_assets
    
    # Erstelle ISOs
    create_iso_images
    
    log "RedScorpion OS wurde erfolgreich erstellt!"
}

# Skript ausführen
main
