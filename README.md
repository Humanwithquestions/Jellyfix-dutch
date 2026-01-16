# Jellyfix-dutch

Deze setup jellyfix in het nederlands.
Deze setup maakt alles klaar voor te streamen, en te downloaden.
Het houd in:
-Jellyfin                  streaming;
-qBittorent                torrenting/downloading;
-Prowlarr                  Indexers;
-Radarr                    Films;
-Sonarr                    Series;
-watchtower                Automatische updates voor docker;
-docker, docker compose    Lxc's;
-Portainer                 Monitoren van docker tool;
-Unattended-upgrades       Systeem updates;
-Fail2ban                  Ssh brute force attacks blocker;
-Bazarr                    Voor ondertitels;

# Al deze diensten moet je zelf instellen.
Jellyfin:                  server een naam geven, gebruikers, bibliotheken instellen, VAAPI transcoderen 
qBittorent:                Koppelen met Radarr, Sonarr
Radarr:                    Gebruiker, etc
Sonarr:                    Gebruiker, etc
Watchtower:                Gebruiker, etc
docker:                    Normaal niks
Portainer:                 Gebruiker, etc
Unattended-upgrades:       Instellen van de conf bestand
Fail2ban:                  Ook het instellen van het conf bestand
Bazarr:                    Het instelllen van gebruiker en welke ontertitel indexers je wilt gebruiken, of eventueel Jellyfin>Plugins>opensubs

# ;TDLR
Dit script doet veel voor jou maar je moet wel de basics kennen om dit in te stellen.
Je kan ook youtube tutorials gebruiken of ai om je te helpen.
Vergeet je wachtwoord niet het is echt pijnlijk om het opnieuw in te stellen, schrijf het ergens op en gebruik mss ook hetzelfde paswoord wij elke dienst.
Veel succes!
