Vagrant.configure("2") do |config|
  config.vm.box = "generic/rocky9"
  
  config.vm.hostname = "temporal-test"
  
  # Port forwarding for Temporal services
  config.vm.network "forwarded_port", guest: 7233, host: 7233  # Temporal gRPC
  config.vm.network "forwarded_port", guest: 80, host: 8080    # HTTP
  config.vm.network "forwarded_port", guest: 443, host: 8443   # HTTPS
  
  # VM resources
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
    vb.name = "temporal-quadlets-test"
  end
  
  # Sync the temporal-quadlets project
  config.vm.synced_folder "/Users/devinsmaldore/code/developer/rpi/temporal-quadlets", "/tmp/temporal-quadlets", type: "rsync"
  
  # Provisioning script
  config.vm.provision "shell", inline: <<-SHELL
    # Update system
    dnf update -y
    
    # Install required packages
    dnf install -y podman openssl curl wget tar gzip
    
    # === POSTGRES USER SETUP ===
    # Create postgres user for shared database
    useradd -r -m -s /bin/bash postgres
    usermod -aG systemd-journal postgres
    
    # Set up subuid/subgid for postgres user
    echo "postgres:200000:65536" >> /etc/subuid
    echo "postgres:200000:65536" >> /etc/subgid
    
    # Enable lingering for postgres user
    loginctl enable-linger postgres
    
    # Start postgres user service and create runtime directory
    systemctl start user@$(id -u postgres).service
    mkdir -p /run/user/$(id -u postgres)
    chown postgres:postgres /run/user/$(id -u postgres)
    chmod 700 /run/user/$(id -u postgres)
    
    # Set up postgres environment
    echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> /home/postgres/.bashrc
    chown postgres:postgres /home/postgres/.bashrc
    
    # Copy and deploy postgres infrastructure
    sudo -u postgres cp -r /tmp/temporal-quadlets/infrastructure/postgres/* /home/postgres/
    sudo -u postgres mkdir -p /home/postgres/.config/containers/systemd
    sudo -u postgres cp /home/postgres/temporal-postgres.container /home/postgres/.config/containers/systemd/
    
    # Fix postgres data directory permissions
    sudo -u postgres mkdir -p /home/postgres/data/postgres
    sudo -u postgres podman unshare chown 999:999 /home/postgres/data/postgres
    
    # === TEMPORAL USER SETUP ===
    # Create temporal user
    useradd -r -m -s /bin/bash temporal
    usermod -aG systemd-journal temporal
    
    # Set up subuid/subgid for temporal user
    echo "temporal:100000:65536" >> /etc/subuid
    echo "temporal:100000:65536" >> /etc/subgid
    
    # Enable lingering for temporal user
    loginctl enable-linger temporal
    
    # Start temporal user service and create runtime directory
    systemctl start user@$(id -u temporal).service
    mkdir -p /run/user/$(id -u temporal)
    chown temporal:temporal /run/user/$(id -u temporal)
    chmod 700 /run/user/$(id -u temporal)
    
    # Set up temporal environment
    echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> /home/temporal/.bashrc
    chown temporal:temporal /home/temporal/.bashrc
    
    # Copy and deploy temporal services
    sudo -u temporal cp -r /tmp/temporal-quadlets/services/temporal/* /home/temporal/
    sudo -u temporal mkdir -p /home/temporal/.config/containers/systemd
    sudo -u temporal cp /home/temporal/*.container /home/temporal/.config/containers/systemd/
    sudo -u temporal cp /home/temporal/temporal.network /home/temporal/.config/containers/systemd/
    
    # Create temporal directories
    sudo -u temporal mkdir -p /home/temporal/certs-staging
    sudo -u temporal mkdir -p /home/temporal/config/{temporal,nginx}
    
    # Generate SSL certificates for temporal (staging area)
    cd /home/temporal/certs-staging
    openssl genrsa -out temporal.key 2048
    openssl req -new -x509 -key temporal.key -out temporal.crt -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=temporal.local"
    chown temporal:temporal temporal.key temporal.crt
    chmod 600 temporal.key
    chmod 644 temporal.crt
    
    # Add temporal.local to hosts file
    echo "127.0.0.1 temporal.local" >> /etc/hosts
    
    # Check podman version
    echo "Podman version: $(podman --version)"
    
    echo "=== DEPLOYMENT COMPLETE ==="
    echo ""
    echo "🗄️  PostgreSQL (infrastructure):"
    echo "   sudo -u postgres -i"
    echo "   systemctl --user start temporal-postgres.service"
    echo ""
    echo "⚡ Temporal (services):"
    echo "   sudo -u temporal -i" 
    echo "   systemctl --user daemon-reload"
    echo "   # First start the nginx-certs volume service to create the volume"
    echo "   systemctl --user start nginx-certs-volume.service"
    echo "   # Copy SSL certificates to the named volume"
    echo "   podman volume mount systemd-nginx-certs"
    echo "   cp /home/temporal/certs-staging/* \\$(podman volume mount systemd-nginx-certs)"
    echo "   podman volume unmount systemd-nginx-certs"
    echo "   # Now start all services"
    echo "   systemctl --user start temporal.network temporal-server.service temporal-ui.service temporal-nginx.service"
    echo ""
    echo "🌐 Access:"
    echo "   Web UI: https://localhost:8443 (or https://temporal.local)"
    echo "   gRPC: localhost:7233"
  SHELL
end