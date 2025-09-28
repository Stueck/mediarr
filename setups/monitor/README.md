sudo iptables -L -n -v --line-numbers
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
mkdir -p /etc/cloudflare
sudo chmod 700 /etc/cloudflare/
touch /etc/cloudflare/up.test.de.ini
chmod 600 /etc/cloudflare/up.test.de.ini
sudo nano /etc/cloudflare/up.test.de.ini
sudo certbot certonly   --dns-cloudflare   --dns-cloudflare-credentials /etc/cloudflare/up.test.de.ini   --dns-cloudflare-propagation-seconds 30   -d up.test.de
sudo certbot renew --dry-run
sudo nano /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
sudo nano /etc/nginx/snippets/cloudflare-realip.conf
sudo nano /usr/local/bin/update-cloudflare-ips.sh
sudo chmod +x /usr/local/bin/update-cloudflare-ips.sh
sudo apt install cron
sudo systemctl enable --now cron
sudo crontab -e
sudo nano /etc/nginx/snippets/dns-rebind-block.conf
sudo nano /etc/nginx/sites-available/kuma.conf
sudo nano /etc/nginx/nginx.conf
sudo rm /etc/nginx/sites-enabled/default
sudo apt install ssl-cert
sudo nano /etc/nginx/conf.d/default-deny.conf
sudo nginx -t && sudo systemctl reload nginx