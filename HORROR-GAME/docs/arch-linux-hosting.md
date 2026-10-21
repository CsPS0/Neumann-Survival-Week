# Arch Linux Dedicated Server & Hosting Guide

This guide covers installing dependencies, configuring, and hosting dedicated multiplayer servers for *The Empty School* natively on Arch Linux (desktop or laptop).

---

## Why Host on Arch Linux?

Hosting directly on an Arch Linux machine is the lightest and lowest-latency method to run the dedicated server:
- **Zero hypervisor overhead**: runs directly on the Linux kernel without VirtualBox/VM overhead.
- **Ultra-low resource footprint**: ~40 MB RAM per active room and near-zero idle CPU.
- **Optimal network latency**: native UDP socket handling with zero packet translation delay.

---

## 1. Prerequisites & Package Installation

Depending on your preferred hosting method, install the necessary packages using `pacman`:

### For Native Hosting (Recommended)
```bash
sudo pacman -S godot
```
*(Alternatively, download the official standalone `Godot_v4.7.x_linux.x86_64` binary and place it in your `$PATH` as `godot`.)*

### For Docker Hosting
```bash
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
```

### For VirtualBox Appliance (.ova) Hosting
```bash
sudo pacman -S virtualbox virtualbox-host-modules-arch
sudo modprobe vboxdrv
```

---

## 2. Hosting Option 1: Native Headless Godot (Recommended)

Native hosting runs the headless Godot server directly. All commands are executed from the `HORROR-GAME/` directory.

### Single Room
Make the runner script executable and launch the server on UDP port 7777:
```bash
chmod +x server/run-server.sh
./server/run-server.sh --port 7777 --max-players 10
```

### 4 Concurrent Rooms (Matching Classroom VM Layout)
To run four independent rooms simultaneously (ports 7777 to 7780) in the background:
```bash
for port in 7777 7778 7779 7780; do
    ./server/run-server.sh --port "$port" --max-players 10 &
done
```

### Stopping All Server Rooms
To terminate all background Godot server instances:
```bash
killall godot
```

### Command-Line Options Reference
The runner script accepts several optional flags:
- `--port <number>`: UDP listening port (default: `7777`).
- `--max-players <number>`: Maximum player capacity for the room (default: `4`, recommended for school: `10`).
- `--public-host <ip>`: The external or LAN IP advertised to joining clients (e.g. `--public-host 192.168.1.100`).
- `--code <code>`: Force a specific 4-digit room code (e.g. `--code 4821`).

---

## 3. Hosting Option 2: Docker / Docker Compose

If you prefer containerized isolation:

### Using Docker Compose
Run the multi-container stack defined in `server/docker-compose.yml`:
```bash
docker compose -f server/docker-compose.yml up --build
```

### Using Plain Docker
Build the server image and run a container:
```bash
docker build -f server/Dockerfile -t empty-school-server .
docker run --rm -it -p 7777:7777/udp -e NEUMANN_PUBLIC_HOST=$(hostname -I | awk '{print $1}') empty-school-server
```

Environment variables supported by the container:
- `NEUMANN_PORT`: UDP listening port.
- `NEUMANN_MAX_PLAYERS`: Maximum players.
- `NEUMANN_PUBLIC_HOST`: IP address communicated to clients.
- `NEUMANN_CODE`: Static 4-digit room code.

---

## 4. Hosting Option 3: VirtualBox Appliance (.ova) on Arch

If you have built `TheEmptySchoolServer.ova` and want to test or run it under Arch:
1. Ensure the host modules are loaded:
   ```bash
   sudo modprobe vboxdrv
   ```
2. Launch VirtualBox (`virtualbox`) and import `TheEmptySchoolServer.ova` via **File** → **Import Appliance...**.
3. In VM Settings → **Network** → **Adapter 1**, ensure it is set to **Bridged Adapter** bound to your active network interface.
4. Boot the VM. The console will display the server IP and room codes.

---

## 5. Network, Firewall & School Wi-Fi Configuration

### Finding Your Local IP
Determine your current LAN IP address:
```bash
ip -br a
# or
hostname -I
```

### Firewall Rules (UDP Ports 7777 to 7780)
Open the required UDP ports in your firewall:

- **Using `ufw`:**
  ```bash
  sudo ufw allow 7777:7780/udp
  ```
- **Using `firewalld`:**
  ```bash
  sudo firewall-cmd --add-port=7777-7780/udp --permanent
  sudo firewall-cmd --reload
  ```
- **Using `nftables` / `iptables`:**
  ```bash
  sudo iptables -A INPUT -p udp --dport 7777:7780 -j ACCEPT
  ```
- **Default Arch installation (no firewall package installed):**
  Incoming UDP traffic is already accepted by default.

### Workaround: School Wi-Fi Client Isolation (Direct Hotspot)
Many school Wi-Fi networks enable **Client Isolation (AP Isolation)**, which blocks connected laptops and PCs from communicating with each other.

If students cannot ping or connect to your Arch laptop, create an ad-hoc Wi-Fi hotspot directly using NetworkManager:
```bash
nmcli device wifi hotspot ssid "NeumannGame" password "survival123"
```

Benefits:
- Bypasses the school router entirely.
- Zero firewall or port blocking.
- Ultra-low latency and zero packet loss.
- Students simply connect to the `NeumannGame` Wi-Fi network and enter the hotspot gateway IP (typically `192.168.12.1:7777`).

To stop the hotspot when finished:
```bash
nmcli connection down Hotspot
```

---

## 6. Resource Usage & Verification

On an Arch Linux system running native headless servers:
- **Idle CPU**: Less than 0.1% per room.
- **Active gameplay CPU**: ~2.5% of one CPU core per room.
- **RAM footprint**: ~38 MB to 41 MB per room.
- **Network bandwidth**: Sync rate of ~4 Hz ensures negligible bandwidth even with 10 players active.

Monitor running instances using `htop` or `ps`:
```bash
htop -p $(pgrep -d',' godot)
```
