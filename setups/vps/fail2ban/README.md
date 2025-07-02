- [Fail2Ban](#fail2ban)
  - [Grundkonfiguration](#grundkonfiguration)
  - [Jellyseerr (mit Cloudflare API)](#jellyseerr-mit-cloudflare-api)
    - [Cloudflare Vorbereitung](#cloudflare-vorbereitung)
      - [Token Name](#token-name)
      - [Permissions (Berechtigungen)](#permissions-berechtigungen)
      - [Zone Resources](#zone-resources)
    - [Fail2ban Konfig](#fail2ban-konfig)


# Fail2Ban

## Grundkonfiguration

Diese Grundkonfig ist nur sehr rudimentär beschrieben, da ich mich während des VPS-Aufbaus dann doch für crowdsec entschieden hatte.  
Interessant könnte dennoch die Jellyseerr/Cloudflare Konfig sein.

**Fail2ban installieren**

```bash
sudo apt update && sudo apt install -y fail2ban
```

**Dienststatus prüfen**:
```bash
sudo systemctl status fail2ban
```

**Basiskonfiguration**:

`jail.local` erstellen. Hier werden die Anpassungen gemacht, da die originale `jail.conf` bei Updates überschrieben werden kann:

```bash
# Default verwenden
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Debian Installationen setzen auf systemd-journald. Fail2Ban muss das korrekte Backend nutzen.  
`backend = system`

Für Debian ist sshd bereits standardmäßig aktiviert.
Siehe
`/etc/fail2ban/jail.d/defaults-debian.conf`

In den Konfigs sollten einige Parameter angepasst werden
z.B. 
- backend
- findtime
- bantime
- ...

```bash
sudo systemctl start fail2ban
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
# Live Log anzeigen
sudo tail -f /var/log/fail2ban.log
# Konfiguration testen
sudo fail2ban-server --test
```

**Log prüfen bei Fehler**:

```bash
sudo journalctl -xe | grep fail2ban
```

**Ausgesperrt?**  
Login über Hoster-Web-Konsole
```bash
sudo systemctl stop fail2ban

sudo fail2ban-client unban --all
# oder
sudo fail2ban-client set sshd unbanip MEINE-IP
```

## Jellyseerr (mit Cloudflare API)

Fail2ban bannt damit direkt zusätzlich auf Cloudflare, so kommen auf proxied Subdomains diese Anfragen gar nicht mehr durch.  
Will man Cloudflare Bans nicht verwenden, einfach den Cloudflare Teil überspringen und die cloudflare-token Action aus der Konfig löschen
[`/etc/fail2ban/jail.d/jellyseerr-cloudflare.local`](jail.d/jellyseerr-cloudflare.local).  

### Cloudflare Vorbereitung

Custom Token im Cloudflare Dashboard erstellen (mit eingeschränkten Rechten):  
https://dash.cloudflare.com/profile/api-tokens

#### Token Name
* **Token name:** `fail2ban-block` (frei wählbar)  

#### Permissions (Berechtigungen)

Minimalberechtigungen einstellen.

Wähle:
* Zone
* Firewall Services
* Edit

#### Zone Resources
Wähle:
* Include
* Specific zone
* Domain (`example.com`) aus der Liste

**Cloudflare Zone ID herausfinden**  
Im Dashboard in der Zone (example.com) → Overview → Rechte Seite unten: Zone ID.

**Ban in Cloudflare Dashboard prüfen**  
In Zone (Domain) → Security → WAF → Tools 
Einträge mit z. B. Fail2Ban_jellyseerr

### Fail2ban Konfig

Filter für die Jellyseerr nginx logs erstellen:
[`/etc/fail2ban/filter.d/jellyseerr.conf`](filter.d/jellyseerr.conf)

Fail2ban hat bereits eine fertige `action`
[`/etc/fail2ban/action.d/cloudflare-token.conf`](action.d/cloudflare-token.conf)  
https://github.com/fail2ban/fail2ban/blob/master/config/action.d/cloudflare-token.conf

Diese Action verwendet man in seiner Jail.
Siehe [`/etc/fail2ban/jail.d/jellyseerr-cloudflare.local`](jail.d/jellyseerr-cloudflare.local).  
Hier die Cloudflare Zone ID und das CustomToken anpassen. 

```bash
sudo fail2ban-client reload
# bzw.
sudo systemctl restart fail2ban

sudo fail2ban-client status jellyseerr

# Testweise IP bannen (manuell)
sudo fail2ban-client set jellyseerr banip 1.2.3.4
# ggf. Log prüfen
sudo tail -n 100 /var/log/fail2ban.log
# Ban in Cloudflare kontrollieren: In Zone (Domain) → Security → WAF → Tools 
# unban
sudo fail2ban-client set jellyseerr unbanip 1.2.3.4
# Unban in Cloudflare kontrollieren: In Zone (Domain) → Security → WAF → Tools 

```







