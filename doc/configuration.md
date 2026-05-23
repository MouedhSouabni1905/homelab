# Vaultwarden

Go to `yourserveraddress/admin` in the browser, log in with `temporary_token` and 

# Borg-ui

Make sure to create `/mnt/local/borg-backup` and make it accessible to UID and GUID 1001, and same thing to the borg-ui data directory:
```
sudo mkdir -p /mnt/local/borg-backup/
sudo chown -R 1001:1001 /mnt/local/borg-backup/
sudo chmod -R u+rwX,g+rwX /mnt/local/borg-backup/
sudo chown -R 1001:1001 /mnt/local/borg-ui/data/
sudo chmod -R u+rwX,g+rwX /mnt/local/borg-ui/data/
```

# Nextcloud

Run this docker compose file:
```
services:
  nextcloud-aio-mastercontainer:
    image: ghcr.io/nextcloud-releases/all-in-one:latest
    init: true
    restart: always
    container_name: nextcloud-aio-mastercontainer
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    network_mode: bridge
    ports:
      - "8002:8080"
    environment:
      - APACHE_PORT=11000
      - APACHE_IP_BINDING=0.0.0.0
      - SKIP_DOMAIN_VALIDATION=false

volumes:
  nextcloud_aio_mastercontainer:
    name: nextcloud_aio_mastercontainer
```
