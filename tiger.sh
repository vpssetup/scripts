#!/bin/bash
set -e

# === Debian 12 + LXDE + TightVNC (localhost-only) ===
# Lightweight desktop access via SSH tunnel
# Works even when user is NOT root
# Ideal for 512 MB VPS
# ----------------------------------------------------

read -p "Enter the username to configure (default: debian): " VNC_USER
VNC_USER=${VNC_USER:-debian}

VNC_HOME="/home/$VNC_USER"
SERVICE_FILE="/etc/systemd/system/tightvnc.service"

echo "? Using username: $VNC_USER"
sleep 1

echo "Updating system..."
sudo apt update -y && sudo apt upgrade -y

echo "Installing LXDE and essentials..."
sudo apt install -y lxde-core lxterminal gvfs dbus-x11 xorg

echo "Installing TightVNC server..."
sudo apt install -y tightvncserver

echo "Installing lightweight browser (optional)..."
sudo apt install -y chromium

# --- Create .vnc directory for user ---
echo "Preparing VNC directories..."
sudo -u "$VNC_USER" mkdir -p "$VNC_HOME/.vnc"
sudo chown -R "$VNC_USER":"$VNC_USER" "$VNC_HOME/.vnc"

# --- Set VNC password interactively ---
echo "You?ll now set a VNC password for $VNC_USER:"
sudo -u "$VNC_USER" tightvncserver :1
sudo -u "$VNC_USER" tightvncserver -kill :1

# --- Create xstartup for LXDE ---
echo "Creating LXDE startup file..."
sudo tee "$VNC_HOME/.vnc/xstartup" > /dev/null <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startlxde &
EOF

sudo chmod +x "$VNC_HOME/.vnc/xstartup"
sudo chown "$VNC_USER":"$VNC_USER" "$VNC_HOME/.vnc/xstartup"

# --- Create systemd service ---
echo "Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=TightVNC server for $VNC_USER
After=syslog.target network.target

[Service]
Type=forking
User=$VNC_USER
PAMName=login
PIDFile=$VNC_HOME/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/tightvncserver -kill :1
ExecStart=/usr/bin/tightvncserver :1 -localhost -geometry 1024x768 -depth 16 -dpi 96
ExecStop=/usr/bin/tightvncserver -kill :1
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable tightvnc.service
sudo systemctl start tightvnc.service

echo
echo "? Setup complete!"
echo "--------------------------------------"
echo "Access your desktop securely via SSH:"
echo "  ssh -L 5901:localhost:5901 $VNC_USER@your-vps-ip"
echo "Then connect with a VNC client to:"
echo "  localhost:5901"
echo
echo "Rebooting in 3 seconds..."
sleep 3
sudo reboot