#!/bin/bash
set -e

#########################################
# VPS BASE SETUP
# Creates "debian" user, sets SSH keys,
# configures sudo, disables password auth,
# and enables firewall.
#########################################

# --- 1. Create user "debian" without password ---
if ! id -u debian >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" debian
fi

echo "? Now set a password for user 'debian':"
passwd debian

# --- 2. Install basic packages ---
apt update
apt install -y sudo ufw curl ca-certificates gnupg lsb-release

# --- 3. Add user to sudo ---
usermod -aG sudo debian

# --- 4. Disable password prompt for sudo ---
echo "debian ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/010_debian_nopasswd
chmod 440 /etc/sudoers.d/010_debian_nopasswd

# --- 5. Setup SSH key login for "debian" ---
sudo -u debian mkdir -p /home/debian/.ssh
sudo -u debian chmod 700 /home/debian/.ssh

# Placeholder SSH public key
cat << 'EOF' > /home/debian/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC4KTGHISS2+/8BiNrNQO4MmIwp5GFRQg7iQzsjTqCqmmJI5ioS0ldC9KbrK3pokRXSYlnytVOVMUJ5Y29KoG7tOahtl07ZcfE5BerBtZt41ZTDcAVxLlA+MqcuhmVZM1bA3+AoSOGFWikKKW9rfqCFMFcpIlpTtLyxSKma2hCuMleeVQCK4VG8voIA2fnHvqdZywVyBdPiMMXuI8lpWkK4EKE9sKr8RwC6+/4yNltICDsm1ZBWbUiHBpmuiQJp4rz+FcCpq/UJ43xJXFguLzAGjLfPquEUqJu5jIQJowZEviJqfD9uR9P7K7LoFkrAel9szGjxXKo1vZ9YxkyQJc2NNFawhK98rlOraJuiVV3RkIKBODlD5zukQ5Gw/+BFsu24rLQYHPQXgOOMSun8W7nu50ye28pZoU44cIifHCbaOfad7kMt/azGt1mBUcR1bO6Tj3+IWMQiUK2P55Thi9elDckrKtdKHl7JzVQ5ieeBxaHm2zZK7kRLap5nstOLgk0= user@local
EOF

chmod 600 /home/debian/.ssh/authorized_keys
chown -R debian:debian /home/debian/.ssh

# --- 6. Harden SSH configuration ---
SSHD_CONFIG="/etc/ssh/sshd_config"

# Disable password auth
if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
else
  echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
fi

# Disable challenge-response
if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
  sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
else
  echo "ChallengeResponseAuthentication no" >> "$SSHD_CONFIG"
fi

# Disable root password login
if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"
else
  echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
fi

systemctl reload sshd || systemctl restart ssh

# --- 7. Configure UFW ---
ufw allow OpenSSH
ufw --force enable

echo "? VPS base setup complete!"
echo
echo "Rebooting in 3 seconds..."
sleep 3
reboot