# Empty School server VM

This VM is a dedicated host for the co-op game. It boots into a running game server, with no desktop and no setup. Use it to host multiplayer sessions on school or club PCs without needing Godot installed on the host machine.

The VM runs Debian 12 (minimal) with Docker. It starts 4 isolated rooms by default (ports 7777 to 7780). Each room is a dedicated server on its own UDP port and supports up to 10 players (up to 40 players simultaneously across all 4 rooms).

## Status

The appliance `TheEmptySchoolServer.ova` has been built, imported into Oracle VirtualBox, and stress-tested with 40 concurrent players (10 players per room across all 4 rooms) covering Hide & Seek (Bot), Hide & Seek (Player Entity), Social Deduction, and the 5-day Co-op Campaign.

## Build the .ova (on your main PC before school)

Requirements: Packer (>= 1.10), VirtualBox (>= 7.0), internet access, about 10 GB free disk.

### Windows (PowerShell or CMD)
```powershell
# From the repository root (or HORROR-GAME):
.\server\vm\build-ova.ps1
# Or using CMD:
.\server\vm\build-ova.bat
```

### Linux (Arch / Debian / Ubuntu)
```bash
server/vm/build-ova.sh
```

The script packages the game context, installs Debian 12 unattended, installs Docker, and builds the container image. The resulting appliance is written to:
```
server/vm/output/TheEmptySchoolServer.ova (~574 MB)
```
*(Do not commit this file to git: at ~574 MB it exceeds GitHub's 100 MB limit and is ignored by `.gitignore`.)*

---

## USB Pendrive Checklist for School Deployment

Prepare your USB drive at home before going to school:

1. **`TheEmptySchoolServer.ova`** (~574 MB):
   - Located in `server/vm/output/`.
2. **Pre-built Game Client (`TheEmptySchool.exe`)**:
   - **Never build the game at school.** School PCs usually lack admin privileges, have no Godot engine or export templates installed, and have firewall restrictions that block downloading dependencies.
   - Build the game client before you leave using:
     ```powershell
     $GODOT --headless --path . --export-release "Windows Desktop" "build/windows/TheEmptySchool.exe"
     ```
   - Copy the `build/windows/` folder to the USB drive. It is a single standalone executable with embedded `.pck` that runs immediately on any Windows 10/11 school PC without installation.
3. **VirtualBox Installer** (optional safety fallback):
   - Keep a copy of `VirtualBox-7.x.x-Win.exe` on the drive in case the teacher PC does not have VirtualBox pre-installed.

---

## Setup on the Teacher PC

1. If VirtualBox is not yet installed, install it on the teacher PC.
2. Open VirtualBox, select **File -> Import Appliance...**, choose `TheEmptySchoolServer.ova`, and click **Import**.
3. Open VM **Settings -> Network -> Adapter 1**:
   - Set **Attached to** to **Bridged Adapter**.
   - Select the PC's active network adapter (the wired Ethernet controller is strongly recommended, though Wi-Fi also works).
4. Start the VM. Within ~20–30 seconds, the console screen displays the server IP and 4-digit room codes:

```text
  The Empty School server
  Address: 192.168.1.50
  4 rooms, up to 10 players each.

  Room 1: 192.168.1.50:7777   code 4535
  Room 2: 192.168.1.50:7778   code 0699
  Room 3: 192.168.1.50:7779   code 3742
  Room 4: 192.168.1.50:7780   code 4146

  Players join with the address and port, or with the room code.
```

Leave the VM running (it can be minimized). No graphical login is required.

---

## How Students Join

1. Copy `TheEmptySchool.exe` from your USB drive to the student PCs (or run it directly from the drive).
2. Launch `TheEmptySchool.exe`.
3. In the main menu, click **Join Co-op**.
4. Enter either:
   - The **4-digit room code** (e.g. `4535` for Room 1) — automatically resolves via LAN broadcast.
   - The direct **IP and Port** (e.g. `192.168.1.50:7777`).
5. Tell Group 1 to join Room 1, Group 2 to join Room 2, etc.

---

## Performance & Optimization for Weak School PCs

For students playing on low-spec school PCs with integrated graphics:
- Open **Settings** in the game menu.
- Under **GRAPHICS & PERFORMANCE**:
  - Set **Quality Preset** to **Low**.
  - Turn **Real-time lamps** to **Off** (uses fast flat ambient lighting, giving the biggest FPS boost).
  - Set **Render Scale** to **60%–75%**.
  - Enable **VSync** or set an **FPS Limit** of 30 or 60 to prevent thermal throttling.

---

## Server Resource Consumption (Measured)

Tested with 40 simultaneous active players across all 4 rooms:
- **CPU**: ~2.5% per active room container (~10.3% total VM CPU usage at 40 concurrent players on 1 vCPU).
- **RAM**: ~38–41 MB per room container (~160 MB total for all 4 containers combined). The entire minimal Debian VM uses only ~600 MB of its 1024 MB allocation.
- **Network**: Low bandwidth update rate (~4 Hz throttled transform sync) ensures smooth gameplay even over congested school Wi-Fi.

---

## Troubleshooting & Maintenance

- **Network IP / DHCP**: The VM IP address is assigned via DHCP. If the teacher PC moves to another network or router, restart the VM or run:
  ```bash
  sudo systemctl restart neumann-rooms
  ```
- **Console / SSH Access**:
  - Default user: `neumann` / password: `neumann`
  - SSH remote access:
    ```bash
    sudo systemctl enable --now ssh
    ```
- **Customizing Rooms**:
  Edit `/etc/neumann/rooms.conf` inside the VM:
  ```ini
  ROOMS=4
  FIRST_PORT=7777
  MAX_PLAYERS=10
  ```
- **View Live Logs**:
  ```bash
  sudo docker logs -f neumann-room-1
  ```
