#!/bin/bash

# Zielpfad für NGINX-Konfiguration
OUTPUT_FILE="/etc/nginx/snippets/cloudflare-realip.conf"

# IPv4- und IPv6-Adressen von Cloudflare abrufen
CLOUDFLARE_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CLOUDFLARE_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

{
    echo "# Automatisch generiert: Cloudflare Real-IP Konfiguration"
    echo "real_ip_recursive on;"
    echo "real_ip_header CF-Connecting-IP;"
    echo ""
    for ip in $CLOUDFLARE_IPV4; do
        echo "set_real_ip_from $ip;"
    done
    for ip in $CLOUDFLARE_IPV6; do
        echo "set_real_ip_from $ip;"
    done
    
} > "$OUTPUT_FILE"

# Konfiguration testen und reload durchführen, wenn erfolgreich
if nginx -t; then
    systemctl reload nginx
else
    echo "Fehler in NGINX-Konfiguration, kein Reload durchgeführt"
fi
