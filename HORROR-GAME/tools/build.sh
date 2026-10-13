#!/usr/bin/env bash
# Builds The Empty School on Linux or macOS.
# Usage: tools/build.sh [options] [target ...]
# Targets: linux windows windows-vr macos android quest. Groups: desktop (default) and all.
# Options: --install-templates  download the export templates when they are missing
#          --release            sign Android builds with a release keystore (see below)
#          --help               show this text
# Environment: GODOT                           path to the Godot 4.7 binary
#              GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER, _PASSWORD  for --release
# Output goes to build/<platform>/ and is never committed.
set -u

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(cd "$project_dir/.." && pwd)"
ci_presets="$repo_dir/.github/godot/export_presets.ci.cfg"
presets="$project_dir/export_presets.cfg"
os="$(uname -s)"
install_templates=0
release=0
targets=()

for arg in "$@"; do
	case "$arg" in
		--install-templates) install_templates=1 ;;
		--release) release=1 ;;
		--help | -h) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		desktop) targets+=(linux windows windows-vr) ;;
		all) targets+=(linux windows windows-vr macos android quest) ;;
		linux | windows | windows-vr | macos | android | quest) targets+=("$arg") ;;
		*) echo "Unknown argument: $arg. Run tools/build.sh --help." >&2; exit 2 ;;
	esac
done
[ ${#targets[@]} -eq 0 ] && targets=(linux windows windows-vr)

fail() { echo "ERROR: $*" >&2; exit 1; }

# 1. Find Godot.
find_godot() {
	local c
	if [ -n "${GODOT:-}" ]; then echo "$GODOT"; return; fi
	for c in godot godot4; do command -v "$c" 2>/dev/null && return; done
	for c in "$HOME"/Godot_v4.7*_linux.x86_64 "$HOME"/godot/Godot_v4.7*_linux.x86_64 \
		/Applications/Godot.app/Contents/MacOS/Godot; do
		[ -x "$c" ] && { echo "$c"; return; }
	done
}
godot="$(find_godot)"
[ -n "$godot" ] && command -v "$godot" >/dev/null 2>&1 ||
	fail "Godot was not found. Install Godot 4.7.x (standard build) or set GODOT to its path."
full_version="$("$godot" --version 2>/dev/null | head -n 1)"
version="$(echo "$full_version" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z0-9]+).*/\1/')"
case "$version" in 4.7*) ;; *) fail "Godot 4.7.x is required. Found: ${full_version:-unknown}" ;; esac
echo "Godot: $godot ($full_version)"

# 2. Check the export templates.
if [ "$os" = "Darwin" ]; then
	tpl_root="$HOME/Library/Application Support/Godot/export_templates"
else
	tpl_root="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
