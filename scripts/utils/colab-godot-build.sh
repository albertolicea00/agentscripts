#!/usr/bin/env bash
# Clone a Godot Git repo on Colab, export debug/release APK/EXE, and copy to Google Drive
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: colab-godot-build.sh [options] <git-repo-url>

Clones a Godot repository inside a Google Colab VM, downloads the headless
Godot editor + export templates, exports Android (.apk) and/or Windows (.exe)
builds, verifies SHA-256 checksums, copies outputs to Google Drive, flushes
the Drive FUSE cache, and stops the Colab session.

Options:
  -d, --drive-dir <path>      Destination under MyDrive/ (default: CollabMedia/builds/godot or $DRIVE_DIR)
  -g, --godot-version <tag>   Godot release tag (default: 4.6.3-stable or $GODOT_VERSION)
  -p, --project-dir <subdir>  Subdirectory containing project.godot (default: auto-detect)
  -t, --targets <csv>         Comma-separated targets: android,windows,linux (default: android,windows)
  -m, --mode <debug|release>  Export mode (default: debug)
  -b, --branch <name>         Git branch or tag to clone (default: repo default branch)
  -s, --session <name>        Colab CLI session name (default: colab or $COLAB_SESSION)
      --ssh-host <host>       SSH host alias for Colab (default: colab or $COLAB_SSH_HOST)
      --keep-session          Keep the Colab session running after flushing Drive
  -h, --help                  Show this help message

Examples:
  make run-colab-godot-build ARGS="https://github.com/user/my-game -d toMyGh"
  ./scripts/utils/colab-godot-build.sh -d toMyGh -t android,windows https://github.com/user/my-game
EOF
}

DRIVE_DIR="${DRIVE_DIR:-CollabMedia/builds/godot}"
GODOT_VERSION="${GODOT_VERSION:-4.6.3-stable}"
PROJECT_DIR=""
TARGETS="android,windows"
MODE="debug"
BRANCH=""
SESSION="${COLAB_SESSION:-colab}"
SSH_HOST="${COLAB_SSH_HOST:-colab}"
KEEP_SESSION="0"
REPO_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--drive-dir) DRIVE_DIR="$2"; shift 2 ;;
    -g|--godot-version) GODOT_VERSION="$2"; shift 2 ;;
    -p|--project-dir) PROJECT_DIR="$2"; shift 2 ;;
    -t|--targets) TARGETS="$2"; shift 2 ;;
    -m|--mode) MODE="$2"; shift 2 ;;
    -b|--branch) BRANCH="$2"; shift 2 ;;
    -s|--session) SESSION="$2"; shift 2 ;;
    --ssh-host) SSH_HOST="$2"; shift 2 ;;
    --keep-session) KEEP_SESSION="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      if [[ -z "$REPO_URL" ]]; then
        REPO_URL="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "Error: --mode must be 'debug' or 'release' (got '$MODE')." >&2
  exit 1
fi

for cmd in colab ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

if [[ -z "$REPO_URL" ]]; then
  read -r -p "Git repository URL: " REPO_URL
fi
if [[ -z "$REPO_URL" ]]; then
  usage >&2
  exit 1
fi

# Strip leading/trailing slashes from DRIVE_DIR
DRIVE_DIR="${DRIVE_DIR#/}"
DRIVE_DIR="${DRIVE_DIR%/}"

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -o ServerAliveCountMax=10)

if ! colab sessions 2>/dev/null | grep -qE "\\b${SESSION}\\b"; then
  echo "Creating Colab session '$SESSION'..."
  colab new -s "$SESSION"
fi

if ! ssh "${SSH_OPTS[@]}" "$SSH_HOST" "test -d /content/drive/MyDrive" 2>/dev/null; then
  echo "Mounting Google Drive on '$SESSION' (approve the browser OAuth prompt if opened)..."
  colab drivemount -s "$SESSION" /content/drive
fi

echo "Building '${REPO_URL}' on Colab (Godot ${GODOT_VERSION}, targets=${TARGETS}, mode=${MODE})..."

