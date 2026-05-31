# Vaultwarden

Go to `yourserveraddress/admin` in the browser, log in with `temporary_token` and 

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
