#!/bin/bash
set -e

#########################################
# DOCKER + FIREWALL SETUP (sudo version)
#########################################

# --- 1. Install Docker (official repository) ---
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian \
$(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 2. Add this user to docker group (no usermod on root directly) ---
sudo usermod -aG docker "$USER"

# --- 3. Create default docker network (using sudo for first docker run) ---
sudo docker network create nginx-proxy || true

# --- 4. Add UFW-Docker rules ---
UFW_RULES=/etc/ufw/after.rules
if ! sudo grep -q "BEGIN UFW AND DOCKER" $UFW_RULES; then
sudo tee -a $UFW_RULES >/dev/null << 'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
-A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j DROP -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

-A DOCKER-USER -j RETURN
COMMIT
# END UFW AND DOCKER
EOF
fi

sudo ufw reload

# --- 5. Allow HTTP & HTTPS ---
sudo ufw route allow proto tcp from any to any port 80
sudo ufw route allow proto tcp from any to any port 443

echo "? Docker installation and firewall setup complete."
echo "You must log out and log back in to use Docker without sudo."
echo
echo "Rebooting in 3 seconds..."
sleep 3
sudo reboot
