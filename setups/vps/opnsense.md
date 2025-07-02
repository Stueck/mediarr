# Opnsense Wireguard Konfiguration

## Inhalt

- [Opnsense Wireguard Konfiguration](#opnsense-wireguard-konfiguration)
  - [Inhalt](#inhalt)
  - [Vorausetzung](#vorausetzung)
  - [Peers](#peers)
  - [Instance](#instance)
  - [Interface](#interface)
  - [Firewall](#firewall)
    - [NAT](#nat)
    - [Rules](#rules)
  - [Verbindung aktivieren \& testen](#verbindung-aktivieren--testen)
  - [Debugging](#debugging)
    - [Ist der VPS-Server online und lauscht?](#ist-der-vps-server-online-und-lauscht)
    - [Firewall auf dem VPS: ist UDP/51820 offen?](#firewall-auf-dem-vps-ist-udp51820-offen)
    - [VPS Public IP korrekt?](#vps-public-ip-korrekt)
    - [Passen die Keys?](#passen-die-keys)
    - [AllowedIPs korrekt?](#allowedips-korrekt)
    - [Tunnel-Adressen korrekt gesetzt?](#tunnel-adressen-korrekt-gesetzt)



## Vorausetzung

Der gewählte Port ist frei (kein anderer WG läuft darauf z.B.)
```Bash
sudo ss -ulpn | grep 51820
```
oder
```Bash
sudo lsof -i UDP:51820
```

## Peers

`VPN -> WireGuard -> Peers -> Add`

- Name: vps-wg-peer
- Public-Key: from VPS
- Allowed IPs: 10.200.200.1/32 (from VPS wg0.conf)
- Endpoint address: VPS IP
- Endpoint port: 51820

## Instance

`VPN -> WireGuard -> Instances -> Add`

- Name: vps-wg-client
- Public-Key: Generate new Keypair
- Listen Port: 51820
- Tunnel address: 10.200.200.2/32
- Peers: vps-wg-peer

-> Public Key kopieren, wird im VPS gebraucht.


## Interface

`Interfaces -> Assignments`

- Assign a new Interface
- Device: select the wgX-Wireguard Interface
- Description: WGIONOS

## Firewall

### NAT
Falls Modus „Hybrid Outbound NAT rule generation“ genutzt:

`Firewall -> NAT -> Outbound -> Add`

- Interface: WAN
- Source: 10.200.200.0/24 (WGIONOS net)
- Destionation: Any
- Log: yes
- Description: NAT for VPS Tunnel
- Translation / Target: Interface address (WAN)
- Haken bei „NAT Reflection“ kann ausbleiben

-> Ziel: der Rückweg zu Emby funktioniert durch NAT korrekt

### Rules

`Firewall -> Rules -> WGIONOS -> Add`

**Rule 1**
- Action: Pass
- (Interface: WGIONOS)
- Protocol: TCP
- Source: 10.200.200.1/32
- Destination: 10.10.20.20/32 (emby IP in DMZ)
- Port: 8096
- Description: Allow VPS to Emby

**Rule 2**
- Action: Pass
- (Interface: WGIONOS)
- Protocol: TCP
- Source: 10.200.200.1/32
- Destination: 10.10.20.21/32 (Jellyseerr IP in DMZ)
- Port: 8096
- Description: Allow VPS to Jellyseerr

**Rule 3**
- Action: BLOCK
- (Interface: WGIONOS)
- Protocol: any
- Source: WGIONOS net
- Destination: any
- Log: yes
- Description: Default block rest


## Verbindung aktivieren & testen
`VPN -> WireGuard -> Status`

Status zeigt: 
  - Handshake received
  - Transfer RX/TX steigt


## Debugging

### Ist der VPS-Server online und lauscht?

Auf dem **VPS** ausführen:
```bash
sudo wg show
sudo netstat -ulnp | grep 51820
```
-> Das sollte zeigen:

* Interface `wg0` ist aktiv
* Port 51820 lauscht auf UDP
* Peers vorhanden (AllowedIPs usw.)

---

### Firewall auf dem VPS: ist UDP/51820 offen?

IONOS blockiert **standardmäßig** alle eingehenden Ports.  Dort muss in der Weboberfläche der WG UDP Port freigegeben werden.

Lokale Firewall prüfen:

```bash
sudo iptables -L -n -v
```

Ggf. öffnen:

```bash
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

---

### VPS Public IP korrekt?

`VPN -> WireGuard -> Peers` -> dort muss stehen:

```text
Endpoint: <VPS_IP_oder_Domain>:51820
```

Test auf OPNsense:

```bash
ping <VPS_IP>
nc -vzu <VPS_IP> 51820
```

-> Wenn das scheitert, kommt der Client nicht durch.

---

### Passen die Keys?

* OPNsense: `Private Key` = eigenständig
  -> **den Public Key im VPS eingeben**

* VPS: `Private Key` = eigenständig
  -> **den Public Key in OPNsense bei Peer eingeben**

-> Jeder Peer kennt nur den Public Key des Gegenübers.

---

### AllowedIPs korrekt?

**Auf dem VPS:**

```ini
[Peer]
PublicKey = <OPNSENSE_PUBLIC_KEY>
AllowedIPs = 10.200.200.2/32,10.10.20.0/24
```

**Auf OPNsense Peer:**

```
AllowedIPs = 10.200.200.1/32
```

**Nie 0.0.0.0/0** verwenden, es sei denn man will einen Full-Tunnel.

---

### Tunnel-Adressen korrekt gesetzt?

* VPS Interface: `10.200.200.1/24`
* OPNsense Instance: `10.200.200.2/32`

Darauf achten, dass der Server **ein /24** hat, der Client **ein /32**

---

