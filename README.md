# Temporal Quadlets

Deploy Temporal with Podman Quadlets on RHEL/Fedora systems. This project demonstrates how to run a complete Temporal workflow orchestration stack using systemd-native container management.

## What's Included

- **Temporal Server** - Core workflow engine with PostgreSQL backend
- **Temporal UI** - Web interface for monitoring workflows
- **PostgreSQL** - Database for persistence
- **Nginx** - Reverse proxy with SSL termination
- **Custom networking** - Isolated container network for service discovery

## Prerequisites

- RHEL 10+ or Fedora with Podman 4.4+
- Root access for system-wide deployment
- Basic familiarity with systemd and containers

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/smaldd14/temporal-quadlets.git
cd temporal-quadlets
```

### 2. Prepare VM Environment
```bash
# SSH into your target machine
ssh your-vm
sudo su -

# Create config directories
mkdir -p /opt/temporal/config/{temporal,nginx/{conf.d,ssl}}
```

### 3. Copy Files
```bash
# Copy quadlet definitions
scp services/temporal/*.container services/temporal/*.volume services/temporal/*.network root@{VM_IP}:/etc/containers/systemd/

# Copy configuration files
scp services/temporal/config/temporal/development-sql.yaml root@{VM_IP}:/opt/temporal/config/temporal/
scp services/temporal/config/nginx/conf.d/temporal.conf root@{VM_IP}:/opt/temporal/config/nginx/conf.d/
scp services/temporal/config/nginx/ssl/* root@{VM_IP}:/opt/temporal/config/nginx/ssl/

# Set proper ownership
ssh root@{VM_IP} "chown -R root:root /opt/temporal/config/"
```

### 4. Deploy Services
```bash
# On your VM
systemctl daemon-reload

# Start services in dependency order
systemctl start temporal.network
systemctl start temporal-postgres.service
systemctl start temporal-server.service
systemctl start temporal-ui.service
systemctl start temporal-nginx.service
```

### 5. Verify Deployment
```bash
# Check all services
systemctl status temporal*.service

# Test access
curl http://localhost/health
```

## Access Points

- **Direct UI**: `http://localhost:8080`
- **Via Nginx**: `http://localhost` or `https://localhost`
- **External** (with port forwarding): Configure in VM settings

## File Structure

```
services/temporal/
├── temporal-postgres.container      # PostgreSQL database
├── temporal-server.container        # Temporal workflow engine
├── temporal-ui.container           # Web UI
├── temporal-nginx.container        # Reverse proxy
├── temporal.network               # Custom network
├── *-config.volume               # Configuration volumes
├── nginx-ssl.volume             # SSL certificates
└── config/                     # Configuration files
    ├── temporal/
    │   └── development-sql.yaml
    └── nginx/
        ├── conf.d/temporal.conf
        └── ssl/
            ├── temporal.crt
            └── temporal.key
```

## Troubleshooting

### View Logs
```bash
# All services
journalctl -f -u temporal*.service

# Individual service
journalctl -f -u temporal-server.service

# Container logs
podman logs temporal-server
```

### Common Issues

**PostgreSQL connection issues**:
```bash
systemctl status temporal-postgres.service
podman exec temporal-postgresql pg_isready -U temporal
```

**Nginx permission errors**:
```bash
chown -R root:root /opt/temporal/config/
```

## Production Notes

- This setup uses self-signed SSL certificates for development
- For production: use real domains and Let's Encrypt certificates
- Consider separate machines for different components
- Implement proper secrets management
- Set up monitoring and backup strategies

## Related Resources

- [Detailed Tutorial Blog Post](https://yoursite.com/temporal-quadlets)
- [Temporal Documentation](https://docs.temporal.io)
- [Podman Quadlets Guide](https://www.redhat.com/en/blog/quadlet-podman)

## Why Podman Quadlets?

- **No daemon dependency** - More secure than Docker daemon
- **Native systemd integration** - Standard Linux service management
- **Perfect for edge** - Reduced attack surface for high-security environments
- **Production ready** - Automatic restarts, health checks, logging