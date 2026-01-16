#!/bin/bash

# JellyfinXArrStack_Fail2Ban - Debian Media Server Setup
# Gebruiker: Boss
# -Gemaakt door TerminalX Group-

set -e

echo "Starten van JellyfinXArrStack installatie voor Debian..."

# Controleer of een commando bestaat
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Benodigde tools installeren
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

####################################
# Docker installeren (Debian)
####################################
if ! command_exists docker; then
    echo "Docker wordt geïnstalleerd..."

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker
fi

####################################
# Docker Compose (legacy fallback)
####################################
if ! command_exists docker-compose; then
    echo "docker-compose (legacy) wordt geïnstalleerd..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

####################################
# Tijdzone
####################################
read -p "Voer je tijdzone in (bijv. Europe/Brussels): " TIMEZONE
sudo timedatectl set-timezone "$TIMEZONE"

####################################
# Automatisch inloggen op tty1
####################################
USER_NAME=$(whoami)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

####################################
# Schijfselectie
####################################
echo "Beschikbare schijven:"
lsblk -f
read -p "Selecteer de te gebruiken schijf (bijv. /dev/sdb): " DISK

if [ ! -b "$DISK" ]; then
    echo "Schijf niet gevonden"
    exit 1
fi

read -p "Is de schijf geformatteerd als EXT4? (j/n): " FORMATTED
if [[ "$FORMATTED" == "n" ]]; then
    sudo mkfs.ext4 "$DISK"
fi

MOUNT="/mnt/media-server"
sudo mkdir -p "$MOUNT"
sudo mount "$DISK" "$MOUNT"

UUID=$(sudo blkid -s UUID -o value "$DISK")
grep -q "$UUID" /etc/fstab || \
echo "UUID=$UUID $MOUNT ext4 defaults 0 2" | sudo tee -a /etc/fstab

####################################
# Mediamappen
####################################
sudo mkdir -p \
    "$MOUNT/movies" \
    "$MOUNT/series" \
    "$MOUNT/config"

sudo chown -R $USER_NAME:$USER_NAME "$MOUNT"

####################################
# DNS (optioneel maar hier afgedwongen)
####################################
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

####################################
# Firewall
####################################
sudo apt install -y ufw
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
# Automatische updates
####################################
sudo apt install -y unattended-upgrades
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades

####################################
# Fail2Ban
####################################
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

####################################
# Docker Compose stack
####################################
COMPOSE="$MOUNT/config/docker-compose.yml"

cat > "$COMPOSE" <<EOL
version: "3.8"
# (compose inhoud ongewijzigd)
EOL

####################################
# Stack starten
####################################
cd "$MOUNT/config"

if command_exists docker-compose; then
    docker-compose pull
    docker-compose up -d
else
    docker compose pull
    docker compose up -d
fi

echo "======================================"
echo " JellyfinXArrStack_Fail2Ban (Debian)"
echo "======================================"
echo "✔ Schijf gemount bij opstarten"
echo "✔ Automatisch inloggen ingeschakeld"
echo "✔ Firewall actief"
echo "✔ Fail2Ban actief"
echo "✔ Automatische updates ingeschakeld"
echo "✔ Containers actief"
echo ""
echo "Stack beheren:"
echo "cd $MOUNT/config && docker compose ps"