fi
tpl_dir="$tpl_root/$version"
if [ ! -f "$tpl_dir/version.txt" ]; then
	tag="${version%.*}-${version##*.}"
	url="https://github.com/godotengine/godot-builds/releases/download/$tag/Godot_v$tag""_export_templates.tpz"
	if [ "$install_templates" -eq 1 ]; then
		echo "Downloading export templates (about 1.2 GB) from $url"
		tmp="$(mktemp -d)"
		curl -fL -o "$tmp/templates.tpz" "$url" && unzip -q "$tmp/templates.tpz" -d "$tmp" ||
			{ rm -rf "$tmp"; fail "Template download failed. Install them from the editor: Editor, Manage Export Templates."; }
		mkdir -p "$tpl_dir" && cp -r "$tmp"/templates/* "$tpl_dir/"
		rm -rf "$tmp"
	else
		fail "Export templates for $version are missing. Run again with --install-templates, or download $url and unpack its templates folder into: $tpl_dir"
	fi
fi
echo "Templates: $tpl_dir"

# 3. Make sure the presets file exists.
if [ ! -f "$presets" ]; then
	[ -f "$ci_presets" ] || fail "Neither $presets nor $ci_presets exists."
	cp "$ci_presets" "$presets"
	echo "Copied the CI presets to HORROR-GAME/export_presets.cfg (gitignored)."
fi
# Append any requested preset that an older or partial export_presets.cfg lacks.
preset_name() {
	case "$1" in
		linux) echo "Linux/X11" ;; windows) echo "Windows Desktop" ;; windows-vr) echo "Windows VR" ;;
		macos) echo "macOS" ;; android) echo "Android" ;; quest) echo "Android VR (Quest)" ;;
	esac
}
for t in "${targets[@]}"; do
	pname="$(preset_name "$t")"
	grep -qF "name=\"$pname\"" "$presets" && continue
	[ -f "$ci_presets" ] && grep -qF "name=\"$pname\"" "$ci_presets" || continue
	n=$(grep -c '^\[preset\.[0-9]*\]$' "$presets")
	awk -v want="$pname" -v newn="$n" '
		/^\[preset\.[0-9]+(\.options)?\]$/ { match($0, /[0-9]+/); cur = substr($0, RSTART, RLENGTH) }
		{ lines[cur] = lines[cur] $0 "\n" }
		/^name=/ { nm = $0; sub(/^name="/, "", nm); sub(/"$/, "", nm); names[cur] = nm }
		END { for (i in names) if (names[i] == want) {
			s = lines[i]
			gsub("\\[preset\\." i "\\]", "[preset." newn "]", s)
			gsub("\\[preset\\." i "\\.options\\]", "[preset." newn ".options]", s)
			printf "\n%s", s } }' "$ci_presets" >> "$presets"
	echo "Added the \"$pname\" preset to HORROR-GAME/export_presets.cfg."
done
if printf '%s\n' "${targets[@]}" | grep -qx macos && ! grep -q 'name="macOS"' "$presets"; then
	n=$(grep -c '^\[preset\.[0-9]*\]$' "$presets")
	cat >> "$presets" <<PRESET

[preset.$n]

name="macOS"
platform="macOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="docs/*, build/*, *.md"
export_path="build/macos/TheEmptySchool.zip"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.$n.options]

custom_template/debug=""
custom_template/release=""
application/icon=""
application/icon_interpolation=4
application/bundle_identifier="hu.njszki.theemptyschool"
application/signature=""
application/short_version="1.0"
application/version="1.0"
application/copyright=""
application/copyright_year=""
display/high_res=true
xcode/codesign/enable=false
xcode/notarization/enable=false
privacy/camera_usage_description=""
privacy/microphone_usage_description=""
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="universal"
PRESET
	echo "Added a macOS preset to HORROR-GAME/export_presets.cfg."
fi

# 4. Android prerequisites, only when an Android target is requested.
android_ok=1
if printf '%s\n' "${targets[@]}" | grep -qE '^(android|quest)$'; then
	sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
	[ -z "$sdk" ] && for c in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" /opt/android-sdk; do [ -d "$c" ] && sdk="$c" && break; done
	java_home="${JAVA_HOME:-}"
	[ -z "$java_home" ] && command -v javac >/dev/null 2>&1 &&
		java_home="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
	settings="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-4.tres"
	[ "$os" = "Darwin" ] && settings="$HOME/Library/Application Support/Godot/editor_settings-4.tres"
	if [ -z "$sdk" ] || [ ! -d "$sdk" ]; then
		echo "SKIP android/quest: Android SDK not found. Set ANDROID_HOME (needs platform-tools, build-tools 35.0.1, platforms;android-35, cmake 3.10.2.4988893, ndk 28.1.13356709)."; android_ok=0
	elif [ -z "$java_home" ]; then
		echo "SKIP android/quest: JDK 17 not found. Install it or set JAVA_HOME."; android_ok=0
	else
		if [ "$release" -eq 1 ]; then
			for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
				[ -n "${!v:-}" ] || { echo "SKIP android/quest: $v is not set for --release."; android_ok=0; }
			done
		else
			dk="$HOME/.android/debug.keystore"
			if [ ! -f "$dk" ]; then
				mkdir -p "$HOME/.android"
				"$java_home/bin/keytool" -genkey -v -keystore "$dk" -storepass android -alias androiddebugkey -keypass android \
					-keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 ||
					{ echo "SKIP android/quest: could not create the debug keystore."; android_ok=0; }
			fi
			export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$dk" GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
		fi
		if [ "$android_ok" -eq 1 ] && { [ ! -x "$sdk/platform-tools/adb" ] || ! ls "$sdk"/build-tools/*/apksigner >/dev/null 2>&1; }; then
			echo "SKIP android/quest: $sdk has no installed build-tools or platform-tools (adb and apksigner are missing). Install them with sdkmanager --sdk_root=$sdk \"platform-tools\" \"build-tools;35.0.1\" \"platforms;android-35\" \"cmake;3.10.2.4988893\" \"ndk;28.1.13356709\" (use sudo for /opt/android-sdk)."; android_ok=0
		fi
		if [ "$android_ok" -eq 1 ]; then
			# Fill the Godot editor settings when a value is missing, empty or points to a missing path.
			mkdir -p "$(dirname "$settings")"
			[ -f "$settings" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$settings"
			ensure_setting() { # key value check (file to test inside the path, or "none")
				local cur
				cur="$(awk -F' = ' -v k="$1" '$1 == k { gsub(/^"|"$/, "", $2); print $2; exit }' "$settings")"
				if [ -n "$cur" ] && { [ "$3" = none ] || [ -e "$cur/$3" ] || { [ "$3" = self ] && [ -e "$cur" ]; }; }; then return; fi
				if grep -q "^$1 = " "$settings"; then
					sed -i "s|^$1 = .*|$1 = \"$2\"|" "$settings"
				else
					printf '%s = "%s"\n' "$1" "$2" >> "$settings"
				fi
				echo "Set $1 in $settings"
			}
			ensure_setting export/android/java_sdk_path "$java_home" bin/javac
			ensure_setting export/android/android_sdk_path "$sdk" platform-tools/adb
			ensure_setting export/android/debug_keystore "$HOME/.android/debug.keystore" self
			ensure_setting export/android/debug_keystore_user androiddebugkey none
			ensure_setting export/android/debug_keystore_pass android none
		fi
	fi
fi

# 5. Import, then export.
cd "$project_dir" || exit 1
if [ ! -d .godot ]; then
	echo "Importing the project (first run)."
	"$godot" --headless --path . --import >/dev/null 2>&1 || true
fi

built=(); failed=(); skipped=()
export_one() { # name preset output kind
	local name="$1" preset="$2" out="$3" kind="$4"
	mkdir -p "$(dirname "$out")"
	echo "== $name"
	if "$godot" --headless --path . "$kind" "$preset" "$out" && [ -f "$out" ]; then
		built+=("$name: $out")
	else
		failed+=("$name")
	fi
}
for t in "${targets[@]}"; do
	android_kind="--export-debug"; [ "$release" -eq 1 ] && android_kind="--export-release"
	case "$t" in
		linux) export_one linux "Linux/X11" build/linux/TheEmptySchool.x86_64 --export-release ;;
		windows) export_one windows "Windows Desktop" build/windows/TheEmptySchool.exe --export-release ;;
		windows-vr) export_one windows-vr "Windows VR" build/vr/TheEmptySchool_VR.exe --export-release ;;
		macos) export_one macos "macOS" build/macos/TheEmptySchool.zip --export-release ;;
		android) if [ "$android_ok" -eq 1 ]; then export_one android "Android" build/mobile/TheEmptySchool.apk "$android_kind"; else skipped+=(android); fi ;;
		quest) if [ "$android_ok" -eq 1 ]; then export_one quest "Android VR (Quest)" build/vr/TheEmptySchool_Quest.apk "$android_kind"; else skipped+=(quest); fi ;;
	esac
done

echo
echo "Built:   ${built[*]:-none}"
echo "Skipped: ${skipped[*]:-none}"
echo "Failed:  ${failed[*]:-none}"
[ ${#failed[@]} -eq 0 ]
