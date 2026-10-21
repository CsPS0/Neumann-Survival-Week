# School Server VM & Student Setup Guide

This guide covers setting up and running the multi-room dedicated server appliance (**The Empty School Server VM**) on a teacher's PC and configuring student PCs for classroom multiplayer sessions.

---

## Overview

The school server VM is a lightweight, pre-configured **Debian 12 VirtualBox appliance (`.ova`)** running Docker. When booted, it automatically starts **4 dedicated server containers**, one per room, listening on UDP ports `7777` to `7780`. Each room supports up to 10 players.

- **Teacher PC**: Runs the headless VM inside VirtualBox. No Godot installation or command-line gaming knowledge required.
- **Student PCs**: Run the standalone Windows executable (`TheEmptySchool.exe`). No installation, Godot, or admin rights required.

---

## 1. Preparation (At Home, Before Class)

> [!IMPORTANT]
> Always build the `.ova` and prepare your USB drive at home. School networks often block large downloads, package repositories, or have restricted bandwidth.

### Build the `.ova` Appliance
Prerequisites: Oracle VirtualBox 7.x+, HashiCorp Packer 1.10+, and ~10 GB free disk space.

Run the build script from the `HORROR-GAME/` directory:

| OS / Shell | Command |
|---|---|
| **Windows (PowerShell)** | `.\server\vm\build-ova.ps1` *(install Packer first: `winget install Hashicorp.Packer`)* |
| **Windows (CMD)** | `.\server\vm\build-ova.bat` |
| **Linux / Git Bash** | `server/vm/build-ova.sh` *(optionally pass RAM in MB, e.g. `server/vm/build-ova.sh 2048`)* |

The output appliance will be created at:
```text
server/vm/output/TheEmptySchoolServer.ova (~574 MB)
```
*(Note: The build process automatically excludes `scripts/staff.gd`, so no real teacher names are included in the server image.)*

