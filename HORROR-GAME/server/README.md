# Empty School Co-op Server

Dedicated server setups for **The Empty School** multiplayer co-op sessions.

There are three ways to host a dedicated server:
1. **Native script** (direct Godot headless process on host)
2. **Docker container** (single room via Docker / Docker Compose)
3. **Virtual Machine appliance (.ova)** (multi-room Debian VM for school PCs and dedicated hosts)

---

## 1. Native Execution

Requires [Godot 4.7](https://godotengine.org/download) installed.

### Windows
```cmd
server\run-server.bat [--port 7777] [--max-players 4] [--public-host <ip>]
```
*If `godot` is not in your PATH, set the `GODOT` environment variable to the path of your Godot 4.7 executable.*

### Linux / macOS
```bash
server/run-server.sh [--port 7777] [--max-players 4] [--public-host <ip>]
```

---

## 2. Docker / Docker Compose

Runs a single containerized server instance:

```bash
# From the HORROR-GAME directory:
docker compose -f server/docker-compose.yml up --build
```

Environment variables configured in `server/docker-compose.yml`:
- `NEUMANN_PORT`: UDP port (default `7777`).
- `NEUMANN_MAX_PLAYERS`: Maximum players per room (default `4`).
- `NEUMANN_PUBLIC_HOST`: Optional external IP/hostname for join code generation.

---

## 3. Virtual Machine Appliance (.ova)

A minimal Debian 12 headless virtual machine running Docker with multiple isolated game rooms. Designed for plug-and-play hosting on school or club PCs.

See [`server/vm/GUIDE.md`](vm/GUIDE.md) for full deployment documentation.

### Prerequisites to Build the .ova
- **Oracle VirtualBox** (with `VBoxManage`)
- **HashiCorp Packer** (>= 1.10)
- **tar** (standard in Linux/macOS and Windows 10/11)
- Internet connection (downloads Debian 12 netinst ISO and Godot Linux binaries)
- ~10 GB free disk space

### Building the .ova

**On Windows:**
1. Install Packer if not already installed:
   ```cmd
   winget install Hashicorp.Packer
   ```
2. Build using PowerShell:
   ```powershell
   # From repository root (HORROR-GAME):
   .\server\vm\build-ova.ps1

   # Or if already inside server\vm:
   .\build-ova.ps1
   ```
   *(Or using CMD: `.\build-ova.bat` / in Git Bash: `./build-ova.sh`)*

**On Linux (Arch / Debian / Ubuntu):**
```bash
server/vm/build-ova.sh
```

*(Optional: specify RAM in MB as an argument, e.g. `server\vm\build-ova.bat 1024` or `server/vm/build-ova.sh 1024`)*

The build takes ~20 to 40 minutes and outputs:
```
server/vm/output/TheEmptySchoolServer.ova
```

### Importing into VirtualBox
1. Open VirtualBox and choose **File -> Import Appliance...**.
2. Select `server/vm/output/TheEmptySchoolServer.ova` and click **Import**.
3. Open VM **Settings -> Network -> Adapter 1**.
4. Set **Attached to** to **Bridged Adapter** and select the host's active network adapter (wired connection recommended).
5. Start the virtual machine.

### Console Display & Joining
Once booted (about 30 seconds), the VM console displays the IP address and room join codes:
```
Address: 192.168.1.50
Room 1: 192.168.1.50:7777   code 4535
Room 2: 192.168.1.50:7778   code 0699
Room 3: 192.168.1.50:7779   code 3742
Room 4: 192.168.1.50:7780   code 4146
```
Players select **Join Co-op** in-game and enter either the room code or `IP:PORT`.

### VM Configuration
Log into the VM console with credentials `neumann` / `neumann`:
- Room settings file: `/etc/neumann/rooms.conf` (`ROOMS`, `FIRST_PORT`, `MAX_PLAYERS`)
- Apply configuration changes:
  ```bash
  sudo systemctl restart neumann-rooms
  ```
- View room logs:
  ```bash
  sudo docker logs neumann-room-1
  ```
- Enable SSH remote access if needed:
  ```bash
  sudo systemctl enable --now ssh
  ```
