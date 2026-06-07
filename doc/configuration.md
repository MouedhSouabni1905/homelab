# Caddy
- Install caddy: https://caddyserver.com/docs/install#debian-ubuntu-raspbian
- Write this configuration to `/etc/caddy/Caddyfile`:
```
domain.com {
	# Set this path to your site's directory.
	root * /usr/share/caddy

	# Enable the static file server.
	file_server

	# Another common task is to set up a reverse proxy:
	# reverse_proxy localhost:8080

	# Or serve a PHP site through php-fpm:
	# php_fastcgi localhost:9000
}

# Refer to the Caddy docs for more information:
# https://caddyserver.com/docs/caddyfile

vpn.domain.com {
	reverse_proxy :8080
}
```

# VPN
- Install headscale: https://headscale.net/stable/setup/install/official/ (not the container)
- Point your domain to the server
- Copy the contents of the `/configs/headscale/config.yaml` file from the repo to `/etc/headscale/config.yaml` (modify hostnames and dns records accordingly)
- Add the following configuration to `/etc/headscale/policy.json`:
```
{
  "tagOwners": {
    "tag:server": ["mimo@"]
  },
}
```
- Restart the headscale service
- Keep in mind this is the route to the headscale server, NOT a web UI of the server
- Create at least one user, which will be used for the tagged devices, basically an admin (doesn't have to be named "admin")
- Install tailscale on the client nodes and run `tailscale up --login-server <YOUR_HEADSCALE_URL>`
- In the server, run `tailscale up --login-server <YOUR_HEADSCALE_URL> --advertise-tags tag:server`
- Follow the instructions to register the node under the right username
- Congratulations, now you can access the file server at samba.vpn.local from anywhere in the world by connecting to the vpn

# Aliasvault

- You need an MX record with the same domain name as your email domain, meaning an MX record with content `domain.com` pointing to `domain.com` and then configure aliasvault (through the install script) to use that `domain.com` as the email domain, like this:
```
root@shinsengumi:~/services/aliasvault# ./install.sh configure-email
==================================================
    _    _ _           __      __         _ _
   / \  | (_) __ _ ___ \ \    / /_ _ _   _| | |_
  / _ \ | | |/ _` / __| \ \/\/ / _` | | | | | __|
 / ___ \| | | (_| \__ \  \  / / (_| | |_| | | |_
/_/   \_\_|_|\__,_|___/   \/  \__,__|\__,_|_|\__|

==================================================
+++ Email Server Configuration +++

About Email Server:
AliasVault includes a built-in email server for handling virtual email addresses.
When enabled, it can receive emails for one or more configured domains.
Each domain must have an MX DNS record pointing to this server's hostname.

Current Configuration:
Email Server Status: Enabled
Active Domains: lubbarbarek.com

Email Server Options:
1) Enable email server / Update domains
2) Disable email server
3) Cancel

Select an option [1-3]: 1

Enter domain(s) for email server
For multiple domains, separate with commas (e.g. domain1.com,domain2.com)
IMPORTANT: Each domain must have an MX record in DNS pointing to this server.
Domains: domain.com

You entered the following domains:
  - domain.com

Are these domains correct? (y/n): y
```

# Samba (server)

- After installing samba, add this configuration to `/etc/samba/smb.conf`:
```
[global]
   workgroup = WORKGROUP
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   security = user
   obey pam restrictions = yes
   passdb backend = tdbsam
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = no
[printers]
   comment = All Printers
   browseable = no
   path = /var/tmp
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700
[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
[users]
   comment = Personal User Directories
   path = /srv/samba/users/
   browseable = yes
   guest ok = no
   read only = no
   writable = yes
   create mask = 0644
   directory mask = 0755
   valid users = mimo
#  valid users = mimo, user2, user3, ...
```
- Add this script to `/scripts/smb_user_create`:
```
#!/usr/bin/env bash
set -euo pipefail

SMB_CONF="/etc/samba/smb.conf"
BASE_DIR="/srv/samba/users"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <username>"
  echo "Description: Script that creates a user and adds his directory and adjusts directory permissions"
  exit 1
fi
PASSWORD="$(cat /scripts/.smbpasswd)"
USER_NAME="$1"
SHARE_NAME="$USER_NAME"
USER_DIR="${BASE_DIR}/${USER_NAME}"

if ! id "$USER_NAME" >/dev/null 2>&1; then
  echo "User '$USER_NAME' does not exist. Creating user..."
  useradd -m -s /bin/bash "$USER_NAME"
  echo "$USER_NAME:default" | chpasswd
  printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" | smbpasswd -s -a "$USER_NAME"
  smbpasswd -e "$USER_NAME"
  echo "User $USER_NAME created with password '$PASSWORD'"
fi
sudo mkdir -p "$USER_DIR"
sudo chown "$USER_NAME:$USER_NAME" "$USER_DIR"
sudo chmod 700 "$USER_DIR"
sudo usermod -aG sambausers "$USER_NAME"
echo "Created user"
echo "!!! Don't forget to add the user to the smb config's valid users !!!"
```
- Then generate a random password with `` and put it in `/scripts/.smbpasswd`
- Then run:
```
sudo groupadd sambausers
sudo mkdir -p /srv/samba/users
sudo systemctl enable smbd
sudo systemctl start smbd
```
- Note: yes the password will be the same for every user, because I do not want to deal with an active directory or ldap installation and the password changing from the client doesn't work for some reason, the main authentication will be throught the VPN.
- Add this to `/scripts/monitor_samba_quota`:
```
#!/bin/bash

SHARE="/srv/samba/users"
LIMIT_GB=750 # in GB
EMAIL="lubbarbarek@proton.me"

USAGE=$(du -sb "$SHARE" | cut -f1)
LIMIT_BYTES=$((LIMIT_GB * 1024 * 1024 * 1024))

USAGE_GB=$((USAGE / 1024 / 1024 / 1024))
PERCENT=$((USAGE * 100 / LIMIT_BYTES))

if [ "$USAGE" -gt "$LIMIT_BYTES" ]; then
    echo "ALERT: $SHARE exceeds ${LIMIT_GB}GB! Current: ${USAGE_GB}GB (${PERCENT}%)"
    echo "Disk usage exceeded limit on $(date)" | mail -s "Samba Share Quota Alert" "$EMAIL"
fi
```
- Make sure the mail is already configured
- Then run `sudo crontab -e` and add this line `*/5 * * * * /scripts/monitor_samba_quota`

# Mail
- Run this (choose "no configuration")
```
sudo apt install -y msmtp msmtp-mta mailutils
```
Add this configuration to `/etc/msmtprc`:
```
defaults
auth           on
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account gmail
host           smtp.gmail.com
port           587
from           email@gmail.com
user           email@gmail.com
password       APP_PASSWORD

account default : gmail
```
- Test with `echo "Test body" | mail -s "Test Subject" recieving@email.com`
# Samba (client)
- After connecting through the VPN (if there is one, otherwise just use the local ip address of the server):
**On linux** (potentially, replace the uid and gid by the target user's ids on the local machine):
```
sudo mkdir /mnt/users
sudo mount -t cifs //serveraddr/users /mnt/users \
  -o credentials=/home/yourlocaluser/.smbcredentials,uid=1000,gid=1000,file_mode=0644,dir_mode=0755,vers=3.0
```
The smbcredentials file should look like:
```
username=username
password=therandomlygeneratedpasswordfrombefore
```
**On windows**:
Simply create a new network device at the root ("This PC"), put the password
