#!/bin/bash

# Define VPS IP and Domain Variables
VPS_IP="YOUR_VPS_IP"  # Replace with your actual VPS IP
DOMAIN="YOUR_SUBDOMAIN"  # Replace with your actual domain or subdomain

echo "Updating system and installing required packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y bind9 bind9utils bind9-doc net-tools iptables-persistent dnsutils

echo "Setting up BIND9 configuration..."
cat <<EOL | sudo tee /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";

    allow-query { any; };  
    recursion yes;

    forwarders {
        94.140.14.14;   # AdGuard DNS (Primary)
        94.140.15.15;   # AdGuard DNS (Secondary)
        45.90.28.0;     # NextDNS (Primary)
        45.90.30.0;     # NextDNS (Secondary)
        185.228.168.168;# Blocklist DNS (Primary)
        185.228.169.169;# Blocklist DNS (Secondary)
        208.67.222.123; # OpenDNS FamilyShield (Primary)
        208.67.220.123; # OpenDNS FamilyShield (Secondary)
    };

    dnssec-validation no;
    auth-nxdomain no;     
    listen-on { any; };
    listen-on-v6 { any; };
};
EOL

cat <<EOL | sudo tee -a /etc/bind/named.conf.local
zone "$DOMAIN" {
    type master;
    file "/etc/bind/zones/db.$DOMAIN";
};
EOL

echo "Creating zone file for $DOMAIN..."
sudo mkdir -p /etc/bind/zones
cat <<EOL | sudo tee /etc/bind/zones/db.$DOMAIN
\$TTL 86400
@    IN SOA   ns1.$DOMAIN. admin.$DOMAIN. (
             2024112601 ; Serial
             3600       ; Refresh
             1800       ; Retry
             1209600    ; Expire
             86400 )    ; Minimum TTL

@    IN NS    ns1.$DOMAIN.
ns1.$DOMAIN.    IN A    $VPS_IP   ; DNS server IP address
EOL

sudo chown -R bind:bind /etc/bind/zones
sudo chmod 644 /etc/bind/zones/db.$DOMAIN

echo "Restarting BIND9 service..."
sudo systemctl restart bind9

echo "Enabling BIND9 service to start on boot..."
sudo systemctl enable bind9

echo "Setting up iptables rules..."
sudo iptables -F
sudo iptables -X
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo netfilter-persistent save
sudo netfilter-persistent reload

echo "Checking BIND9 service status..."
sudo systemctl status bind9

echo "BIND9 DNS server setup completed for $DOMAIN at IP $VPS_IP."
echo "iptables rules have been configured. Make sure to update your Cloudflare DNS records accordingly."
