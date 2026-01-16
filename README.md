# ✅ JellyfinXArrStack – Installatie & Setup Checklist (Nederlands)

## 1️⃣ Jellyfin – Media Server
- [ ] Open WebUI: `http://<server-ip>:8096`
- [ ] Server een naam geven
- [ ] Admin gebruiker aanmaken
- [ ] Extra gebruikers toevoegen (optioneel)
- [ ] Bibliotheken toevoegen:
  - `/mnt/media-server/movies` → Films
  - `/mnt/media-server/series` → Series
- [ ] VAAPI hardware transcoding inschakelen
- [ ] Plugins installeren (optioneel, bv. OpenSubs)

## 2️⃣ qBittorrent – Download Client
- [ ] Open WebUI: `http://<server-ip>:8080`
- [ ] Koppelen met Sonarr en Radarr
- [ ] Downloadmappen controleren

## 3️⃣ Radarr – Films
- [ ] Open WebUI: `http://<server-ip>:7878`
- [ ] Gebruiker instellen (PUID/PGID)
- [ ] Bibliotheekpad instellen: `/mnt/media-server/movies`
- [ ] Download client koppelen: qBittorrent
- [ ] Indexers toevoegen (TMDB, NZB, torrents)

## 4️⃣ Sonarr – Series
- [ ] Open WebUI: `http://<server-ip>:8989`
- [ ] Gebruiker instellen (PUID/PGID)
- [ ] Bibliotheekpad instellen: `/mnt/media-server/series`
- [ ] Download client koppelen: qBittorrent
- [ ] Indexers toevoegen (TVDB, Jackett)

## 5️⃣ Watchtower – Automatische updates
- [ ] Controleer logs: `docker logs -f watchtower`
- [ ] Controleren of updates automatisch worden uitgevoerd

## 6️⃣ Docker / Docker Compose
- [ ] Controleer containers:  
```bash
cd /mnt/media-server/config
docker compose ps

    Controleer PUID/PGID rechten

7️⃣ Portainer – Docker Management

Open WebUI: http://<server-ip>:9000

Admin gebruiker aanmaken

    Stack bekijken of importeren

8️⃣ Unattended-upgrades – Automatische updates

Configuratiebestand controleren: /etc/apt/apt.conf.d/50unattended-upgrades

    Eventueel automatische reboot inschakelen:

Unattended-Upgrade::Automatic-Reboot "true";

9️⃣ Fail2Ban – Beveiliging

Jail configureren via /etc/fail2ban/jail.local

    Status controleren:

sudo fail2ban-client status
sudo fail2ban-client status sshd

🔟 Bazarr – Ondertitels

Open WebUI: http://<server-ip>:6767

Gebruiker instellen (PUID/PGID)

Mappen instellen:

    Films: /mnt/media-server/movies

    Series: /mnt/media-server/series

Ondertitel indexers toevoegen: OpenSubtitles, Addic7ed, etc.

    Koppelen met Jellyfin (optioneel)

💡 Extra tips

    Check Watchtower logs en backups: /mnt/media-server/backup (laatste 7 backups)

    Bij problemen: herstart een container:

docker restart <container_naam>

    Maak een lijst van gebruikers, API-keys en mappen voordat je begint