ssh "${SSH_OPTS[@]}" "$SSH_HOST" \
  "REPO_URL=$(printf '%q' "$REPO_URL") DRIVE_DIR=$(printf '%q' "$DRIVE_DIR") GODOT_VERSION=$(printf '%q' "$GODOT_VERSION") PROJECT_DIR=$(printf '%q' "$PROJECT_DIR") TARGETS=$(printf '%q' "$TARGETS") MODE=$(printf '%q' "$MODE") BRANCH=$(printf '%q' "$BRANCH") bash -s" <<'REMOTE_EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Derive template folder name (e.g. 4.6.3-stable -> 4.6.3.stable) and editor settings major.minor (e.g. 4.6)
TEMPLATE_VER="${GODOT_VERSION//-/.}"
MAJOR_MINOR="$(echo "$GODOT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')"

echo "=== 1. Checking dependencies ==="
NEED_PKGS=()
command -v java >/dev/null 2>&1 || NEED_PKGS+=(openjdk-17-jdk-headless)
command -v apksigner >/dev/null 2>&1 || NEED_PKGS+=(apksigner)
command -v adb >/dev/null 2>&1 || NEED_PKGS+=(adb)
command -v unzip >/dev/null 2>&1 || NEED_PKGS+=(unzip)
command -v curl >/dev/null 2>&1 || NEED_PKGS+=(curl)

if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  apt-get -qq update
  apt-get -qq install -y "${NEED_PKGS[@]}" >/dev/null
fi

echo "=== 2. Setting up Godot ${GODOT_VERSION} + export templates ==="
GODOT_DIR="/content/godot/${GODOT_VERSION}"
TPL_DIR="/root/.local/share/godot/export_templates/${TEMPLATE_VER}"
mkdir -p "$GODOT_DIR" "$TPL_DIR" /root/.config/godot

if [ ! -x "${GODOT_DIR}/godot" ]; then
  curl -fsSL -o "${GODOT_DIR}/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -q -o "${GODOT_DIR}/godot.zip" -d "$GODOT_DIR"
  mv "${GODOT_DIR}/Godot_v${GODOT_VERSION}_linux.x86_64" "${GODOT_DIR}/godot"
  chmod +x "${GODOT_DIR}/godot"
  rm -f "${GODOT_DIR}/godot.zip"
fi

if [ ! -f "${TPL_DIR}/android_debug.apk" ] && [ ! -f "${TPL_DIR}/windows_debug_x86_64.exe" ]; then
  curl -fsSL -o "${GODOT_DIR}/templates.tpz" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  rm -rf "${GODOT_DIR}/tpl_tmp"
  unzip -q -o "${GODOT_DIR}/templates.tpz" -d "${GODOT_DIR}/tpl_tmp"
  mv "${GODOT_DIR}/tpl_tmp/templates/"* "$TPL_DIR/"
  rm -rf "${GODOT_DIR}/tpl_tmp" "${GODOT_DIR}/templates.tpz"
fi

echo "=== 3. Configuring Android SDK stub & debug keystore ==="
mkdir -p /content/android-sdk/build-tools/34.0.0 /content/android-sdk/platform-tools
ln -sf "$(command -v apksigner)" /content/android-sdk/build-tools/34.0.0/apksigner
ln -sf "$(command -v adb)" /content/android-sdk/platform-tools/adb

if [ ! -f /content/debug.keystore ]; then
  keytool -genkey -v -keystore /content/debug.keystore \
    -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

JAVA_HOME_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
cat > "/root/.config/godot/editor_settings-${MAJOR_MINOR}.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "/content/android-sdk"
export/android/java_sdk_path = "${JAVA_HOME_DIR}"
export/android/debug_keystore = "/content/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF

echo "=== 4. Cloning repository ==="
REPO_NAME="$(basename "${REPO_URL%.git}")"
WORK_DIR="/content/godot_build/${REPO_NAME}"
rm -rf "$WORK_DIR"
mkdir -p /content/godot_build

if [ -n "$BRANCH" ]; then
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK_DIR"
else
  git clone --depth 1 "$REPO_URL" "$WORK_DIR"
fi

cd "$WORK_DIR"

# Auto-detect project.godot directory if not specified
if [ -z "$PROJECT_DIR" ]; then
  PROJ_FILE="$(find . -maxdepth 3 -name 'project.godot' | head -n 1 || true)"
  if [ -z "$PROJ_FILE" ]; then
    echo "Error: Could not find project.godot in ${REPO_NAME}. Pass --project-dir." >&2
    exit 1
  fi
  PROJECT_DIR="$(dirname "$PROJ_FILE")"
