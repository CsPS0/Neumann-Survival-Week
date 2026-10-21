# Empty School server VM

This VM is a fallback host for the co-op game. It boots into a running game server, with no desktop and no setup. Use it when no player can host, for example on a school PC in the middle of the room.

The VM runs Debian 12 (minimal) with Docker. It starts several rooms. Each room is one game server on its own UDP port and holds up to 10 players. Students who want a lobby pick a room and join it. Three players or ten players both work, because the limit is a maximum.

## Status

The build files were written without access to VirtualBox, so the .ova has not been built or booted yet. Build it once on your Arch laptop and test it with two game clients before the delivery date.

## Build the .ova (once, on your laptop)

Requirements: Packer, VirtualBox, internet access, about 10 GB free disk.

```
sudo pacman -S packer virtualbox virtualbox-host-modules-arch
server/vm/build-ova.sh
```

The script packs the HORROR-GAME folder, installs Debian unattended, installs Docker and builds the server image inside the VM. The result is `server/vm/output/TheEmptySchoolServer.ova`. Build time is about 20 to 40 minutes. Copy the file to a USB drive. Do not commit it, it is too large for git.

The VM uses 1 vCPU and 1024 MB of RAM. Pass another value to change it: `server/vm/build-ova.sh 768`.

## Import on the teacher PC (Windows 10)

1. Install VirtualBox on the PC.
2. Open VirtualBox, choose File, Import Appliance, select `TheEmptySchoolServer.ova` and press Import.
3. Open the VM Settings, Network, Adapter 1. Set "Attached to" to **Bridged Adapter**. Select the PC's active network card (the wired one when possible).
4. Start the VM. Wait about 30 seconds.

The console login screen shows the server address and the rooms, for example:

```
Address: 192.168.1.50
Room 1: 192.168.1.50:7777   code ABCDEFGHIJ
Room 2: 192.168.1.50:7778   code ...
```

You do not need to log in. Leave the VM window open or minimized. VMware Player also imports .ova files (File, Open) and needs the same bridged network setting.

## Windows firewall

Bridged traffic goes to the VM directly, so the Windows firewall on the host PC does not filter it in most cases. If students cannot connect, check three things:

- The VM address starts with the same numbers as the student PCs (for example 192.168.1.x). If it starts with 10.0.2, the adapter is still on NAT.
- The school network allows traffic between PCs. Some networks isolate clients.
- Add an inbound rule for UDP ports 7777 to 7780 on the teacher PC and on the student PCs if their firewall blocks outgoing UDP.

## How players join

In the game, choose Join Co-op and type either the room code or the address with the port, for example `192.168.1.50:7777`. Each room is a separate game. Tell group 1 to use room 1, group 2 to use room 2, and so on.

## Settings

Log in on the console with user `neumann`, password `neumann`. Edit `/etc/neumann/rooms.conf`:

- `ROOMS`: number of rooms. Default 4.
- `FIRST_PORT`: port of room 1. Default 7777.
- `MAX_PLAYERS`: players per room. Default 10.

Apply with `sudo systemctl restart neumann-rooms`. The login screen updates after a few seconds. Open the matching UDP ports if you add rooms.

Each room uses roughly 100 MB of RAM (not measured yet). Four rooms fit in 1 GB. Raise the VM memory in VirtualBox before you add many rooms.

## Notes

- The address comes from DHCP. If the PC moves to another network or the lease changes, restart the VM so the rooms and codes use the new address.
- The VM does not have remote access. To enable SSH, log in on the console and run `sudo systemctl enable --now ssh`.
- Change the `neumann` password with `passwd` if the VM stays on a shared network.
- Stop the server by shutting down the VM. Logs for room 1: `sudo docker logs neumann-room-1`.
