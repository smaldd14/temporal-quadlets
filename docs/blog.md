# Deploying Temporal with Podman Quadlets

I spent Labor Day Weekend learning how to deploy Temporal on a linux machine using Podman Quadlets. Temporals website has great docs on how to self-host temporal, in many ways, but there isn't anything about using podman quadlets, so I thought I'd dive in.


## The Goal
I wanted to deploy Temporal Server with postgres, UI, and an NGINX proxy, following much of what this [tutorial]() did, and I also followed a bit of the docker compose self hosting [tutorial](). However, I wanted to be able to use Podman's Quadlets feature to easily deploy containers as systemd services. 
First, I wanted to install this on my Raspberry Pi, but then I realized my pi was running Debian(bookworm) which only support podman version 4.3.1. So, I set off to create a Vagrantfile to accurately mimic a linux environment because I am on a mac, and I want installs to go as seemless as possible on a fresh linux machine.

## Prereqs
Set up a RHEL10 machine

## The Process

Once sshing into your machine, sudo into root with `sudo su -`. This will allow you to put the podman quadlets into the proper directory, and the configuration files where the volume expect them to be so that they can be mounted into their respective containers.

Podman quadlets allows you to specify systemd services that run containers, and it also allows you to create custom networks for your containers to communicate with each other. You can specify volumes, networks, and containers as `*.volume`, `*.container` and `*.network` files. 

Podman quadlets look for containers in the following directories:
- `/etc/containers/systemd/` (system-wide)
- `$HOME/.config/containers/systemd/` (per-user)
[see docs]()

 - `scp -r services/temporal/ root@{VM-IP}:`. This should copy the file to the user's home directory.
- `ssh root@{VM-IP}`# You may need to enable root login
- make the config directories where the volumes will point to
```bash
mkdir -p /opt/temporal/config/{nginx.temporal}
# Move config files to proper directories
cp -R config /opt/temporal/
```

Now let's load in the Podman quadlet files so that they become systemd services.
```bash
# Move
cp temporal/*.* /etc/containers/systemd/
# Reload systemd to pick up new services
systemctl daemon-reload
# list services that we just loaded to ensure they are there
systemctl list-unit-files | grep temporal
# Start services in dependency order
systemctl start temporal-network
systemctl start nginx-config-volume.service
systemctl start nginx-ssl-volume.service
systemctl start temporal-postgres.service
systemctl start temporal-server.service
systemctl start temporal-ui.service
systemctl start temporal-nginx.service
```

At this point, you'll be able to access temporal UI by simply going to `localhost` in your web browser. But, We mentioned that we wanted to set up an nginx reverse proxy so that we can reach the server from outside our local machine. For that, I followed [the Temporal docs](https://learn.temporal.io/tutorials/infrastructure/nginx-sqlite-binary/#deploying-an-nginx-reverse-proxy-with-an-ssl-certificate).

## Accessing from Host Machine (Optional)

If you're running this setup in a VM and want to access the Temporal UI from your host machine, you'll need to set up port forwarding.

### VirtualBox Port Forwarding
In VirtualBox, go to VM Settings → Network → Advanced → Port Forwarding and add these rules:

- **SSH**: Host Port 2222 → Guest Port 22 (you probably already have this)
- **Temporal HTTP**: Host Port 8080 → Guest Port 80 (nginx proxy)
- **Temporal HTTPS**: Host Port 8443 → Guest Port 443 (nginx proxy with SSL)
- **Temporal UI Direct**: Host Port 9080 → Guest Port 8080 (direct UI access, bypass nginx)

Then access from your host machine:
- HTTP via nginx: `http://localhost:8080`
- HTTPS via nginx: `https://localhost:8443` (will show certificate warning)
- Direct UI: `http://localhost:9080`

### Production Deployment Note

This setup uses self-signed certificates for local development. For production deployment with real domains and Let's Encrypt certificates, see the [official Temporal nginx guide](https://learn.temporal.io/tutorials/infrastructure/nginx-sqlite-binary/#deploying-an-nginx-reverse-proxy-with-an-ssl-certificate). 
