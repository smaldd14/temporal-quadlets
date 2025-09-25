# Temporal Quadlets Installation Guide

This guide walks through deploying Temporal Server with podman quadlets on RHEL 10.

## Prerequisites

- RHEL 10 system
- Root access for initial setup
- Network connectivity

## Architecture Overview

This deployment uses a multi-user architecture:
- **postgres user**: Runs PostgreSQL database with host networking (port 5432)
- **temporal user**: Runs Temporal services with custom bridge network
- **nginx**: Provides HTTPS reverse proxy to Temporal UI

## Installation Steps

### 1. Install Podman
```bash
# Install podman and dependencies
sudo dnf update
sudo dnf install -y podman openssl curl

# Verify podman installation
podman --version
```

### 2. Create Users
```bash
# Create postgres user for database
sudo useradd -r -m -s /bin/bash postgres
sudo usermod -aG systemd-journal postgres
sudo loginctl enable-linger postgres
# Create UIDs for podman
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 postgres

# Create temporal user for temporal services
sudo useradd -r -m -s /bin/bash temporal
sudo usermod -aG systemd-journal temporal
sudo loginctl enable-linger temporal
# Create UIDs for podman
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 temporal
```

### 3. Deploy PostgreSQL (as postgres user)

#### Copy PostgreSQL quadlet file:
```bash
# Copy the postgres quadlet file to postgres user
sudo mkdir -p /home/postgres/.config/containers/systemd
sudo cp infrastructure/postgres/temporal-postgres.container /home/postgres/.config/containers/systemd/
sudo chown -R postgres:postgres /home/postgres/.config
```

#### create proper login session
run as root:
```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 postgres
reboot now
```
Se [this doc](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md) for more detail

After first creating the users, you may run into an error that looks like the following:
```bash
Failed to connect to user scope bus via local transport: $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined (consider using --machine=<user>@.host --user to connect to bus of other user)
```
To fix, you need to create a proper login session for the user:
```bash
# Or check if the postgres user has a proper runtime directory:
sudo ls -la /run/user/$(id -u postgres)

# If that directory doesn't exist, you might need to create a proper login session first:
sudo loginctl enable-linger postgres
dnf install -y systemd-container
sudo machinectl shell postgres@
```

#### Start PostgreSQL service:
```bash
# Switch to postgres user and start database
sudo -u postgres -i
systemctl --user daemon-reload
systemctl --user list-unit-files | grep temporal
systemctl --user start temporal-postgres.service
# the following won't work because service is generated, but running the enable-linger aparently allows for it to start at boot
# But it doesn't look like that's happening?
systemctl --user enable temporal-postgres.service

# Verify database is running
podman ps
exit
```

### 4. Setup Temporal Configuration

#### Create configuration directories:
```bash
sudo mkdir -p /home/temporal/config/temporal
sudo mkdir -p /home/temporal/config/nginx

# Copy configuration files
sudo cp -r services/temporal/config/* /home/temporal/config/
sudo chown -R temporal:temporal /home/temporal/config
```

### 5. Deploy Temporal Services (as temporal user)

#### Copy quadlet files:
```bash
# Copy temporal quadlet files
sudo mkdir -p /home/temporal/.config/containers/systemd
sudo cp services/temporal/*.container /home/temporal/.config/containers/systemd/
sudo cp services/temporal/*.network /home/temporal/.config/containers/systemd/
sudo cp services/temporal/*.volume /home/temporal/.config/containers/systemd/
sudo chown -R temporal:temporal /home/temporal/.config
```

#### Start Temporal services:
```bash
# Switch to temporal user
sudo -u temporal -i

# Reload systemd to pick up quadlet files
systemctl --user daemon-reload

# Start services in dependency order
systemctl --user list-unit-files | grep temporal
systemctl --user start temporal-network
systemctl --user start temporal-config-volume.service
systemctl --user start nginx-config-volume.service
systemctl --user start temporal-server.service
systemctl --user start temporal-ui.service
# TODO:  from root, it seems like this needs to be run after reboots too, 
sudo sysctl net.ipv4.ip_unprivileged_port_start=80

systemctl --user start temporal-nginx.service

# Enable services to start at boot, apparently this is supposed to be taken care of with the linger cmd? but it doesn't
systemctl --user enable temporal.network
systemctl --user enable temporal-config-volume.service
systemctl --user enable nginx-config-volume.service
systemctl --user enable temporal-server.service
systemctl --user enable temporal-ui.service
systemctl --user enable temporal-nginx.service

exit
```

