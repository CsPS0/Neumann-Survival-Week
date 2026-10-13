# The Empty School: build guide

One-line build commands for the Godot game in `HORROR-GAME`. Written 2026-10-13 against `main` at fb7cdd3.

Targets: Linux, Windows, macOS, Windows VR, Meta Quest VR (APK) and phone (Android APK). Each target has commands for an Arch Linux machine and for a Windows machine.

## What was checked

- Checked against the repo: `.github/workflows/release.yml`, `.github/godot/export_presets.ci.cfg`, `HORROR-GAME/server/`, the earlier thread "Check main and Arch build steps", and your local copies of `HORROR-GAME/AGENTS.md`, `HORROR-GAME/build/README.txt` and `HORROR-GAME/export_presets.cfg`.
- `HORROR-GAME/export_presets.cfg` and `HORROR-GAME/AGENTS.md` are gitignored. A fresh clone does not contain them. The CI preset file in `.github/godot/` is the tracked copy.
- Verified earlier on Linux (thread "Check main and Arch build steps", Godot 4.7.2): Linux and Windows exports, and the Linux build booting headless.
- Not verified anywhere: macOS, Windows VR, Android and Quest exports, and every Windows-machine command. Each is marked "Not verified" below.

## Prerequisites

| Item | Needed for | Detail |
|---|---|---|
| Godot 4.7.2 standard build (not .NET) | All targets | Your install: `/home/csps/Godot_v4.7.2-stable_linux.x86_64` on Arch. The CI workflow pins 4.7 stable, so CI builds use the 4.7 templates. |
| Export templates matching the editor version exactly | All targets | Folder name must be `4.7.2.stable`. Download is about 1.2 GB. You already installed them on Arch. |
| `export_presets.cfg` in `HORROR-GAME` | All targets | See the next section. |
| Local-only files | Real names and faces | `scripts/staff.gd`, `scripts/student_faces_local.gd`, `assets/faces_local/` and `assets/photos_local/aula.jpg`. Without them the build uses placeholders. The export packs whatever is on disk. |
| JDK 17 | Android and Quest | Arch package `jdk17-openjdk`. |
| Android SDK with platform-tools, build-tools 35.0.1 and platform android-35 | Android and Quest | The presets build with Gradle off, so cmake and the NDK are not needed. Arch: AUR packages `android-sdk` and `android-sdk-cmdline-tools-latest`, then run `sudo /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk "platform-tools" "build-tools;35.0.1" "platforms;android-35"`. |
| Debug keystore | Android and Quest debug builds | Created once with `keytool`, see below. |
| Release keystore | Android and Quest release builds | Your own keystore. Never commit it. |
| Vulkan driver | Running the Linux build | Required to start the game. |

The macOS export has no extra prerequisite on Linux or Windows. The result is unsigned and not notarized. A Mac needs a Gatekeeper override to open it.

## Quickest route: the build scripts

Two scripts do Steps 1 to 3 below for you. They live in `HORROR-GAME/tools/` on `main` (merged in PR 27).

- They find Godot, check the version is 4.7.x and check the export templates.
- They copy the CI presets into `HORROR-GAME/export_presets.cfg` when the file is missing.
- They import the project on the first run, export each target and print a Built, Skipped and Failed summary.
- They print a clear message and stop when Godot or the templates are missing. Add `--install-templates` to download the templates (about 1.2 GB).
- Android and Quest targets are skipped with a reason when the SDK, JDK or keystore is missing. On the first run they create the debug keystore and the Godot Android settings file when neither exists.

Arch, Linux and macOS. The default targets are linux, windows and windows-vr:

```
GODOT=/home/csps/Godot_v4.7.2-stable_linux.x86_64 ./tools/build.sh
```

Other forms: `./tools/build.sh all`, `./tools/build.sh linux quest`, `./tools/build.sh --install-templates desktop`, `./tools/build.sh --release android`. Run them from `HORROR-GAME`.

Windows, in PowerShell or cmd, from `HORROR-GAME`:

```
$env:GODOT="C:\Godot\Godot_v4.7.2-stable_win64_console.exe"; .\tools\build.bat
```

In cmd use `set GODOT=...` and then `tools\build.bat`. Other forms: `tools\build.bat all`, `tools\build.bat linux quest`, `tools\build.bat --install-templates desktop`.

Tested: on your Arch machine (2026-10-13) `build.sh` built Linux, Windows, and the phone and Quest debug APKs with Godot 4.7.2. The Windows VR, macOS and Windows PowerShell paths are untested. `build.bat` has not run at all.