fi
echo "Detected Godot project dir: ${PROJECT_DIR}"

# Detect version suffix if available
VER_SUFFIX=""
if [ -f "tools/bump_version.py" ]; then
  APP_VER="$(python3 tools/bump_version.py --version 2>/dev/null || true)"
  [ -n "$APP_VER" ] && VER_SUFFIX="-v${APP_VER}"
fi

echo "=== 5. Importing Godot resources ==="
GODOT_SILENCE_ROOT_WARNING=1 "${GODOT_DIR}/godot" --headless --path "$PROJECT_DIR" --editor --import --quit || true

EXPORT_FLAG="--export-${MODE}"
OUT_LOCAL="${WORK_DIR}/colab_exports"
mkdir -p "$OUT_LOCAL"
BUILT_FILES=()

IFS=',' read -ra TARGET_LIST <<< "$TARGETS"
for raw_t in "${TARGET_LIST[@]}"; do
  t="$(echo "$raw_t" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$t" in
    android)
      OUT_FILE="${OUT_LOCAL}/${REPO_NAME}${VER_SUFFIX}-${MODE}.apk"
      echo "=== Exporting Android (${MODE}) -> $(basename "$OUT_FILE") ==="
      GODOT_SILENCE_ROOT_WARNING=1 "${GODOT_DIR}/godot" --headless --path "$PROJECT_DIR" "$EXPORT_FLAG" "Android" "$OUT_FILE"
      BUILT_FILES+=("$OUT_FILE")
      ;;
    windows)
      OUT_FILE="${OUT_LOCAL}/${REPO_NAME}${VER_SUFFIX}-${MODE}.exe"
      echo "=== Exporting Windows Desktop (${MODE}) -> $(basename "$OUT_FILE") ==="
      GODOT_SILENCE_ROOT_WARNING=1 "${GODOT_DIR}/godot" --headless --path "$PROJECT_DIR" "$EXPORT_FLAG" "Windows Desktop" "$OUT_FILE"
      BUILT_FILES+=("$OUT_FILE")
      ;;
    linux)
      OUT_FILE="${OUT_LOCAL}/${REPO_NAME}${VER_SUFFIX}-${MODE}.x86_64"
      echo "=== Exporting Linux (${MODE}) -> $(basename "$OUT_FILE") ==="
      GODOT_SILENCE_ROOT_WARNING=1 "${GODOT_DIR}/godot" --headless --path "$PROJECT_DIR" "$EXPORT_FLAG" "Linux" "$OUT_FILE"
      BUILT_FILES+=("$OUT_FILE")
      ;;
    *)
      echo "Error: Unsupported target '$t' (expected android, windows, or linux)." >&2
      exit 1
      ;;
  esac
done

echo "=== 6. Copying & verifying on Google Drive (MyDrive/${DRIVE_DIR}) ==="
DEST="/content/drive/MyDrive/${DRIVE_DIR}"
mkdir -p "$DEST"

for f in "${BUILT_FILES[@]}"; do
  base="$(basename "$f")"
  cp -v "$f" "${DEST}/${base}"
  sync
  SRC_SHA="$(sha256sum "$f" | awk '{print $1}')"
  DST_SHA="$(sha256sum "${DEST}/${base}" | awk '{print $1}')"
  if [ "$SRC_SHA" != "$DST_SHA" ]; then
    echo "Error: SHA-256 mismatch for ${base}!" >&2
    exit 1
  fi
  echo "Verified SHA-256 (${base}): ${DST_SHA}"
done

echo "=== Drive folder contents ==="
ls -lh "$DEST/"
REMOTE_EOF

echo "Flushing Google Drive FUSE cache on '$SESSION'..."
printf 'from google.colab import drive\ndrive.flush_and_unmount()\nprint("DRIVE_FLUSHED_OK")\n' \
  | colab exec -s "$SESSION" --timeout 300

if [[ "$KEEP_SESSION" == "0" ]]; then
  echo "Stopping Colab session '$SESSION'..."
  colab stop -s "$SESSION"
else
  echo "Keeping Colab session '$SESSION' running (--keep-session)."
fi