### 6. Verify Deployment

#### Check service status:
```bash
# Check postgres service
sudo -u postgres systemctl --user status temporal-postgresql.service

# Check temporal services
sudo -u temporal systemctl --user status temporal-server.service
sudo -u temporal systemctl --user status temporal-ui.service
sudo -u temporal systemctl --user status temporal-nginx.service
```

#### Check containers:
```bash
# Check postgres container
sudo -u postgres podman ps

# Check temporal containers
sudo -u temporal podman ps
```

#### Test connectivity:
```bash
# Test nginx health endpoint
curl -k https://localhost/health

# Test temporal server (if accessible)
curl -f http://localhost:7233 || echo "Temporal server running on gRPC"
```

## Access Points

- **Web UI**: https://temporal.local (add to /etc/hosts: `<server-ip> temporal.local`)
- **gRPC API**: `<server-ip>:7233` (for client applications)
- **HTTP Redirect**: http://temporal.local → https://temporal.local

## Configuration

### Custom Domain
Update `/etc/hosts` on client machines:
```
<server-ip> temporal.local
```

### Client Connection
Applications should connect to: `<server-ip>:7233`

### Logs
```bash
# PostgreSQL logs
sudo -u postgres journalctl --user -u temporal-postgresql.service -f

# Temporal service logs
sudo -u temporal journalctl --user -u temporal-server.service -f
sudo -u temporal journalctl --user -u temporal-ui.service -f
sudo -u temporal journalctl --user -u temporal-nginx.service -f

# Container logs
sudo -u postgres podman logs -f temporal-postgresql
sudo -u temporal podman logs -f temporal-server
sudo -u temporal podman logs -f temporal-ui
sudo -u temporal podman logs -f temporal-nginx
```

## Troubleshooting

### Service Won't Start
```bash
# Check quadlet syntax and service status
sudo -u temporal systemctl --user status temporal-server.service

# Verify network exists
sudo -u temporal podman network ls

# Check PostgreSQL connectivity
sudo -u postgres podman exec temporal-postgresql pg_isready -U temporal
```

### SSL Certificate Issues
```bash
# Regenerate certificates
sudo rm /home/temporal/config/nginx/temporal.crt /home/temporal/config/nginx/temporal.key
# Re-run certificate generation from step 4
```

### Database Issues
```bash
# Check PostgreSQL logs
sudo -u postgres journalctl --user -u temporal-postgresql.service

# Connect to database for debugging
sudo -u postgres podman exec -it temporal-postgresql psql -U temporal
```

### Network Issues
```bash
# Check if temporal network exists
sudo -u temporal podman network ls

# Recreate network if needed
sudo -u temporal systemctl --user restart temporal.network
```

## Maintenance

### Updates
```bash
# Update container images
sudo -u postgres podman pull postgres:16
sudo -u temporal podman pull temporalio/auto-setup:1.28.1
sudo -u temporal podman pull temporalio/ui:2.39.0
sudo -u temporal podman pull nginx:1.27-alpine

# Restart services
sudo -u postgres systemctl --user restart temporal-postgresql.service
sudo -u temporal systemctl --user restart temporal-server.service
sudo -u temporal systemctl --user restart temporal-ui.service
sudo -u temporal systemctl --user restart temporal-nginx.service
```

### Backup
```bash
# Backup PostgreSQL database
sudo -u postgres podman exec temporal-postgresql pg_dump -U temporal temporal > temporal-backup-$(date +%Y%m%d).sql
```

## Security Notes

- PostgreSQL is accessible on port 5432 via host networking
- Temporal UI is only accessible through nginx HTTPS proxy
- Self-signed certificates are used (replace with proper certificates for production)
- Default passwords are used (change for production)