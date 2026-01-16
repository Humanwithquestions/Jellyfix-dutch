#!/bin/bash

# JellyfinXArrStack_Fail2Ban - Debian Desktop Media Server Setup (Productie + Backup)
# Gebruiker: Boss
# -Gemaakt door TerminalX Group-

set -e

echo "Start setup van JellyfinXArrStack voor Debian Desktop (Productie + Backup)..."

# Controleer of een commando bestaat
commando_bestaat() {
    command -v "$1" >/dev/null 2>&1
}

####################################
# Benodigde pakketten installeren
####################################
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release ufw unattended-upgrades fail2ban parted tar

####################################
# Docker installeren
####################################
if ! commando_bestaat docker; then
    echo "Docker wordt geïnstalleerd..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
fi

####################################
# Legacy Docker Compose fallback
####################################
if ! commando_bestaat docker-compose; then
    echo "Docker Compose (legacy) wordt geïnstalleerd..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

####################################
# Tijdzone instellen
####################################
read -p "Voer je tijdzone in (bijv. Europe/Brussels): " TIJDZONE
sudo timedatectl set-timezone "$TIJDZONE"

####################################
# PUID en PGID detecteren voor containers
####################################
GEBRUIKER=$(whoami)
PUID=$(id -u "$GEBRUIKER")
PGID=$(id -g "$GEBRUIKER")
echo "Gebruik PUID=$PUID en PGID=$PGID voor containers."

####################################
# Auto-login op tty1
####################################
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $GEBRUIKER --noclear %I \$TERM
EOF

####################################
# Systeem slaap/idle voorkomen
####################################
sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=suspend/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#IdleAction=suspend/IdleAction=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

sudo setterm -blank 0 -powerdown 0 -powersave off

# GNOME Desktop: schermvergrendeling en idle uitschakelen
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.screensaver lock-enabled false || true
    gsettings set org.gnome.desktop.session idle-delay 0 || true
fi

####################################
# Schijf selectie en automatische partitionering
####################################
echo "Beschikbare schijven:"
lsblk -d -o NAME,SIZE,MODEL
read -p "Selecteer de schijf voor de mediaserver (bijv. sdb): " SCHIJFNAAM
SCHIJF="/dev/$SCHIJFNAAM"

if [ ! -b "$SCHIJF" ]; then
    echo "Schijf niet gevonden!"
    exit 1
fi

echo "⚠ WAARSCHUWING: Alle data op $SCHIJF wordt verwijderd!"
read -p "Typ 'JA' om door te gaan: " BEVESTIG

if [[ "$BEVESTIG" != "JA" ]]; then
    echo "Afgebroken."
    exit 1
fi

sudo wipefs -a "$SCHIJF"
sudo parted -s "$SCHIJF" mklabel gpt
sudo parted -s -a optimal "$SCHIJF" mkpart primary ext4 0% 100%
PARTITIE="${SCHIJF}1"
sudo mkfs.ext4 "$PARTITIE"

MOUNT="/mnt/media-server"
sudo mkdir -p "$MOUNT"
sudo mount "$PARTITIE" "$MOUNT"

UUID=$(sudo blkid -s UUID -o value "$PARTITIE")
grep -q "$UUID" /etc/fstab || \
echo "UUID=$UUID $MOUNT ext4 defaults 0 2" | sudo tee -a /etc/fstab
echo "✅ Schijf $SCHIJF gepartitioneerd en gemount op $MOUNT"

####################################
# Mediamappen aanmaken
####################################
sudo mkdir -p "$MOUNT/movies" "$MOUNT/series" "$MOUNT/config"
sudo chown -R $GEBRUIKER:$GEBRUIKER "$MOUNT"

####################################
# DNS
####################################
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

####################################
# Firewall
####################################
sudo ufw allow 22/tcp
sudo ufw allow 8096/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 8989/tcp
sudo ufw allow 7878/tcp
sudo ufw allow 9696/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 6881/tcp
sudo ufw allow 6881/udp
sudo ufw allow 6767/tcp
sudo ufw --force enable

####################################
# Automatische updates & Fail2Ban
####################################
sudo systemctl enable unattended-upgrades fail2ban
sudo systemctl start unattended-upgrades fail2ban

####################################
# Docker netwerk voor isolatie
####################################
NETWERK="media"
if ! docker network inspect "$NETWERK" >/dev/null 2>&1; then
    docker network create "$NETWERK"
fi

