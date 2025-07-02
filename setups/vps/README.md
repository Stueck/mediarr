
- [Übersicht](#übersicht)
  - [Behandelte und angebundene interne Dienste](#behandelte-und-angebundene-interne-dienste)
    - [Emby](#emby)
    - [Jellyseerr](#jellyseerr)
- [VPS Einrichtung (Allgemein \& Sicherheit)](#vps-einrichtung-allgemein--sicherheit)
  - [Zeit \& Lokalisierung](#zeit--lokalisierung)
  - [Unnötige Dienste prüfen](#unnötige-dienste-prüfen)
  - [System aktualisieren](#system-aktualisieren)
  - [Automatische Sicherheitsupdates](#automatische-sicherheitsupdates)
  - [Swap aktivieren (wenn RAM \< 2 GB)](#swap-aktivieren-wenn-ram--2-gb)
  - [Root-Zugriff absichern / neuen Benutzer einrichten](#root-zugriff-absichern--neuen-benutzer-einrichten)
  - [iptables einrichten](#iptables-einrichten)
- [WireGuard-VPN](#wireguard-vpn)
  - [Allgemein](#allgemein)
  - [Installation](#installation)
  - [Konfiguration](#konfiguration)
    - [Keys erzeugen](#keys-erzeugen)
    - [Datei erstellen](#datei-erstellen)
    - [Dienst aktivieren und starten](#dienst-aktivieren-und-starten)
    - [Heimnetz Wireguard (z.B. OPNSense) konfigurieren](#heimnetz-wireguard-zb-opnsense-konfigurieren)
- [DNS](#dns)
  - [Einträge](#einträge)
  - [Cloudflare (optional)](#cloudflare-optional)
- [NGINX-Reverse-Proxy](#nginx-reverse-proxy)
  - [Übersicht](#übersicht-1)
    - [Dateien](#dateien)
    - [Struktur](#struktur)
  - [Installation](#installation-1)
  - [TLS-Zertifikate via Certbot](#tls-zertifikate-via-certbot)
    - [Automatische Verlängerung](#automatische-verlängerung)
  - [Konfigs bereit und los (TL;DR)](#konfigs-bereit-und-los-tldr)
  - [Details \& Erläuterungen](#details--erläuterungen)
    - [Reverse Proxy](#reverse-proxy)
      - [Hinweise](#hinweise)
      - [Nginx Allgemein `nginx.conf`](#nginx-allgemein-nginxconf)
      - [DNS-Rebind-Schutz](#dns-rebind-schutz)
    - ['Silent Drop' alle ungültigen Domains](#silent-drop-alle-ungültigen-domains)
      - [Vorteile](#vorteile)
      - [Testen](#testen)
- [Crowdsec](#crowdsec)
  - [Crowdsec installieren](#crowdsec-installieren)
  - [!!! Eigene iptables wiederherstellen (reboot) !!!](#-eigene-iptables-wiederherstellen-reboot-)
  - [Bannzeit anpassen und dynamisch erhöhen](#bannzeit-anpassen-und-dynamisch-erhöhen)
    - [Dienststatus prüfen](#dienststatus-prüfen)
    - [Optional: Mit Crowdsec Console verbinden (Weboberfläche):](#optional-mit-crowdsec-console-verbinden-weboberfläche)
    - [Optional: Automatische Aktualisierungen](#optional-automatische-aktualisierungen)
  - [Ausgesperrt?](#ausgesperrt)
  - [Optional: Benachrichtigungen einrichten](#optional-benachrichtigungen-einrichten)
- [Todo: Monitoring einrichten](#todo-monitoring-einrichten)


# Übersicht

* **Ziel:** Zugriff auf interne Dienste (z. B. Emby, Jellyseerr) über einen öffentlichen VPS mittels WireGuard-Tunnel ins Heimnetz via NGINX-Reverse-Proxy mit Let’s Encrypt-Zertifikaten und Crowdsec Schutz.
* **Sicherheit:** TLS-Verschlüsselung, DNS-Rebind-Schutz, automatisierte Sperrungen über Crowdsec, SSH-Key-Login, kein rootlogin, kein Passwortlogin
* **Hostsystem:** Debian 12 auf einem VPS (1 vCore, 1 GB RAM, IPv4 & IPv6).
* **Heimnetz:** OPNsense-VM mit WireGuard-"Client" vermittelt an interne Dienste (DMZ-artig).


## Behandelte und angebundene interne Dienste

### Emby
* Läuft intern in DMZ z.B. `10.10.10.10:8096` (hinter Opnsense-VM)
* Reverse-Proxied via `emby.example.com`
* Logformat angepasst in nginx `emby.conf` 
* (Konfigs für Jellyfin dürften sehr ähnlich sein)

### Jellyseerr

* Läuft intern in DMZ auf z.B. `10.10.10.11:5055` (hinter Opnsense-VM)
* Reverse-Proxied via `jellyseerr.example.com`
* zusätzlich per Cloudflare Proxy geschützt
* greift auf Radarr/Sonarr in anderem isoliertem Subnetz zu (Opnsense Firewall-Regel)

---

# VPS Einrichtung (Allgemein & Sicherheit)

## Zeit & Lokalisierung

```bash
timedatectl set-timezone Europe/Berlin
apt install locales -y
dpkg-reconfigure locales
```
- de_DE.UTF-8 (für Deutsch)
- en_US.UTF-8 (Standard US-Englisch, UTF-8)

## Unnötige Dienste prüfen

```bash
ss -tuln
```
=> ggf. Dienste entfernen, die nicht gebraucht werden (z. B. Exim, FTP, Avahi, …).

Erwartete Ausgabe:
- `:22` = SSH offen (Port ggf. später ändern)
- `:51820` = WireGuard
- `:80`, `:443` = NGINX
- `:53`, `:5355` = lokale DNS-Auflösung (z. B. systemd-resolved)

## System aktualisieren

```bash
apt update && apt full-upgrade -y
```

Optional gleich Kernel-Neustart prüfen:

```bash
reboot
```

## Automatische Sicherheitsupdates

**Risiken:**
- Selten: ein Update bricht einen Dienst
- Problematisch, wenn aktiv angepasste Konfigurationsdateien genutzt (und die automatisch überschrieben werden). Möglichst User-Konfigs anlegen und nicht die Basiskonfigs bearbeiten


Sicherheitsupdates aktivieren:

```bash
dpkg-reconfigure --priority=low unattended-upgrades
```

## Swap aktivieren (wenn RAM < 2 GB)

Bei 1 GB RAM ist 1 GB Swap sinnvoll, damit bei Speicherengpässen nicht gleich Dienste crashen.

- Swap prüfen, ob vorhanden
    ```Bash
    swapon --show
    # oder
    free -h
    ```

- Falls nicht vorhanden:

    ```bash
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    # Checks
    swapon --show
    # => /etc/fstab enthält: /swapfile none swap sw 0 0
    ```


## Root-Zugriff absichern / neuen Benutzer einrichten

1. Neuen Benutzer mit sudo-Rechten:

   ```bash
   adduser deinname
   usermod -aG sudo deinname
   ```

2. SSH-Key für den neuen User hinterlegen:

    Key erzeugen (auf der Maschine, die sich später verbinden soll)

    ```bash
    ssh-keygen -t ed25519 -C "mein-vps"
    ```
    Den public key (Inhalt von `.pub`) in `authorized_keys` einfügen (auf VPS).  

    ```bash
    mkdir -p ~/.ssh
    nano ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    ```

    **Wichtig:** Login jetzt testen - es geht weiter mit der Abschaltung des root-Zugangs und Aktivierung des Key-Logins.

    **Hinweis:** Falls Putty verwendet 
    - Putty verwendet ein anderes Keyformat als OpenSSH.
    - PuTTYgen nutzen 
        => Generate
        => Save private & public key (z.B. id_rsa.ppk)
        => Public key in eine Zeile der `authorized_keys` einfügen
    - PuTTY konfigurieren
        - bei Connection -> SSH -> Auth
        - bei Private key file for authentication die .ppk-Datei auswählen
        - Verbindungsname speichern und testen
    - (vielleicht lieber mal umsteigen auf Terminal?)    


3. SSH absichern:  
    **ACHTUNG:** Reihenfolge beachten sonst sperrt man sich aus.
    Ohne User kein Userlogin. Ohne SSH Key kein passwortfreier Login.  


   * Öffne `/etc/ssh/sshd_config`:
     ```bash
     nano /etc/ssh/sshd_config
     ```
   * Ändern oder einfügen

     ```ini
     PermitRootLogin no
     PasswordAuthentication no
     AllowUsers deinUser
     ```
   * **Nur mit SSH-Key anmelden** - kein Passwort-Login!
   * Dann:

     ```bash
     systemctl restart ssh
     ```

    * SSH Port ändern  
      Zumindest sinnvoll, um die Logs sauber zu halten.  
      Grundsätzlich eigentlich nur „Security by Obscurity“.

      Beispiel: SSH auf Port 22222 ändern:

      **Nicht vergessen:** Firewall/iptables entsprechend anpassen:
      Ebenso in der VPS-Hoster-Firewall in der Weboberfläche.

        ```bash
        iptables -A INPUT -p tcp --dport 22222 -j ACCEPT

        nano /etc/ssh/sshd_config
        # Port 22222
        systemctl restart ssh
        # Prüfen, ob nun wirklich auf Port 22222 gelauscht wird
        ss -tlnp | grep 22222
        ``` 

## iptables einrichten

Debian 12 verwendet nftables als Standard-Firewall-Backend.  
Das klassische iptables ist aber weiterhin über eine Kompatiblitätsschicht verfügbar: `iptables-nft`.   
Gedenkt man zukünftig UFW verwenden zu wollen, ist das nur mit iptables kompatibel.
Daher Entscheidung für iptables, da ich mich nicht noch zusätzlich in nftables einarbeiten muss.  

Prüfen mit:
```bash
sudo update-alternatives --display iptables
sudo iptables --version
``` 
Damit iptables Regeln nach dem boot erhalten bleiben:  
```bash
sudo apt install iptables-persistent
# aktuelle regeln speichern mit:
sudo netfilter-persistent save
``` 
Wird gespeichert unter:  
`/etc/iptables/rules.v4`  
`/etc/iptables/rules.v6`  

**ACHTUNG Crowdsec**:
Das wird sich später etwas beißen. Man sollte mit `sudo netfilter-persistent save` am besten nur die eigenen Regeln speichern. Bitte beim Einrichten später von [Crowdsec](#-eigene-iptables-wiederherstellen-reboot-) beachten.

```bash
# Alte Regeln löschen?
# sudo iptables -F
# sudo iptables -X

# SSH (angepasster Port z. B. 22222) - wichtig! der nächste DROP Befehl sperrt sonst aus
sudo iptables -A INPUT -p tcp --dport 22222 -j ACCEPT

# Standard-Drop (nur explizit Erlaubtes geht durch)
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Loopback erlauben - INPUT genügt, da OUTPUT ACCEPT eingestellt ist
sudo iptables -A INPUT -i lo -j ACCEPT

# Bereits etablierte Verbindungen erlauben
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# HTTP/HTTPS (für NGINX, Certbot)
sudo iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

# WireGuard
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# Regel für VPN-Schnittstelle wg0 (z. B. Zugriff auf Dienste erlauben)
sudo iptables -A INPUT -i wg0 -j ACCEPT

# Regeln speichern
sudo netfilter-persistent save
```

**Achtung:** Hat man IPv6 aktiviert und vom Hoster eine IPv6 zugewiesen bekommen, dann muss man die Firewallrules auch für IPv6 machen. Dazu analog obige Befehle ausführen, aber `ip6tables` verwenden. Situativ prüfen, ob es für SSH oder Wireguard notwendig ist - je nachdem wie man sich verbindet. 

Test
```bash
sudo reboot
sudo iptables -L
sudo ip6tables -L
sudo systemctl status iptables.service
```

---

# WireGuard-VPN

## Allgemein

VPS ist der WireGuard-Server mit:
- Tunnelnetz: 10.200.200.0/24 (eigenes alleine genutztes "Subnetz")
- VPS-WG-IP (wg0): 10.200.200.1
- Listen-Port: 51820/udp (Port ggf. anpassen - iptables und VPS-Hoster-Firewall nicht vergessen)

IONOS blockiert **standardmäßig** alle eingehenden Ports.  
Dort muss in der Weboberfläche der Wireguard UDP Port freigegeben werden.

`net.ipv4.ip_forward = 1` ist nicht notwendig für dieses Setup, da nginx lokal läuft. 

## Installation

```Bash
sudo apt update
sudo apt install wireguard
```

## Konfiguration

### Keys erzeugen

```Bash
cd /etc/wireguard/
( umask 0077 && wg genkey | tee privatekey | wg pubkey > publickey )
```

- privatekey: VPS-Private-Key
- publickey: VPS-Public-Key (wird später auf beim Heimnetz-"Client"/Opnsense eingetragen)

Beispiel
```Bash
cat privatekey
# -> VPS_PRIVATE_KEY
cat publickey
# -> VPS_PUBLIC_KEY
```

### Datei erstellen
[`/etc/wireguard/wg0.conf`](wireguard/wg0.conf) - Konfiguration mit Public/Private Keys, AllowedIPs, Endpunkt OPNsense.  
**Optional:** einen anderen Port nutzen, als den Standardport. 

```ini 
[Interface]
Address = 10.200.200.1/24
ListenPort = 51820
PrivateKey = <VPS_PRIVATE_KEY>

[Peer]
PublicKey = <HEIMNETZ_PUBLIC_KEY>
AllowedIPs = 10.200.200.2/32,10.10.10.0/24
```

**Wichtig**  
AllowedIPs in Konfig anpassen. Das Ziel-Subnetz (bzw. IP) muss enthalten sein.  
Wireguard wurde oben unter [iptables](#iptables-einrichten) bereits konfiguriert. Falls das nicht passt, nochmal bearbeiten.

**!!Achtung!!**  
In der VPS-Hoster-Firewall den gewählten WG-Port freigeben

### Dienst aktivieren und starten

```Bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
ip a show wg0
```
**Hinweis:** wg-quick schreibt `Saveconfig=true` in die Konfig. Das muss raus, wenn man die Konfig manuell an passt. Es überschreibt ansonsten die Konfig (mit laufendem Zustand). Das macht nur Sinn wenn man die `wg set`-Befehle nutzt.  
Einfach mal nachsehen, ob man in die Situation gelaufen ist:
```Bash
sudo systemctl stop wg-quick@wg0
nano /etc/wireguard/wg0.conf
```


Weitere Befehle
```Bash
sudo systemctl status wg-quick@wg0.service
sudo wg-quick up wg0
# Loggings
sudo journalctl -xeu wg-quick@wg0.service | tail -20
# bei Fehlern
sudo wg-quick down wg0 && sudo wg-quick up wg0
```

Wireguard Status prüfen
```Bash
sudo wg show
```

Ankommende Wireguard Pakete prüfen
```Bash
sudo tcpdump -ni any port 51820
```

Verbindung prüfen
```Bash
# sofern ping auf die Heimnetz-Firewall freigegben ist
ping 10.200.200.2
# sofern ping auf diesen Host von der Heimnetz-Firwall freigegben ist
ping 10.10.10.10
# sofert Firewall-Regel für Dienst bereits hinterlegt
curl -I http://10.10.10.10:8096
traceroute 10.10.10.10
```
**Hinweis:** der ICMP (Ping) auf die Heimnetz-Opnsense ist wahrscheinlich geblockt (Firewall). 

Optionaler Portscan (sollte was nicht gehen, zuerst die AllowedIPs in Wireguard prüfen, dann natürlich die Firewallregeln)
```Bash
sudo apt install nmap
nmap -p 8096 10.10.10.10
```

### Heimnetz Wireguard (z.B. OPNSense) konfigurieren
Bzgl. Opensense: Peer-Konfiguration, Firewall/NAT-Regeln, statische Route für VPS-Subnetz siehe [opnsense.md](opnsense.md)
Ansonsten muss jeder selbst wissen, was er zuhause betreibt und wo er Wireguard installieren möchte.

Testen vom VPS aus (sobald Heimnetz konfiguriert ist)

```Bash
ping 10.200.200.1        # Tunnel IP des Heimnetz WG
ping 10.10.10.10         # z.B. emby im Subnetz
curl http://10.10.10.10:8096
```

---

# DNS

## Einträge

Wir benötigen für den Reverseproxy eine eigene (Sub)Domain je Dienst.  
Das ist natürlich abhängig davon, ob man die gesamte Domain per Wildcard auf den Server zeigen lässt oder nur bestimmte Subdomains. Stellt man beispielsweise die Wildcard auf die Server IP, muss im Grunde nichts weiter getan werden. Ansonsten sind die jeweiligen Subdomains einzustellen:  

Diese legen wir beim Domainverwalter an.  
Also einen "A"-Eintrag anlegen, gewünschte Subdomain und die IP des VPS eintragen. 
Ist IPv6 gewünscht, muss auch ein "AAAA" Eintrag auf die IPv6-VPS-Adresse gemacht werden.  

Beispiel:
- `emby.example.com`  
- `jellyseerr.example.com`  
  (es bieten sich natürlich eingängigere Subdomains an, das hier ist exemplarisch)




## Cloudflare (optional)

**Hinweis:** Das Peering der Dt. Telekom zu Cloudflare ist miserabel. Das führt zu sehr schlechten Antwortzeiten. Bei komplexen Oberflächen (emby) entsprechend zu einem sehr langsamen Seitenaufbau beim (Telekom-)Nutzer. Daher genau überlegen/testen, was man über Cloudflare proxyt bzw. tunnelt.   

Will man den Cloudflare-Proxy nutzen, oder gar den Tunnel, muss man die Domain von Cloudflare verwalten lassen.  
Dazu einfach die Domain bei Cloudflare anlegen, ggf. die vorhandenen Einträge von seinem alten Verwalter übernehmen und anschließend beim Verwalter, die Nameserver von Cloudflare eintragen.  
Ab dann kann man für einzelne oder alle Einträge den Proxy ("orangene Wolke") aktivieren.  
**Achtung:** Es ist gegen die Nutzungsbestimmungen als "Free"-Nutzer darüber zu streamen.  
Es spricht aber nichts dagegen zumindest Jellyseerr damit zu "schützen".  
Der Cloudflare Tunnel wird hier nicht behandelt, da dafür ja der VPS genutzt wird.  

Wenn man möchte, kann man die GUI von emby noch per Cloudflare proxien, und nur das Streaming vom VPS direkt liefern.  
Hier gibt es dazu eine [Anleitung](https://emby.media/community/index.php?/topic/128300-how-i-host-via-cloudflare-tunnels-but-dont-stream-video-through-it/)  



# NGINX-Reverse-Proxy

## Übersicht

* emby: über `emby.example.com`
* Jellyseerr: über `jellyseerr.example.com`
* Drop Rest (Status 444)

### Dateien
* [`/etc/nginx/nginx.conf`](nginx/nginx.conf)
* [`/etc/nginx/conf.d/default_deny.conf`](nginx/conf.d/default_deny.conf)
* [`/etc/nginx/sites-available/emby.conf`](nginx/sites-available/emby.conf)
* [`/etc/nginx/sites-available/jellyseerr.conf`](nginx/sites-available/jellyseerr.conf)
* [`/etc/nginx/snippets/dns-rebind-block.conf`](nginx/snippets/dns-rebind-block.conf)
* [`/etc/nginx/snippets/cloudflare-realip.conf`](nginx/snippets/cloudflare-realip.conf)
* [`/etc/nginx/snippets/common-headers.conf`](nginx/snippets/common-headers.conf)

### Struktur
```Bash
/etc/nginx/
├── nginx.conf                     # Hauptkonfiguration 
├── sites-enabled/
│   ├── emby.conf                  # Reverse Proxy für emby
│   ├── jellyseerr.conf            # Reverse Proxy für jellyseerr
│   ├── default_deny.conf          # Fängt alles ab, was nicht erlaubt ist
├── snippets/
│   ├── dns-rebind-block.conf      # Absicherung gegen DNS-Rebind-Angriffe
│   ├── cloudflare-realip.conf     # Real-IP für Cloudflare (Proxy aktiv)
│   ├── common-headers.conf        # Ausgelagerte Header (Wiederverwendung)
```

## Installation
```bash
sudo apt update && sudo apt install nginx certbot python3-certbot-nginx ssl-cert
```

## TLS-Zertifikate via Certbot

Am Besten direkt vor der Konfig der Subdomains die Zertifikate beantragen. Dann kann man die Konfigs wie sie sind verwenden. Da die Konfigs ([`emby.conf`](nginx/sites-available/emby.conf)/[`jellyseerr.conf`](nginx/sites-available/jellyseerr.conf)) bereits den SSL-Part beinhalten, würde ansonsten der nginx nicht ohne die vorliegenden Certs starten.


* Wildcard nicht nötig
* Für Cloudflare-Proxied Subdomains kann es eventuell nicht funktionieren. Daher entweder kurz abschalten oder einen Blick auf das certbot-plugin `python3-certbot-dns-cloudflare` werfen.

```Bash
sudo certbot --nginx -d emby.example.com
sudo certbot --nginx -d jellyseerr.example.com
```

### Automatische Verlängerung

Erneuerung wird automatisch per systemd alle 12h geprüft.  
Certbot erneuert automatisch, wenn das Zertifikat in weniger als 30 Tagen abläuft.  
Certbot über systemd-Timer ist Standard bei `apt` unter Debian.   

* **Certbot Reload-Hook**  
  ```Bash
  echo -e '#!/bin/bash\nsystemctl reload nginx' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh >/dev/null && sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
  ```

* Trockenlauf testen

  Um sicherzugehen, dass die Erneuerung funktioniert, einen Testlauf durchführen:

  ```bash
  sudo certbot renew --dry-run
  ```

  Wenn keine Fehler auftauchen, ist alles korrekt eingerichtet.


* Einstellungen prüfen

  ```bash
  certbot certificates
  systemctl list-timers | grep certbot
  systemctl status certbot.timer
  systemctl cat certbot.service
  ```

## Konfigs bereit und los (TL;DR)



```bash
sudo apt update && sudo apt install nginx certbot python3-certbot-nginx ssl-cert -y
# Konfigdateien einfügen unter
/etc/nginx/sites-available/emby.conf
/etc/nginx/sites-available/jellyseerr.conf
/etc/nginx/conf.d/default_deny.conf
/etc/nginx/snippets/dns-rebind-block.conf
/etc/nginx/snippets/cloudflare-realip.conf
/etc/nginx/snippets/common-headers.conf
# oder erzeugen
sudo nano /etc/nginx/sites-available/emby.conf
sudo nano /etc/nginx/sites-available/jellyseerr.conf
sudo nano /etc/nginx/conf.d/default_deny.conf
sudo nano /etc/nginx/snippets/dns-rebind-block.conf
sudo nano /etc/nginx/snippets/cloudflare-realip.conf
sudo nano /etc/nginx/snippets/common-headers.conf
# ggf. weitere Konfigs
```
**Wichtig:** 

* Subdomains und `proxy_pass` auf eigene Werte anpassen in [`emby.conf`](nginx/sites-available/emby.conf) und [`jellyseerr.conf`](nginx/sites-available/jellyseerr.conf) => jeweils MEHRERE Stellen - aufpassen.
* [`nginx.conf`](nginx/nginx.conf) anpassen oder einfach überschreiben. Details unter [Nginx Allgemein](#nginx-allgemein-nginxconf)



```Bash
# Aktivieren
sudo ln -s /etc/nginx/sites-available/emby.conf /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/jellyseerr.conf /etc/nginx/sites-enabled/
# 'default_deny.conf' aktivieren nur notwendig wenn nicht in conf.d/ gespeichert 
# sondern in sites-available (siehe 'includes' in nginx.conf) 
# sudo ln -s /etc/nginx/sites-available/default_deny.conf /etc/nginx/sites-enabled/

# default entfernen
sudo rm -f /etc/nginx/sites-enabled/default

# nginx conf testen & neuladen zum aktivieren
sudo nginx -t && sudo systemctl reload nginx
```

## Details & Erläuterungen

### Reverse Proxy

Nginx lädt standardmäßig  alle Konfigs aus `conf.d/` und `sites-enabled/`.

#### Hinweise

- [`cloudflare-realip.conf`](nginx/snippets/cloudflare-realip.conf)  
  Beinhaltet die Cloudflare IP-Adressen. Diese können wechseln. Daher sollten diese per Script aktualisiert werden (cron bzw systemd.timer)
  - Script unter [`scripte/update-cloudflare-ips.sh`](scripte/update-cloudflare-ips.sh)
  - als Cronjob 1x pro Woche ausführen z.B.:
      ```Bash
      sudo apt install cron
      sudo systemctl enable --now cron
      sudo chmod +x /usr/local/bin/update-cloudflare-ips.sh
      sudo crontab -e
      # folgendes einfügen =>
      0 3 * * 1 /usr/local/bin/update-cloudflare-ips.sh >/dev/null 2>&1
      ```
- [`dns-rebind-block.conf`](nginx/snippets/dns-rebind-block.conf)  
    Abfangen interner/privater IP-Zugriffe (Absicherung gegen DNS-Rebind-Angriffe)

- [`common-headers.conf`](nginx/snippets/common-headers.conf)  
    Ausgelagerte Header (zur einfacheren Wiederverwendung)

---

#### Nginx Allgemein `nginx.conf`
- `worker_connections 512` da VPS nur 1GB RAM hat (legt fest wieviele gleichzeitige Verbindungen ein einzelner Worker-Prozess handhaben darf)
    - Anzeigen, ob System genug offene Dateideskriptoren erlaubt - falls man die `worker_connections` beispielsweise auf 2048 erhöht.
        ```bash
        ulimit -n
        # => 1024
        # ggf. dann erhöhen via systemd oder evtl /etc/security/limits.conf
        ```
    - sollten viele gleichzeitige Streams oder Requests erwartet werden, `worker_connections` auf beispielsweise 1024 erhöhen - aber bei einem RAM-Limit von 1 GB ist 512 gut gewählt.
- `sendfile off` da Nginx als reiner Reverse Proxy dient
- `gzip` Settings
- `tcp_nodelay`: Beschleunigt Antwort bei kleinen Daten -> gut für alle Dienste
- proxy timeouts
- `ssl_protocols TLSv1.2 TLSv1.3` auf als sicher geltende Versionen beschränkt
- weiteres siehe Kommentare in [`nginx.conf`](nginx/nginx.conf)

---

#### DNS-Rebind-Schutz

Der Schutz verhindert, dass ein Client (z. B. via manipuliertem DNS) auf **interne IP-Adressen oder `localhost`** zugreift - **über den öffentlichen Nginx**, z. B.:

* `Host: 127.0.0.1`
* `Host: localhost`
* `Host: 10.0.0.1`
* `Host: 192.168.1.1`

-> Das könnte Angreifern ermöglichen, lokale Dienste über den Nginx zu erreichen, wenn der Proxy z. B. falsch konfiguriert ist oder interne APIs ohne Authentifizierung existieren.

**Mögliche Probleme durch DNS-Rebind-Angriffe**

* Zugriff auf **interne Admin-Dienste** (z. B. `localhost:9000`, `127.0.0.1:22`, Emby ohne Auth)
* Umgehung von Same-Origin-Sicherheitsmechanismen (besonders gefährlich in Kombination mit JavaScript im Browser)
* SSRF-artige Angriffe (Server Side Request Forgery)


**Empfehlung**: **in alle produktiven `server {}`-Blöcke**, die öffentlich erreichbar sind.  
```nginx
include snippets/dns-rebind-block.conf;
```

---

### 'Silent Drop' alle ungültigen Domains

- [`/etc/nginx/conf.d/default_deny.conf`](nginx/conf.d/default_deny.conf)
- Der `default_server` behandelt nicht explizit definierte Domains und antwortet mit `return 444` (bzw. verbindungslose Drop-Antwort, bei Nginx bedeutet das: keine Antwort = stilles Drop).
- Die `default_server`-Direktive gilt für alle Listener auf `0.0.0.0:80` und `:443`, die keinen besser passenden server_name finden.
- Reihenfolge egal - wichtig ist nur, dass kein anderer Block `default_server` beansprucht.

#### Vorteile
- Unerwartete Zugriffe (z. B. durch Scans, Wildcard-Domains oder Fehler) werden sofort gedroppt.
- Kein `400 Bad Request` mehr im Log - stattdessen still und leise ignoriert.

--- 

#### Testen
- Zugriff via undefinierter Subdomain
- Zugriff via VPS IP
  ```bash
  curl -I http://<VPS-IP>
  # => curl: (52) Empty reply from server
  curl -kI https://<VPS-IP>
  # => curl: (92) HTTP/2 stream 1 was not closed cleanly: PROTOCOL_ERROR (err 1)
  ```

---

# Crowdsec

Ursprünglich habe ich mich an fail2ban versucht. Erste Konfigs und Dokumentation (z.B. Jellyseerr und Cloudflare) sind hier zu finden:  
[README Fail2ban](fail2ban/README.md).  
Ich habe mich zwischenzeitlich aber nun für Crowdsec entschieden.  
Allerdings muss ich sagen, sind mir die Standardszenarios viel zu "locker". Hier lohnt sich bzgl. `capacity` und `leakspeed` Anpassungen zu machen. Um das sauber zu machen, muss man aber eigene Szenarios anlegen, die man von den "Originalen" kopiert. Keine schöne Lösung.

Ich würde Crowdsec tatsächlich erst jetzt am Schluss installieren, da dann automatisch empfohlene Module installiert werden.


## Crowdsec installieren

Als Bouncer wird iptables verwendet. Entscheidung für iptables wurde unter [iptables einrichten](#iptables-einrichten) getroffen. Parallel sollte man nft und ipt wohl nicht betreiben.

```bash
# Paketquellen hinzufügen
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash
# CrowdSec + iptables-Bouncer installieren
sudo apt install crowdsec
sudo apt install crowdsec-firewall-bouncer-iptables

# Crowdsec ergänzen
sudo cscli collections install crowdsecurity/iptables
sudo cscli postoverflows install crowdsecurity/ipv6_to_range
# Optional sudo cscli postoverflows install crowdsecurity/cdn-whitelist

# Vollständigskeitshalber (ist wahrscheinlich schon automatisch drauf):
sudo cscli parsers install crowdsecurity/geoip-enrich
sudo cscli collections install crowdsecurity/base-http-scenarios
sudo cscli collections install crowdsecurity/http-cve
sudo cscli collections install crowdsecurity/linux
sudo cscli collections install crowdsecurity/nginx
sudo cscli collections install crowdsecurity/sshd

sudo systemctl reload crowdsec

```

Bei mir war `crowdsecurity/iptables` nicht standardmäßig installiert. Das wird wahrscheinlich aber auch nicht getriggert, da die VPS-Hoster-Firewall alles schluckt.   
[Konfiguration](https://app.crowdsec.net/hub/author/crowdsecurity/collections/iptables) muss noch für `Acquisition` gemacht werden: 
```bash
nano /etc/crowdsec/acquis.d/journalctl.yaml
```
Das einfügen:  
```ini
source: journalctl
journalctl_filter:
 - "-k"
labels:
  type: syslog
```

## !!! Eigene iptables wiederherstellen (reboot) !!!
Mit `netfilter-persistent save` sollte man nur die eigenen Regeln speichern. Crowdsec kümmert sich um sein Zeug selbst.    
Ansonsten führt das zu einer **Fehlerquelle:** Crowdsec-Bouncer läuft zum Zeitpunkt des `netfilter-persistent` noch nicht (systemd Startreihenfolge), daher werden gar keine Regeln wiederhergestellt => Fehler weil Bouncer nicht da.  
Oder aber die "damals" mit `netfilter-persistent` gespeicherten Daten sind für Crowdsec vielleicht schon veraltet.
```bash
sudo systemctl stop crowdsec-firewall-bouncer
sudo netfilter-persistent save
sudo systemctl start crowdsec-firewall-bouncer
``` 
Nun ist es aber wie immer nicht so leicht... beim Reboot startet Crowdsec (evtl.) zuerst und danach `netfilter-persistent`. Also verschwinden dann die Crowdsec Einträge.  
Lösung - die Startreihenfolge beeinflussen:
```bash
sudo mkdir -p /etc/systemd/system/crowdsec-firewall-bouncer.service.d
sudo nano /etc/systemd/system/crowdsec-firewall-bouncer.service.d/override.conf
``` 
=>
```ini
[Unit]
After=netfilter-persistent.service
Requires=netfilter-persistent.service
```
Ich mache dies bewusst nicht in der vorhandenen `/etc/systemd/system/crowdsec-firewall-bouncer.service`, da dies bei Neuinstallation/Update von Crowdsec wieder überschrieben werden könnte.


Aber Achtung: Vielleicht macht es "andersherum" noch mehr Sinn? Also mit `netfilter-persistent save` auch Crowdsec mit abspeichern und dafür Crowdsec zuerst starten lassen. Man dürfte das aber nicht vergessen, wenn man weitere Crowdsec Listen hinzufügt. Ich weiß es noch nicht. Irgendwas muss man hier jedenfalls tun und ich habe mich zunächst für die obige Methode entschieden.



## Bannzeit anpassen und dynamisch erhöhen

`/etc/crowdsec/profiles.yaml`

Expotentielle Bannzeit mit einer Formel einfügen. Grundzeit 24 Stunden (statt der Standard-4h). Nach Bedarf kann man es auch Linear machen. Je nach Geschmack.  

Unter `name: default_ip_remediation` und `name: default_range_remediation` einfügen.
```ini
decisions:
 - type: ban
   duration: 24h # nach Geschmack anpassen

duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) * GetDecisionsCount(Alert.GetValue()) + 1) * 24) # Formel einfügen
```
```bash
sudo systemctl restart crowdsec
```

Führt beispielsweise zu:
```ini
(0*0 + 1)*24 =  24h (1d)   # Erster Ban
(1*1 + 1)*24 =  48h (2d)   # etc.
(2*2 + 1)*24 = 120h (5d) 
(3*3 + 1)*24 = 240h (10d)
(4*4 + 1)*24 = 408h (17d)
(5*5 + 1)*24 = 624h (26d)
(6*6 + 1)*24 = 888h (37d)
```

### Dienststatus prüfen
```bash
# Metriken anzeigen
sudo cscli metrics
# Alerts anzeigen
sudo cscli alerts list
# Aktive IP-Bans anzeigen
sudo cscli decisions list
# Alle aktiven Konfigurationen anzeigen
sudo cscli hub list
# Aktive Collections anzeigen
sudo cscli collections list
# Aktive Bouncer anzeigen
sudo cscli bouncers list
```

### Optional: Mit Crowdsec Console verbinden (Weboberfläche): 
Bei [Crowdsec](https://app.crowdsec.net/) anmelden, dann wird einem ein Befehl wie dieser angezeigt:  
`sudo cscli console enroll -e context casdkjf45352ajkl24kj5Cyxs`


### Optional: Automatische Aktualisierungen  
Hat man an den installierten Inhalten keine manuellen Änderungen gemacht, kann man das Upgrade noch automatisieren.  

Beispiel:  
```bash
sudo crontab -e
# das einfügen =>
0 2 * * * /usr/bin/cscli hub update && /usr/bin/cscli hub upgrade > /dev/null 2>&1
```
`cscli hub update`: aktualisiert die Hub-Liste.  
`cscli hub upgrade`: bringt installierte Parsers/Scenarios/Collections auf den neuesten Stand.

## Ausgesperrt?  
Login über Hoster-Web-Konsole
```bash
cscli decisions delete -i de.in.e.ip
```
Bzgl. "aussperren" auch einfach mal die `Simulate` Funktionalität von Crowdsec ansehen.  


## Optional: Benachrichtigungen einrichten  

`/etc/crowdsec/profiles.yaml`

Todo

---

# Todo: Monitoring einrichten

Für Übersicht:

* `htop`, `ncdu`, `vnstat`
* oder systemübergreifend: Netdata, Prometheus, Monit

Noch nicht behandelt/dokumentiert.

---