Android notes from that run:
- The Android CLI replaced `sdkmanager`. Packages needed: platform-tools, build-tools 35.0.1 and platforms android-35. Gradle is off, so cmake and the NDK are not needed.
- A root-owned SDK in `/opt/android-sdk` needs `sudo chmod -R a+rX /opt/android-sdk` so your user can run adb and apksigner.
- Godot 4.7 reads `~/.config/godot/editor_settings-4.7.tres`. The script fills that file.
- The line "cannot connect to daemon at tcp:5037" at the end of the phone build is harmless. It means no adb server is running.

The manual steps follow for reference.

## Step 1: get the presets file

Use the tracked CI preset file. It holds Linux/X11, Windows Desktop, Windows VR, Android and Android VR (Quest). It has no macOS preset.

Arch:

```
cp /home/csps/REPOS/Neumann-Survival-Week/.github/godot/export_presets.ci.cfg /home/csps/REPOS/Neumann-Survival-Week/HORROR-GAME/export_presets.cfg
```

Windows (PowerShell):

```
Copy-Item .\.github\godot\export_presets.ci.cfg .\HORROR-GAME\export_presets.cfg
```

Your own local `export_presets.cfg` already has all six presets including `macOS`. If you have it, skip this step. A copy sits in the project files at `Neumann-Survival-Week/HORROR-GAME/export_presets.cfg`. Overwriting it with the CI file removes the macOS preset.

## Step 2: set the Godot path and import once

Arch:

```
export GODOT=/home/csps/Godot_v4.7.2-stable_linux.x86_64; cd /home/csps/REPOS/Neumann-Survival-Week/HORROR-GAME && $GODOT --headless --path . --import
```

Windows (PowerShell). Use the `_console.exe` build of Godot so output appears in the terminal. Adjust the path to where you unpacked it:

```
$env:GODOT = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"; cd C:\REPOS\Neumann-Survival-Week\HORROR-GAME; & $env:GODOT --headless --path . --import
```

Windows export templates folder: `%APPDATA%\Godot\export_templates\4.7.2.stable`. Install them from the editor menu Editor, Manage Export Templates, Download and Install. Not verified on Windows.

Run the import once per fresh checkout. All commands below run from `HORROR-GAME`.

## Step 3: build commands

Each command creates its output folder first. Output goes to `build/`, which is gitignored. Do not commit it.

### Linux

Arch (verified):

```
mkdir -p build/linux && $GODOT --headless --path . --export-release "Linux/X11" build/linux/TheEmptySchool.x86_64
```

Windows (PowerShell, not verified):

```
New-Item -ItemType Directory -Force build\linux | Out-Null; & $env:GODOT --headless --path . --export-release "Linux/X11" build/linux/TheEmptySchool.x86_64
```

Run on Arch: `./build/linux/TheEmptySchool.x86_64`. Output is a single file of about 75 MB.

### Windows

Arch (verified):

```
mkdir -p build/windows && $GODOT --headless --path . --export-release "Windows Desktop" build/windows/TheEmptySchool.exe
```

Windows (PowerShell, not verified):

```
New-Item -ItemType Directory -Force build\windows | Out-Null; & $env:GODOT --headless --path . --export-release "Windows Desktop" build/windows/TheEmptySchool.exe
```

Output is a single file of about 111 MB. The `embed_pck` option is on, so no `.pck` file ships beside it. The build is unsigned. SmartScreen shows a warning, as `build/README.txt` states.

### macOS

Needs the `macOS` preset from your local `export_presets.cfg`. The CI file does not contain it. Not verified.

Arch:

```
mkdir -p build/macos && $GODOT --headless --path . --export-release "macOS" build/macos/TheEmptySchool.zip
```

Windows (PowerShell):

```
New-Item -ItemType Directory -Force build\macos | Out-Null; & $env:GODOT --headless --path . --export-release "macOS" build/macos/TheEmptySchool.zip
```

The preset sets architecture `universal`, codesign off and notarization off. On a Mac, remove the quarantine flag after unzipping: `xattr -cr TheEmptySchool.app`.

### Windows VR

Needs the `Windows VR` preset. Both preset files contain it. Not verified here. The release workflow runs this exact export.

Arch:

```
mkdir -p build/vr && $GODOT --headless --path . --export-release "Windows VR" build/vr/TheEmptySchool_VR.exe
```

Windows (PowerShell):

```
New-Item -ItemType Directory -Force build\vr | Out-Null; & $env:GODOT --headless --path . --export-release "Windows VR" build/vr/TheEmptySchool_VR.exe
```

### Android phone APK

Needs JDK 17, the Android SDK and a keystore. Not verified. The Arch and Windows commands below match what `release.yml` and `HORROR-GAME/AGENTS.md` describe.

One-time setup on Arch. This creates the debug keystore and tells Godot where Java and the SDK are. Adjust the two paths to your install:

