#!/bin/sh
# Runs inside the VM during the build. Installs Docker, builds the server image and enables the rooms service.
set -eu
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends docker.io
systemctl enable docker

mkdir -p /opt/neumann-game /etc/neumann /etc/issue.d
tar -xf /tmp/game-context.tar -C /opt/neumann-game
(cd /opt/neumann-game && docker build -f server/Dockerfile -t empty-school-server .)
rm -rf /opt/neumann-game /tmp/game-context.tar

install -m 644 /tmp/vm-files/rooms.conf /etc/neumann/rooms.conf
install -m 755 /tmp/vm-files/neumann-rooms /usr/local/bin/neumann-rooms
install -m 644 /tmp/vm-files/neumann-rooms.service /etc/systemd/system/neumann-rooms.service
systemctl enable neumann-rooms.service

# Console login screen: show the address from the first boot until the rooms service writes the real one.
printf '\n  The Empty School server. Starting rooms. Wait a moment.\n\n' > /etc/issue.d/10-neumann.issue

# Remote access is off in the final image. Enable it with: sudo systemctl enable --now ssh
systemctl disable ssh

# Free space and shrink the exported disk.
docker image prune -f
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/vm-files
dd if=/dev/zero of=/zero.fill bs=1M 2>/dev/null || true
rm -f /zero.fill
sync