####################################
# Docker Compose Stack
####################################
COMPOSE="$MOUNT/config/docker-compose.yml"
cat > "$COMPOSE" <<EOL
version: "3.8"

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    networks:
      - $NETWERK
    ports:
      - "8096:8096"
    volumes:
      - $MOUNT/movies:/media/movies
      - $MOUNT/series:/media/series
      - $MOUNT/config/jellyfin:/config
    environment:
      - TZ=$TIJDZONE
    restart: unless-stopped

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    networks:
      - $NETWERK
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $MOUNT/config/portainer:/data
    restart: unless-stopped

  sonarr:
    image: linuxserver/sonarr:latest
    container_name: sonarr
    networks:
      - $NETWERK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIJDZONE
    volumes:
      - $MOUNT/series:/tv
      - $MOUNT/movies:/downloads
      - $MOUNT/config/sonarr:/config
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: linuxserver/radarr:latest
    container_name: radarr
    networks:
      - $NETWERK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIJDZONE
    volumes:
      - $MOUNT/movies:/movies
      - $MOUNT/movies:/downloads
      - $MOUNT/config/radarr:/config
    ports:
      - "7878:7878"
    restart: unless-stopped

  prowlarr:
    image: linuxserver/prowlarr:latest
    container_name: prowlarr
    networks:
      - $NETWERK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIJDZONE
    volumes:
      - $MOUNT/config/prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped

  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    networks:
      - $NETWERK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIJDZONE
      - WEBUI_PORT=8080
    volumes:
      - $MOUNT/config/qbittorrent:/config
      - $MOUNT/movies:/downloads
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped

  bazarr:
    image: linuxserver/bazarr:latest
    container_name: bazarr
    networks:
      - $NETWERK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIJDZONE
    volumes:
      - $MOUNT/config/bazarr:/config
      - $MOUNT/movies:/movies
      - $MOUNT/series:/series
    ports:
      - "6767:6767"
    restart: unless-stopped

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    networks:
      - $NETWERK
    environment:
      - TZ=$TIJDZONE
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=300
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

networks:
  $NETWERK:
    external: true
EOL

####################################
# Start stack
####################################
cd "$MOUNT/config"
if commando_bestaat docker-compose; then
    docker-compose pull
    docker-compose up -d
else
    docker compose pull
    docker compose up -d
fi

####################################
# Geautomatiseerde backups van configs
####################################
BACKUP_DIR="$MOUNT/backup"
mkdir -p "$BACKUP_DIR"

BACKUP_SCRIPT="$MOUNT/config/backup-configs.sh"
cat > "$BACKUP_SCRIPT" <<'EOL'
#!/bin/bash
# Backup van container configs
BACKUP_DIR="/mnt/media-server/backup"
CONFIG_DIR="/mnt/media-server/config"
DATUM=$(date +%F_%H-%M-%S)
MAX_BACKUPS=7

tar -czf "$BACKUP_DIR/config_$DATUM.tar.gz" -C "$CONFIG_DIR" .
cd "$BACKUP_DIR"
ls -1tr | head -n -$MAX_BACKUPS | xargs -d '\n' rm -f 2>/dev/null || true
EOL

chmod +x "$BACKUP_SCRIPT"

sudo tee /etc/systemd/system/media-backup.service > /dev/null <<EOF
[Unit]
Description=Backup van mediaserver configs

[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT
EOF

sudo tee /etc/systemd/system/media-backup.timer > /dev/null <<EOF
[Unit]
Description=Dagelijkse backup van mediaserver configs

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now media-backup.timer

echo "✅ Dagelijkse automatische backups ingeschakeld in $BACKUP_DIR (laatste 7 behouden)"

echo "======================================"
echo " JellyfinXArrStack_Fail2Ban (Debian Desktop, Productie + Backup)"
echo "======================================"
echo "✔ Schijf gepartitioneerd en gemount"
echo "✔ Auto-login ingeschakeld"
echo "✔ Systeem slaapt niet / schermvergrendeling uitgeschakeld"
echo "✔ Firewall actief"
echo "✔ Fail2Ban actief"
echo "✔ Automatische updates ingeschakeld"
echo "✔ Docker netwerk aangemaakt: $NETWERK"
echo "✔ Containers actief (met Watchtower automatische updates)"
echo "✔ Dagelijkse automatische backups ingeschakeld"
echo ""
echo "Beheer stack:"
echo "cd $MOUNT/config && docker compose ps"