### Prepare the USB Drive
Copy the following files onto a USB flash drive:
1. `TheEmptySchoolServer.ova`
2. `build/windows/TheEmptySchool.exe` (the standalone player client)
3. VirtualBox 7.x Windows installer (optional fallback, if VirtualBox is not pre-installed on the teacher's PC)

---

## 2. Teacher PC: Installing and Running the VM

### Step 1: Install VirtualBox
If VirtualBox is not already installed on the teacher's PC, install Oracle VirtualBox 7.x. Ensure hardware virtualization (VT-x or AMD-V) is enabled in the PC's BIOS/UEFI.

### Step 2: Import the Appliance
1. Open VirtualBox.
2. Go to **File** → **Import Appliance...** (or press `Ctrl+I`).
3. Select `TheEmptySchoolServer.ova` from the USB drive and click **Next**, then **Import**.

### Step 3: Configure Bridged Networking (Critical)
The VM must have its own IP address on the school local network so students can reach it directly.

1. In VirtualBox, select **TheEmptySchoolServer** and click **Settings** (`Ctrl+S`).
2. Navigate to **Network** → **Adapter 1**.
3. Set **Attached to:** to **Bridged Adapter**.
4. In the **Name** dropdown, select the PC's **active network card** (wired Ethernet is strongly recommended; if on Wi-Fi, select the active Wi-Fi adapter).
5. Click **OK**.

> [!WARNING]
> Do **not** leave the network mode on `NAT`. NAT isolates the VM behind the teacher's PC, preventing students from connecting.

### Step 4: Start the Server
1. Select the VM and click **Start**.
2. Wait 20 to 30 seconds for the Debian system and Docker containers to initialize.
3. The VM console will display the status banner with the assigned IP and room join codes:

```text
  The Empty School server
  Address: 192.168.1.50
  4 rooms, up to 10 players each.

  Room 1: 192.168.1.50:7777   code 4535
  Room 2: 192.168.1.50:7778   code 0699
  Room 3: 192.168.1.50:7779   code 3742
  Room 4: 192.168.1.50:7780   code 4146
```

4. Leave the VM running in the background. You can minimize its window. No login is needed to keep the servers active.
5. Write down the **Address** and room ports for the students.

---

## 3. Student PCs: Setup and Joining

### Distribute the Game Client
Copy `TheEmptySchool.exe` to each student PC (e.g. via USB stick, local network share, or Desktop). It runs portably with no installation required.

### Performance Settings for Weak School Hardware
School desktop PCs often rely on older integrated graphics (Intel HD Graphics). Recommend these settings:

1. Launch `TheEmptySchool.exe`.
2. Go to **Settings** → **Graphics**:
   - **Preset**: `Low`
   - **Real-time lamps**: `Off` *(biggest performance boost: replaces expensive spot shadows with ambient illumination)*
   - **Render scale**: `60%` – `75%`
   - **VSync**: `On` (or set an FPS limit of `30` or `60`)
   - **Anti-aliasing**: `Off`
3. *Fallback for legacy GPUs*: If the game fails to boot or lags on Vulkan, create a shortcut to `TheEmptySchool.exe` with arguments:
   ```cmd
   TheEmptySchool.exe --rendering-method gl_compatibility --rendering-driver opengl3
   ```

### Joining a Room
1. From the main menu, click **Join Co-op**.
2. Connect to the designated room:
   - **Preferred method (Direct IP & Port)**: Type the VM's address and room port (e.g. `192.168.1.50:7777`) and click **Join**.
   - **Alternative (Room code)**: If local UDP broadcast is not blocked by the school router, enter the 4-digit code shown on the teacher's screen.
3. Assign student groups to specific rooms to avoid overcrowding:
   - **Group 1**: Room 1 (`<IP>:7777`)
   - **Group 2**: Room 2 (`<IP>:7778`)
   - **Group 3**: Room 3 (`<IP>:7779`)
   - **Group 4**: Room 4 (`<IP>:7780`)
4. Once students are in the lobby, any student can select and start a game mode (**Hide and Seek**, **Social Deduction**, or **Campaign Co-op**). See [Multiplayer Modes](multiplayer-modes.md) for rules.

---

## 4. VM Management and Configuration

If you need to reconfigure or inspect the VM, log in at the VirtualBox console:
- **Username:** `neumann`
- **Password:** `neumann`

### Management Commands

| Task | Command |
|---|---|
| Edit room count / ports / capacity | `sudo nano /etc/neumann/rooms.conf` |
| Restart server rooms | `sudo systemctl restart neumann-rooms` |
| View live logs for Room 1 | `sudo docker logs -f neumann-room-1` |
| Check VM network IP | `ip -br a` |
| Enable SSH (disabled by default) | `sudo systemctl enable --now ssh` |

### Configuration File (`/etc/neumann/rooms.conf`)
```ini
ROOMS=4
FIRST_PORT=7777
MAX_PLAYERS=10
```
After modifying this file, apply the changes with:
```bash
sudo systemctl restart neumann-rooms
```

---

## 5. Troubleshooting & FAQ

| Problem | Cause | Solution |
|---|---|---|
| **Console displays "No network address yet"** | Adapter is not bridged or the physical cable is disconnected. | Open VM Settings → Network → Adapter 1. Verify Attached to is **Bridged Adapter** and bound to the active adapter. Run `sudo systemctl restart neumann-rooms`. |
| **Students cannot reach the server IP** | Windows Firewall on the teacher's PC is blocking inbound UDP. | In Windows Defender Firewall, allow incoming UDP traffic on ports `7777` through `7780`, or temporarily allow VirtualBox. |
| **"No room 1234 found on this network"** | School router has Wi-Fi Client Isolation or blocks UDP broadcast (port 7778). | Join directly using the VM's IP address and port (e.g. `192.168.1.50:7777`) instead of the 4-digit code. |
| **VirtualBox shows VT-x / AMD-V disabled error** | Hardware virtualization is disabled in BIOS, or Hyper-V is conflicting. | Enter PC BIOS/UEFI during boot and enable Intel Virtualization Technology (VT-x) or AMD-V. |
| **IP address changed after relocating the laptop** | DHCP assigned a new IP address on a different network. | Run `sudo systemctl restart neumann-rooms` in the VM console to refresh the banner with the new IP. |
| **A room shows as full** | Player count reached `MAX_PLAYERS` (default 10). | Have students join another room (ports 7778, 7779, 7780), or edit `/etc/neumann/rooms.conf` to increase `MAX_PLAYERS`. |
| **Low FPS / stuttering on student PCs** | Hardware graphics capabilities exceeded. | In the in-game Settings → Graphics, set Preset to **Low** and turn **Real-time lamps** to **Off**. |
