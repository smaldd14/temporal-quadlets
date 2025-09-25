# Deploying Temporal with Podman Quadlets

I spent Labor Day Weekend learning how to deploy Temporal on a linux machine using Podman Quadlets. Temporals website has great docs on how to self-host temporal, in many ways, but there isn't anything about using podman quadlets, so I thought I'd dive in.


## The Goal
I wanted to deploy Temporal Server with postgres, UI, and an NGINX proxy, following much of what this [tutorial]() did, and I also followed a bit of the docker compose self hosting [tutorial](). However, I wanted to be able to use Podman's Quadlets feature to easily deploy containers as systemd services. 
First, I wanted to install this on my Raspberry Pi, but then I realized my pi was running Debian(bookworm) which only support podman version 4.3.1. So, I set off to create a Vagrantfile to accurately mimic a linux environment because I am on a mac, and I want installs to go as seemless as possible on a fresh linux machine.

## Prereqs
I had to install Virtualbox and Vagrant on my mac, and have claude code create a vagrantfile to get a linux rhel setup going.

## Setup Quadlet files
I needed to set up 5 different quadlet files: `temporal.network`, `temporal-server.container`, `temporal-ui.container`, `temporal-postgres.container` and `temporal-nginx.container`. Each one sets up the different services that are needed for self hosting temporal.

### Temporal network
I set up `temporal.network` to create a Podman container network device. Doing so allows you to refer to the other container services by name when you want to communicate with them, e.g. my applications that want to connect to the temporal server can be on the `temporal.network` and connect to temporal with `temporal-server:7233`. You can see the `temporal-ui.container` can connect to the temporal server:
```bash
# Connect to temporal server
Environment=TEMPORAL_ADDRESS=temporal-server:7233
```

