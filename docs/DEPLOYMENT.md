# Temporal Quadlets Deployment Guide

This guide walks through deploying Temporal Server with podman quadlets on Raspberry Pi.

## Prerequisites

- Raspberry Pi with Raspberry Pi OS
- Root access for initial setup
- Network connectivity

## Installation Steps

### 1. Create Temporal User
```bash
# Create dedicated user for temporal services
sudo useradd -r -m -s /bin/bash temporal
sudo usermod -aG systemd-journal temporal
```

### 2. Install Podman
```bash
# Install podman and dependencies
sudo apt update
sudo apt install -y podman

# Enable lingering for temporal user (allows user services to start at boot)
sudo loginctl enable-linger temporal
```

### 3. Stop Existing Docker Temporal (if running)
```bash
# Stop and disable existing temporal docker containers
sudo docker compose -f /path/to/docker-compose.yml down
sudo systemctl disable docker-temporal.service  # if exists
```

### 4. Deploy Quadlet Files

#### Switch to temporal user:
```bash
sudo -u temporal -i
```

#### Copy project files:
```bash
# Assuming files are in /tmp/temporal-quadlets
cp -r /tmp/temporal-quadlets/* ~/
```

#### Create quadlet directories:
```bash
mkdir -p ~/.config/containers/systemd
cp quadlets/* ~/.config/containers/systemd/
```

### 5. Generate SSL Certificates

#### Exit temporal user session and create certificates as root:
```bash
# Exit temporal user session
exit

# Install openssl and create certificates as root
sudo apt install -y openssl
sudo mkdir -p /home/temporal/data/nginx-certs
cd /home/temporal/data/nginx-certs

# Generate private key
sudo openssl genrsa -out temporal.key 2048

# Generate self-signed certificate (valid for 1 year)
sudo openssl req -new -x509 -key temporal.key -out temporal.crt -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=temporal.local"

# Set proper ownership and permissions
sudo chown temporal:temporal temporal.key temporal.crt
sudo chmod 600 temporal.key
sudo chmod 644 temporal.crt
```

### 6. Create Required Directories and Switch Back to Temporal User
```bash
# Create remaining directories as root and set ownership
sudo mkdir -p /home/temporal/data/sqlite
sudo mkdir -p /home/temporal/config/temporal
sudo mkdir -p /home/temporal/config/nginx
sudo chown -R temporal:temporal /home/temporal/data /home/temporal/config

# Switch back to temporal user
sudo -u temporal -i
```

### 7. Reload and Start Services
```bash
# See what temporal services currently exist (should be none initially)
systemctl --user list-units --state=active | grep temporal
# Reload systemd to pick up quadlet files
systemctl --user daemon-reload

# Start services in dependency order
systemctl --user start temporal-network.service
systemctl --user start temporal-server.service
systemctl --user start temporal-ui.service  
systemctl --user start temporal-nginx.service

# Enable services to start at boot
systemctl --user enable temporal-network.service
systemctl --user enable temporal-server.service
systemctl --user enable temporal-ui.service
systemctl --user enable temporal-nginx.service
```

### 8. Verify Deployment
```bash
# Check service status
systemctl --user status temporal-server.service
systemctl --user status temporal-ui.service
systemctl --user status temporal-nginx.service

# Check containers are running
podman ps

# Test connectivity
curl -k https://localhost/health
```

## Access Points

- **Web UI**: https://temporal.local (add to /etc/hosts: `<pi-ip> temporal.local`)
- **gRPC API**: `<pi-ip>:7233` (for client applications)
- **HTTP Redirect**: http://temporal.local → https://temporal.local

## Configuration

### Custom Domain
Update `/etc/hosts` on client machines:
```
<raspberry-pi-ip> temporal.local
```

### Client Connection
Applications should connect to: `<raspberry-pi-ip>:7233`

### Logs
```bash
# View service logs
journalctl --user -u temporal-server.service -f
journalctl --user -u temporal-ui.service -f
journalctl --user -u temporal-nginx.service -f

# View container logs
podman logs -f temporal-server
podman logs -f temporal-ui
podman logs -f temporal-nginx
```

## Troubleshooting

### Service Won't Start
```bash
# Check quadlet syntax
systemctl --user status temporal-server.service

# Verify network exists
podman network ls

# Check file permissions
ls -la ~/data/
ls -la ~/config/
```

### SSL Certificate Issues
```bash
# Regenerate certificates
cd ~/data/nginx-certs
rm temporal.crt temporal.key
# Re-run certificate generation from step 5
```

### Database Issues
```bash
# Check SQLite files
ls -la ~/data/sqlite/
# Remove and restart if corrupted (will lose data)
rm -rf ~/data/sqlite/*
systemctl --user restart temporal-server.service
```

## Maintenance

### Updates
```bash
# Update container images
podman pull temporalio/auto-setup:1.28.1
podman pull temporalio/ui:2.39.0
podman pull nginx:1.27-alpine

# Restart services
systemctl --user restart temporal-server.service
systemctl --user restart temporal-ui.service
systemctl --user restart temporal-nginx.service
```

### Backup
```bash
# Backup SQLite database
tar -czf temporal-backup-$(date +%Y%m%d).tar.gz ~/data/sqlite/
```