```
keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Then open the Godot editor once, go to Editor, Editor Settings, Export, Android, and set Java SDK Path, Android SDK Path and the debug keystore (`~/.android/debug.keystore`, user `androiddebugkey`, password `android`). The release workflow writes the same settings into `~/.config/godot/editor_settings-4.tres`. On Windows the file is `%APPDATA%\Godot\editor_settings-4.tres`.

Debug build, Arch:

```
mkdir -p build/mobile && $GODOT --headless --path . --export-debug "Android" build/mobile/TheEmptySchool.apk
```

Debug build, Windows (PowerShell):

```
New-Item -ItemType Directory -Force build\mobile | Out-Null; & $env:GODOT --headless --path . --export-debug "Android" build/mobile/TheEmptySchool.apk
```

Release build, Arch. Godot reads the release keystore from three environment variables. This is how CI signs:

```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore GODOT_ANDROID_KEYSTORE_RELEASE_USER=youralias GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='yourpassword' $GODOT --headless --path . --export-release "Android" build/mobile/TheEmptySchool.apk
```

Release build, Windows (PowerShell):

```
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH="C:\keys\release.keystore"; $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER="youralias"; $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="yourpassword"; & $env:GODOT --headless --path . --export-release "Android" build/mobile/TheEmptySchool.apk
```

Install on a phone with USB debugging on: `adb install -r build/mobile/TheEmptySchool.apk`. The preset builds `arm64-v8a` only, with package name `hu.njszki.theemptyschool` and Gradle off.

### Meta Quest VR APK

Same prerequisites and the same setup as the phone APK. The preset `Android VR (Quest)` sets `xr_mode=1` (OpenXR), `arm64-v8a` only and package name `hu.njszki.theemptyschoolvr`. Not verified.

Debug build, Arch:

```
mkdir -p build/vr && $GODOT --headless --path . --export-debug "Android VR (Quest)" build/vr/TheEmptySchool_Quest.apk
```

Debug build, Windows (PowerShell):

```
New-Item -ItemType Directory -Force build\vr | Out-Null; & $env:GODOT --headless --path . --export-debug "Android VR (Quest)" build/vr/TheEmptySchool_Quest.apk
```

Release build: use the phone release commands with `"Android VR (Quest)"` and the output `build/vr/TheEmptySchool_Quest.apk`.

Install on a Quest in developer mode: `adb install -r build/vr/TheEmptySchool_Quest.apk`.

## Build everything in one line

Arch. Builds Linux, Windows and Windows VR. It stops at the first failure. Verified for the first two targets only:

```
mkdir -p build/linux build/windows build/vr && $GODOT --headless --path . --export-release "Linux/X11" build/linux/TheEmptySchool.x86_64 && $GODOT --headless --path . --export-release "Windows Desktop" build/windows/TheEmptySchool.exe && $GODOT --headless --path . --export-release "Windows VR" build/vr/TheEmptySchool_VR.exe
```

Windows (PowerShell, not verified):

```
"build\linux","build\windows","build\vr" | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }; & $env:GODOT --headless --path . --export-release "Linux/X11" build/linux/TheEmptySchool.x86_64; & $env:GODOT --headless --path . --export-release "Windows Desktop" build/windows/TheEmptySchool.exe; & $env:GODOT --headless --path . --export-release "Windows VR" build/vr/TheEmptySchool_VR.exe
```

## Build on GitHub instead

The release workflow builds Linux, Windows, Windows VR, Android and Quest in the cloud. It runs only when you push a tag that starts with `demo` or `v`. Branch pushes and pull requests never start it.

```
git tag demo-1.1 && git push origin demo-1.1
```

- The workflow uses Godot 4.7 stable and the CI preset file.
- The Android and Quest jobs run only when three repository secrets exist: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER` and `ANDROID_KEYSTORE_PASSWORD`. Without them the jobs skip and the release still publishes the desktop files.
- The workflow builds no macOS target.
- Use a tag name without spaces, for example `demo-1.1` or `v1.1`.

## Headless server

`HORROR-GAME/server/run-server.sh`, `run-server.bat`, `Dockerfile` and `docker-compose.yml` start the dedicated co-op server. They are not part of the game builds above. Read the scripts before use. They were not checked for this guide.

## Common errors

- `This project doesn't have an export_presets.cfg file at its root`: run Step 1.
- `No export template found`: the template folder name differs from the editor version. For editor 4.7.2 the folder must be `4.7.2.stable`.
- The build shows placeholder names or faces: the local-only files are missing from `HORROR-GAME`.
- Single-script `--check-only` reports `Identifier not found: NetSession`. This is a limit of that check. The full headless boot loads the autoloads and runs clean.
