#!/data/data/com.termux/files/usr/bin/bash
# anland-arch-setup.sh
#
# KDE Plasma (Wayland, KGSL GPU acceleration) running natively in Termux via
# Anland, plus an Arch Linux ARM container (proot-distro) with yay. Apps you
# install in Arch show up in the Plasma Kickoff menu and draw on the same
# desktop with the Adreno GPU.
#
# Optionally also sets up an Ubuntu 26.04 container with its own Plasma desktop
# (Anland's prebuilt image + patched KWin/XWayland + the Ubuntu GPU driver).
# Only one desktop (native, X11, Ubuntu or Debian) can be shown at a time.
#
# The X11 session is an extra: native Wayland Plasma stays the default and is
# never replaced. The X11 session uses the separate Termux:X11 display app and
# software rendering (the Anland GPU path is Wayland only).
#
# Run it in Termux itself (not inside a container):
#   bash anland-arch-setup.sh
#
# With no options it opens a menu: pick what to install, start or stop a
# desktop, open the Arch/Ubuntu shells, sync Kickoff. A copy of the script is
# kept as the "anland-menu" command, so the menu is always one word away.
#
# Options (skip the menu and install straight away; with no terminal and no
# options it installs native Plasma + the Arch container):
#   --no-arch       skip the Arch container
#   --ubuntu        also set up the Ubuntu 26.04 container
#   --debian        also set up the Debian 13 container
#   --x11           also set up a Plasma X11 session (Termux:X11 app) next to Wayland
#   --x11-ubuntu    also set up an Ubuntu Plasma (X11) container over Termux:X11
#   --x11-debian    also set up a Debian Plasma (X11) container over Termux:X11
#   --x11-arch      also set up an Arch XFCE4 container over Termux:X11
#   --ubuntu-only   only Anland + the Ubuntu container (no native Plasma, no Arch)
#   --debian-only   only Anland + the Debian container (no native Plasma, no Arch)
#   -h, --help      show this text
#
# Environment variables:
#   ARCH_USER      user created in Arch              (default: arch)
#   ARCH_NAME      proot-distro container name       (default: archlinux)
#   UBUNTU_NAME    Ubuntu container name             (default: ubuntu-anland)
#   DEBIAN_NAME    Debian container name             (default: debian-anland)
#   UBUNTU_IMAGE   image for the Ubuntu container    (default: Anland's 26.04 image)
#   DEBIAN_IMAGE   image for the Debian container    (default: Anland's 13 image)
#   ARCH_ROOTFS    Arch rootfs: local file or https URL (default: Arch Linux ARM latest)
#                  The menu (Install / update > i) can set all the images too.
#                  A custom Ubuntu/Debian image must still be Ubuntu 26.04 / Debian 13,
#                  and a custom Arch rootfs must be Arch Linux ARM based.
#   XUBUNTU_NAME / XDEBIAN_NAME / XARCH_NAME   X11 container names
#                  (default: ubuntu-x11 / debian-x11 / arch-x11)
#   XUBUNTU_IMAGE / XDEBIAN_IMAGE / XARCH_IMAGE   image for each X11 container
#                  (default: proot-distro's ubuntu / debian / archlinux). Ubuntu and
#                  Debian take any Debian/Ubuntu-based image, Arch any Arch-based one
#                  (image, tarball or URL that proot-distro accepts).
#                  Images only apply to a container that does not exist yet.
#   ANLAND_DIR     download/work folder              (default: ~/anland)
#   GITHUB_TOKEN   optional, avoids GitHub API rate limits
#
# Needs: Termux (GitHub or F-Droid build), aarch64 phone with an Adreno GPU
# (Snapdragon), Wi-Fi, about 6 GB free storage (more for each extra container).
#
# Commands this installs:
#   plasma          start native Plasma, then open the "Anland Termux" app
#   plasma-ubuntu   start the Ubuntu desktop instead (with --ubuntu)
#   plasma-debian   start the Debian desktop instead (with --debian)
#   plasma-x11      start the Plasma X11 session, then open "Termux:X11" (with --x11)
#   x11-ubuntu      start the Ubuntu Plasma desktop on Termux:X11 (with --x11-ubuntu)
#   x11-debian      start the Debian Plasma desktop on Termux:X11 (with --x11-debian)
#   x11-arch        start the Arch XFCE4 desktop on Termux:X11 (with --x11-arch)
#   plasma-stop     stop whichever desktop is running
#   archsh          shell in the Arch container as your user
#   ubuntush        shell in the Ubuntu container (root)
#   debiansh        shell in the Debian container (root)
#   ksync           rebuild the "[Arch]" Kickoff entries by hand
#   archrun         (internal) run a command in Arch with the display settings of
#                   the running session (Wayland + GPU, or X11)
#   anland-menu     this script's menu
#
# Known issue: if kwin_wayland fails with "cannot locate symbol", Termux's Qt
# moved past the Anland KWin build. Wait for a new Anland release, then re-run
# this script. Check before upgrading: apt list --upgradable | grep -i qt
set -eu

# Absolute path of this script, taken before the script changes directory.
SELF=$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")
ARCH_USER_GIVEN=${ARCH_USER:-}
ARCH_USER=${ARCH_USER:-arch}
ARCH_NAME=${ARCH_NAME:-archlinux}
UBUNTU_NAME=${UBUNTU_NAME:-ubuntu-anland}
DEBIAN_NAME=${DEBIAN_NAME:-debian-anland}
# Anland's prebuilt Ubuntu 26.04 ("resolute") image with Plasma installed.
UBUNTU_IMAGE_DEFAULT=ghcr.io/lfdevs/ubuntu:resolute-anland-plasma
UBUNTU_IMAGE=${UBUNTU_IMAGE:-$UBUNTU_IMAGE_DEFAULT}
# Ubuntu 26.04 uses XWayland 24.1.10; the release also lists the Debian one.
UBUNTU_XWAYLAND_RE='^xwayland_24\.1\.10.*_arm64\.deb$'
# Anland's prebuilt Debian 13 ("trixie") image with Plasma installed.
DEBIAN_IMAGE_DEFAULT=ghcr.io/lfdevs/debian:trixie-anland-plasma
DEBIAN_IMAGE=${DEBIAN_IMAGE:-$DEBIAN_IMAGE_DEFAULT}
# Arch rootfs: empty means the latest Arch Linux ARM; else a local file or URL.
ARCH_ROOTFS=${ARCH_ROOTFS:-}
# X11 desktop containers over Termux:X11: Plasma (Ubuntu, Debian) or XFCE4 (Arch).
# The Ubuntu and Debian slots take Debian/Ubuntu-based images, the Arch slot an Arch-based one.
XUBUNTU_NAME=${XUBUNTU_NAME:-ubuntu-x11}
XDEBIAN_NAME=${XDEBIAN_NAME:-debian-x11}
XARCH_NAME=${XARCH_NAME:-arch-x11}
XUBUNTU_IMAGE_DEFAULT=ubuntu
XUBUNTU_IMAGE=${XUBUNTU_IMAGE:-$XUBUNTU_IMAGE_DEFAULT}
XDEBIAN_IMAGE_DEFAULT=debian
XDEBIAN_IMAGE=${XDEBIAN_IMAGE:-$XDEBIAN_IMAGE_DEFAULT}
XARCH_IMAGE_DEFAULT=archlinux
XARCH_IMAGE=${XARCH_IMAGE:-$XARCH_IMAGE_DEFAULT}
# Debian 13 uses XWayland 24.1.6.
DEBIAN_XWAYLAND_RE='^xwayland_24\.1\.6.*_arm64\.deb$'
WORK=${ANLAND_DIR:-$HOME/anland}
DO_NATIVE=1
DO_ARCH=1
DO_UBUNTU=0
DO_DEBIAN=0
DO_X11=0
X11_READY=0
DO_XUBUNTU=0
DO_XDEBIAN=0
DO_XARCH=0
DO_XCONT=0
X11_FALLBACK=

for a in "$@"; do
  case $a in
    --no-arch) DO_ARCH=0 ;;
    --ubuntu) DO_UBUNTU=1 ;;
    --debian) DO_DEBIAN=1 ;;
    --x11) DO_X11=1 ;;
    --x11-ubuntu) DO_XUBUNTU=1 ;;
    --x11-debian) DO_XDEBIAN=1 ;;
    --x11-arch) DO_XARCH=1 ;;
    --ubuntu-only) DO_UBUNTU=1; DO_NATIVE=0; DO_ARCH=0 ;;
    --debian-only) DO_DEBIAN=1; DO_NATIVE=0; DO_ARCH=0 ;;
    -h|--help) sed -n '2,/^set -eu/{/^set -eu/!p}' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- checks ----
[ -n "${PREFIX:-}" ] && [ -d /data/data/com.termux ] \
  || die "Run this in Termux itself, not inside a container."
[ "$(id -u)" -ne 0 ] || die "Do not run this as root."
[ "$(uname -m)" = aarch64 ] || die "This only supports aarch64 phones."
[ -e /dev/kgsl-3d0 ] || warn "No Adreno GPU node found: the Anland GPU path needs a Snapdragon phone."

HDR=()
[ -n "${GITHUB_TOKEN:-}" ] && HDR=(-H "Authorization: Bearer $GITHUB_TOKEN")
gh_api() { curl -fsSL "${HDR[@]}" -H 'Accept: application/vnd.github+json' "https://api.github.com/$1"; }
fetch()  { curl -fL --retry 3 -# -O "$1"; }
# URL of the newest mesa-for-android-container asset whose name matches regex $1.
# Searches recent releases (the "latest" one can be a Turnip-only release).
mesa_url() {
  gh_api "repos/lfdevs/mesa-for-android-container/releases?per_page=30" \
    | jq -r --arg re "$1" '[.[].assets[] | select(.name | test($re)) | .browser_download_url][0] // empty'
}

# Helper command that stops whichever Plasma desktop (native or Ubuntu) is
# running, so the other one can be started.
make_plasma_stop() {
  cat > "$PREFIX/bin/plasma-stop" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f startplasma >/dev/null 2>&1 || true
pkill kwin_wayland >/dev/null 2>&1 || true
pkill kwin_x11 >/dev/null 2>&1 || true
pkill plasmashell >/dev/null 2>&1 || true
pkill -f 'startxfce4|xfce4-session' >/dev/null 2>&1 || true
pkill -f 'com\.termux\.x11' >/dev/null 2>&1 || true
killall anland >/dev/null 2>&1 || true
EOF
  chmod +x "$PREFIX/bin/plasma-stop"
}

# ------------------------------------------------------------------ menu ----
RAW_URL=https://raw.githubusercontent.com/ttyy31129-sudo/termux-plasma-arch/main/anland-arch-setup.sh

have()  { [ -x "$PREFIX/bin/$1" ]; }
state() { if have "$1"; then printf 'installed'; else printf 'not installed'; fi; }
pause() { read -r -p "Press Enter to go back to the menu... " _ || true; }
clear_screen() { clear 2>/dev/null || true; }

# Run an installed command, or say that it still has to be installed.
run_cmd() {
  local name=$1; shift
  if have "$name"; then "$PREFIX/bin/$name" "$@" || true
  else warn "'$name' is not installed yet. Choose 'Install / update' first."
  fi
}

# An image reference, path or URL: no spaces or shell characters.
valid_ref() { [[ $1 =~ ^[A-Za-z0-9._:/@+~%=?\&-]+$ ]]; }

images_state() {
  if [ "$UBUNTU_IMAGE" = "$UBUNTU_IMAGE_DEFAULT" ] && [ "$DEBIAN_IMAGE" = "$DEBIAN_IMAGE_DEFAULT" ] \
     && [ -z "$ARCH_ROOTFS" ] && [ "$XUBUNTU_IMAGE" = "$XUBUNTU_IMAGE_DEFAULT" ] \
     && [ "$XDEBIAN_IMAGE" = "$XDEBIAN_IMAGE_DEFAULT" ] && [ "$XARCH_IMAGE" = "$XARCH_IMAGE_DEFAULT" ]; then
    printf 'default'
  else
    printf 'custom'
  fi
}

# A file path made absolute (the script changes folders later). Other values stay.
abs_if_file() {
  local v=${1/#\~/$HOME}
  if [ -f "$v" ]; then readlink -f -- "$v"; else printf '%s' "$1"; fi
}

# Pick an image: the default, a rootfs file found in Downloads, or typed.
# args: variable-name default-value title default-label
pick_image() {
  local var=$1 def=$2 title=$3 deflabel=$4
  local dl="$HOME/storage/downloads" f i=0 c files=()
  if [ -d "$dl" ]; then
    shopt -s nullglob
    for f in "$dl"/*.tar.gz "$dl"/*.tgz "$dl"/*.tar.xz "$dl"/*.tar.zst; do files+=("$f"); done
    shopt -u nullglob
  fi
  printf '\n  %s\n  ----------\n' "$title"
  printf '   d  %s\n' "$deflabel"
  for f in ${files[@]+"${files[@]}"}; do i=$((i + 1)); printf '   %s  %s\n' "$i" "${f##*/}"; done
  printf '   t  Type an image, path or https URL\n\n'
  read -r -p "Choose: " c || exit 0
  case $c in
    d|D) printf -v "$var" '%s' "$def" ;;
    t|T)
      read -r -p "Image, path or https URL: " c || exit 0
      if [ -z "$c" ]; then :
      elif valid_ref "$c"; then printf -v "$var" '%s' "$c"
      else warn "Not a valid image, path or URL."; sleep 1
      fi ;;
    ''|*[!0-9]*) ;;
    *) if [ "$c" -ge 1 ] && [ "$c" -le "$i" ]; then printf -v "$var" '%s' "${files[$((c - 1))]}"; fi ;;
  esac
}

# One line pair of the image screen: number, title, value, (default) marker.
show_image() {
  printf '   %s  %s\n        %s%s\n' "$1" "$2" "$3" "$([ "$3" = "$4" ] && printf ' (default)')"
}

# Choose the images used when a container is created.
image_menu() {
  local c c2 v
  while :; do
    clear_screen
    printf '\n  Images\n  ------\n'
    show_image 1 "Ubuntu 26.04 (Wayland)" "$UBUNTU_IMAGE" "$UBUNTU_IMAGE_DEFAULT"
    show_image 2 "Debian 13 (Wayland)" "$DEBIAN_IMAGE" "$DEBIAN_IMAGE_DEFAULT"
    show_image 3 "Arch rootfs (terminal)" "${ARCH_ROOTFS:-Arch Linux ARM latest}" "Arch Linux ARM latest"
    show_image 4 "Ubuntu Plasma X11" "$XUBUNTU_IMAGE" "$XUBUNTU_IMAGE_DEFAULT"
    show_image 5 "Debian Plasma X11" "$XDEBIAN_IMAGE" "$XDEBIAN_IMAGE_DEFAULT"
    show_image 6 "Arch XFCE4 X11" "$XARCH_IMAGE" "$XARCH_IMAGE_DEFAULT"
    printf '\n  1-6 = change   r = reset all   b = back\n'
    printf '  1-2 must stay Ubuntu 26.04 / Debian 13.\n'
    printf '  3 must be Arch Linux ARM based.\n'
    printf '  4-5 take any Debian/Ubuntu-based image.\n'
    printf '  6 takes any Arch-based image.\n'
    printf '  Only used for containers not made yet.\n\n'
    read -r -p "Choose: " c || exit 0
    case $c in
      1|2)
        if [ "$c" = 1 ]; then v=Ubuntu; else v=Debian; fi
        read -r -p "$v image (Enter = keep, d = default): " c2 || exit 0
        case $c2 in
          "") ;;
          d|D) if [ "$c" = 1 ]; then UBUNTU_IMAGE=$UBUNTU_IMAGE_DEFAULT; else DEBIAN_IMAGE=$DEBIAN_IMAGE_DEFAULT; fi ;;
          *) if valid_ref "$c2"; then
               if [ "$c" = 1 ]; then UBUNTU_IMAGE=$c2; else DEBIAN_IMAGE=$c2; fi
             else warn "Not a valid image reference."; sleep 1
             fi ;;
        esac ;;
      3) pick_image ARCH_ROOTFS "" "Arch rootfs" "Arch Linux ARM latest (download, default)" ;;
      4) pick_image XUBUNTU_IMAGE "$XUBUNTU_IMAGE_DEFAULT" "Ubuntu X11 image" "$XUBUNTU_IMAGE_DEFAULT (proot-distro, default)" ;;
      5) pick_image XDEBIAN_IMAGE "$XDEBIAN_IMAGE_DEFAULT" "Debian X11 image" "$XDEBIAN_IMAGE_DEFAULT (proot-distro, default)" ;;
      6) pick_image XARCH_IMAGE "$XARCH_IMAGE_DEFAULT" "Arch X11 image" "$XARCH_IMAGE_DEFAULT (proot-distro, default)" ;;
      r|R) UBUNTU_IMAGE=$UBUNTU_IMAGE_DEFAULT; DEBIAN_IMAGE=$DEBIAN_IMAGE_DEFAULT; ARCH_ROOTFS=""
           XUBUNTU_IMAGE=$XUBUNTU_IMAGE_DEFAULT; XDEBIAN_IMAGE=$XDEBIAN_IMAGE_DEFAULT; XARCH_IMAGE=$XARCH_IMAGE_DEFAULT ;;
      b|B|0) return 0 ;;
    esac
  done
}

# Toggle screen for the install parts. Returns 0 to start, 1 to go back.
install_menu() {
  local c
  while :; do
    clear_screen
    printf '\n  Install / update\n  ----------------\n'
    printf '   [%s] 1  Native Plasma in Termux (GPU)\n' "$([ "$DO_NATIVE" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 2  Arch Linux container + yay + Kickoff sync (needs 1)\n' "$([ "$DO_ARCH" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 3  Ubuntu 26.04 desktop container\n' "$([ "$DO_UBUNTU" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 4  Debian 13 desktop container\n' "$([ "$DO_DEBIAN" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 5  Plasma X11 session, Termux:X11 app (extra, needs 1)\n' "$([ "$DO_X11" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 6  Ubuntu Plasma X11 container (needs 1)\n' "$([ "$DO_XUBUNTU" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 7  Debian Plasma X11 container (needs 1)\n' "$([ "$DO_XDEBIAN" = 1 ] && printf x || printf ' ')"
    printf '   [%s] 8  Arch XFCE4 X11 container (needs 1)\n' "$([ "$DO_XARCH" = 1 ] && printf x || printf ' ')"
    printf '\n  Images: %s\n' "$(images_state)"
    printf '\n  1-8 = tick / untick   i = choose images\n  g = go   b = back\n\n'
    read -r -p "Choose: " c || exit 0
    case $c in
      1) DO_NATIVE=$((1 - DO_NATIVE)); if [ "$DO_NATIVE" = 0 ]; then DO_ARCH=0; DO_X11=0; DO_XUBUNTU=0; DO_XDEBIAN=0; DO_XARCH=0; fi ;;
      2) DO_ARCH=$((1 - DO_ARCH)); if [ "$DO_ARCH" = 1 ]; then DO_NATIVE=1; fi ;;
      3) DO_UBUNTU=$((1 - DO_UBUNTU)) ;;
      4) DO_DEBIAN=$((1 - DO_DEBIAN)) ;;
      5) DO_X11=$((1 - DO_X11)); if [ "$DO_X11" = 1 ]; then DO_NATIVE=1; fi ;;
      6) DO_XUBUNTU=$((1 - DO_XUBUNTU)); if [ "$DO_XUBUNTU" = 1 ]; then DO_NATIVE=1; fi ;;
      7) DO_XDEBIAN=$((1 - DO_XDEBIAN)); if [ "$DO_XDEBIAN" = 1 ]; then DO_NATIVE=1; fi ;;
      8) DO_XARCH=$((1 - DO_XARCH)); if [ "$DO_XARCH" = 1 ]; then DO_NATIVE=1; fi ;;
      i|I) image_menu ;;
      g|G)
        if [ $((DO_NATIVE + DO_ARCH + DO_UBUNTU + DO_DEBIAN)) -eq 0 ]; then
          warn "Tick at least one part."; sleep 1
        else
          return 0
        fi ;;
      b|B|0) return 1 ;;
    esac
  done
}

# Asks for the Arch username. Keeps the one a previous run set up, if any.
ask_arch_user() {
  local u old=""
  if [ -z "$ARCH_USER_GIVEN" ] && have archsh; then
    old=$(sed -n 's/.*--user \([a-z_][a-z0-9_-]*\).*/\1/p' "$PREFIX/bin/archsh" | head -n1)
    [ -z "$old" ] || ARCH_USER=$old
  fi
  while :; do
    read -r -p "Username for the Arch container [$ARCH_USER]: " u || exit 0
    u=${u:-$ARCH_USER}
    if [[ $u =~ ^[a-z_][a-z0-9_-]*$ ]]; then ARCH_USER=$u; return 0; fi
    warn "Use lowercase letters, digits, _ or -, starting with a letter."
  done
}

# Replace the installed menu with the newest script from GitHub.
update_self() {
  local tmp="$TMPDIR/anland-menu.new"
  if curl -fsSL -o "$tmp" "$RAW_URL" && bash -n "$tmp" 2>/dev/null \
     && grep -q 'anland-arch-setup' "$tmp"; then
    chmod +x "$tmp"
    mv -f "$tmp" "$PREFIX/bin/anland-menu"
    echo "Updated. Restarting the menu..."; sleep 1
    exec "$PREFIX/bin/anland-menu"
  fi
  rm -f "$tmp"
  warn "Could not download a valid update. Nothing was changed."
  pause
}

# Start one of the X11 desktops (they all use the Termux:X11 app).
x11_menu() {
  local c
  while :; do
    clear_screen
    printf '\n  X11 desktops (Termux:X11)\n  -------------------------\n'
    printf '   1) %-24s (%s)\n' "Plasma X11 (native)" "$(state plasma-x11)"
    printf '   2) %-24s (%s)\n' "Ubuntu Plasma X11" "$(state x11-ubuntu)"
    printf '   3) %-24s (%s)\n' "Debian Plasma X11" "$(state x11-debian)"
    printf '   4) %-24s (%s)\n' "Arch XFCE4 X11" "$(state x11-arch)"
    printf '   b) Back\n\n'
    read -r -p "Choose: " c || exit 0
    case $c in
      1) run_cmd plasma-x11; pause ;;
      2) run_cmd x11-ubuntu; pause ;;
      3) run_cmd x11-debian; pause ;;
      4) run_cmd x11-arch; pause ;;
      b|B|0) return 0 ;;
    esac
  done
}

# Returns 0 when the user chose to install (DO_* are set), exits on Quit.
main_menu() {
  local c
  while :; do
    clear_screen
    printf '\n  Termux KDE Plasma + Arch + Ubuntu + Debian\n  ------------------------------------------\n'
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
      warn "You are inside a desktop: starting or stopping one here will close it. Use the Termux app."
    fi
    printf '   1) %-30s\n' "Install / update"
    printf '   2) %-30s (%s)\n' "Start native Plasma" "$(state plasma)"
    printf '   3) %-30s (%s)\n' "Start Ubuntu Plasma" "$(state plasma-ubuntu)"
    printf '   4) %-30s (%s)\n' "Start Debian Plasma" "$(state plasma-debian)"
    printf '   x) %-30s\n' "X11 desktops (Termux:X11)"
    printf '   5) %-30s\n' "Stop the running desktop"
    printf '   6) %-30s (%s)\n' "Arch shell (yay)" "$(state archsh)"
    printf '   7) %-30s (%s)\n' "Ubuntu shell (apt)" "$(state ubuntush)"
    printf '   8) %-30s (%s)\n' "Debian shell (apt)" "$(state debiansh)"
    printf '   9) %-30s\n' "Sync Arch apps to Kickoff"
    printf '   u) %-30s\n' "Update this menu from GitHub"
    printf '   0) %-30s\n\n' "Quit"
    read -r -p "Choose: " c || exit 0
    case $c in
      1) if install_menu; then return 0; fi ;;
      2) echo "Starting Plasma. Open the Anland Termux app now."; run_cmd plasma; pause ;;
      3) echo "Starting Ubuntu Plasma. Open the Anland Termux app now."; run_cmd plasma-ubuntu; pause ;;
      4) echo "Starting Debian Plasma. Open the Anland Termux app now."; run_cmd plasma-debian; pause ;;
      x|X) x11_menu ;;
      5) run_cmd plasma-stop; echo "Stopped."; sleep 1 ;;
      6) run_cmd archsh ;;
      7) run_cmd ubuntush ;;
      8) run_cmd debiansh ;;
      9) run_cmd ksync; pause ;;
      u|U) update_self ;;
      0|q|Q) exit 0 ;;
    esac
  done
}

if [ "$#" -eq 0 ] && [ -t 0 ]; then
  main_menu
  if [ "$DO_ARCH" = 1 ]; then ask_arch_user; fi
fi

if [ "$DO_UBUNTU" = 1 ] && ! valid_ref "$UBUNTU_IMAGE"; then die "Invalid UBUNTU_IMAGE: $UBUNTU_IMAGE"; fi
if [ "$DO_DEBIAN" = 1 ] && ! valid_ref "$DEBIAN_IMAGE"; then die "Invalid DEBIAN_IMAGE: $DEBIAN_IMAGE"; fi
if [ -n "$ARCH_ROOTFS" ]; then
  ARCH_ROOTFS=${ARCH_ROOTFS/#\~/$HOME}
  valid_ref "$ARCH_ROOTFS" || die "Invalid ARCH_ROOTFS: $ARCH_ROOTFS"
  case $ARCH_ROOTFS in
    http://*|https://*) ;;
    *) ARCH_ROOTFS=$(readlink -f -- "$ARCH_ROOTFS" 2>/dev/null || printf '%s' "$ARCH_ROOTFS") ;;  # before any cd
  esac
fi
if [ "$DO_XUBUNTU" = 1 ] || [ "$DO_XDEBIAN" = 1 ] || [ "$DO_XARCH" = 1 ]; then DO_XCONT=1; fi
if { [ "$DO_X11" = 1 ] || [ "$DO_XCONT" = 1 ]; } && [ "$DO_NATIVE" = 0 ]; then
  die "The X11 options need native Plasma: do not combine them with --ubuntu-only or --debian-only."
fi
for _n in "$XUBUNTU_NAME" "$XDEBIAN_NAME" "$XARCH_NAME"; do
  [[ $_n =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid container name: $_n"
done
if [ "$DO_XUBUNTU" = 1 ] && ! valid_ref "$XUBUNTU_IMAGE"; then die "Invalid XUBUNTU_IMAGE: $XUBUNTU_IMAGE"; fi
if [ "$DO_XDEBIAN" = 1 ] && ! valid_ref "$XDEBIAN_IMAGE"; then die "Invalid XDEBIAN_IMAGE: $XDEBIAN_IMAGE"; fi
if [ "$DO_XARCH" = 1 ] && ! valid_ref "$XARCH_IMAGE"; then die "Invalid XARCH_IMAGE: $XARCH_IMAGE"; fi
# Local image files are made absolute now: the script changes folders later.
UBUNTU_IMAGE=$(abs_if_file "$UBUNTU_IMAGE"); DEBIAN_IMAGE=$(abs_if_file "$DEBIAN_IMAGE")
XUBUNTU_IMAGE=$(abs_if_file "$XUBUNTU_IMAGE"); XDEBIAN_IMAGE=$(abs_if_file "$XDEBIAN_IMAGE")
XARCH_IMAGE=$(abs_if_file "$XARCH_IMAGE")
if [ "$DO_ARCH" = 1 ] && ! [[ $ARCH_USER =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  die "ARCH_USER must be a lowercase Linux username."
fi

# ------------------------------------------------------- Termux packages ----
export DEBIAN_FRONTEND=noninteractive
termux-wake-lock 2>/dev/null || true

PATCHED="xwayland mesa mesa-vulkan-icd-freedreno layer-shell-qt"

say "Updating Termux and installing packages"
if [ "$DO_NATIVE" = 1 ]; then
  # Hold already-installed patched packages first, so the upgrade below (and any
  # re-run after a failed run) cannot replace them with Termux's stock builds.
  for p in $PATCHED; do
    dpkg -s "$p" >/dev/null 2>&1 && apt-mark hold "$p" >/dev/null || true
  done
fi
pkg update -y
apt-get -y -o Dpkg::Options::=--force-confold dist-upgrade
if [ "$DO_NATIVE" = 1 ]; then
  pkg install -y x11-repo
  pkg update -y
  pkg install -y curl jq proot-distro plasma-desktop konsole dolphin pipewire termux-api
else
  pkg install -y curl jq proot-distro termux-api
fi

# --------------------------------------------------- Anland + GPU driver ----
say "Finding the latest Anland release"
REL=$(gh_api repos/lfdevs/anland-termux/releases/latest) \
  || die "GitHub API request failed (rate limit? set GITHUB_TOKEN)."
TAG=$(jq -r .tag_name <<<"$REL")
pick() { jq -r --arg re "$1" '[.assets[] | select(.name | test($re)) | .browser_download_url][0] // empty' <<<"$REL"; }

DAEMON=$(pick '^anland_[0-9.]+(-[0-9]+)?_aarch64\.deb$')
if [ "${TERMUX_APP__APK_RELEASE:-}" = F_DROID ]; then
  APK=$(pick '^AnlandTermux-.*-compatible\.apk$')   # F-Droid / ZeroTermux build
else
  APK=$(pick '^AnlandTermux-[0-9.]+\.apk$')         # GitHub Termux build
fi
NEEDED="DAEMON APK"
if [ "$DO_NATIVE" = 1 ]; then
  XWAY=$(pick '^xwayland_.*_aarch64\.deb$')
  KWIN=$(pick '^kwin-anland_.*_aarch64\.deb$')
  NEEDED="$NEEDED XWAY KWIN"
fi
if [ "$DO_UBUNTU" = 1 ]; then
  UXWAY=$(pick "$UBUNTU_XWAYLAND_RE")
  UKWIN=$(pick '^kwin_anland-.*ubuntu.*\.zip$')
  NEEDED="$NEEDED UXWAY UKWIN"
fi
if [ "$DO_DEBIAN" = 1 ]; then
  DXWAY=$(pick "$DEBIAN_XWAYLAND_RE")
  DKWIN=$(pick '^kwin_anland-.*debian.*\.zip$')
  NEEDED="$NEEDED DXWAY DKWIN"
fi
for v in $NEEDED; do
  [ -n "${!v}" ] || die "Release $TAG has no $v asset (release layout changed?)."
done

if [ "$DO_NATIVE" = 1 ]; then
say "Finding matching LayerShellQt and Freedreno packages"
TAGS=$(gh_api "repos/lfdevs/termux-packages/releases?per_page=100" | jq -r '.[].tag_name') \
  || die "Could not list lfdevs/termux-packages releases."
LV=$(dpkg-query -W -f='${Version}' layer-shell-qt 2>/dev/null || true)
WANT="layer-shell-qt_${LV%%-*}-1"
if grep -qxF "$WANT" <<<"$TAGS"; then
  LTAG=$WANT
else
  LTAG=$(grep '^layer-shell-qt_' <<<"$TAGS" | head -n1 || true)
fi
FTAG=$(grep '^freedreno-' <<<"$TAGS" | grep -v -- '-weston$' | head -n1 || true)
[ -n "$LTAG" ] && [ -n "$FTAG" ] || die "Could not find LayerShellQt/Freedreno releases."
tag_debs() { gh_api "repos/lfdevs/termux-packages/releases/tags/$1" \
  | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url'; }
LURLS=$(tag_debs "$LTAG") || die "Could not read release $LTAG."
FURLS=$(tag_debs "$FTAG") || die "Could not read release $FTAG."
fi

say "Downloading Anland $TAG${LTAG:+, $LTAG, $FTAG}"
rm -rf "$WORK/dl"; mkdir -p "$WORK/dl"; cd "$WORK/dl"
fetch "$DAEMON"
if [ "$DO_NATIVE" = 1 ]; then
  for u in "$XWAY" "$KWIN" $LURLS $FURLS; do fetch "$u"; done
fi

say "Installing"
# --allow-downgrades: Termux's repo can carry a newer layer-shell-qt/mesa than the
# patched builds, and the patched ones are the ones Anland needs.
reinst() {
  apt-get install -y --reinstall --allow-downgrades --allow-change-held-packages \
    -o Dpkg::Options::=--force-confold "$@"
}
reinst ./anland_*_aarch64.deb
if [ "$DO_NATIVE" = 1 ]; then
reinst ./xwayland_*_aarch64.deb ./kwin-anland_*_aarch64.deb
reinst ./layer-shell-qt_*.deb
reinst ./mesa*.deb
# Keep Termux updates from replacing the patched packages.
apt-mark hold $PATCHED

say "Installing the 'plasma' command"
curl -fL -o "$WORK/startplasma-anland.sh" \
  https://github.com/lfdevs/anland-termux/raw/refs/heads/main/scripts/startplasma-anland.sh
chmod +x "$WORK/startplasma-anland.sh"
make_plasma_stop
cat > "$PREFIX/bin/plasma" <<EOF
#!$PREFIX/bin/bash
cd "$WORK"
plasma-stop
sleep 1
anland >/dev/null 2>&1 &
./startplasma-anland.sh
EOF
chmod +x "$PREFIX/bin/plasma"
fi

say "Downloading the Anland display app"
if [ ! -d "$HOME/storage/downloads" ]; then
  termux-setup-storage || true
  for _ in $(seq 30); do [ -d "$HOME/storage/downloads" ] && break; sleep 1; done
fi
if [ -d "$HOME/storage/downloads" ]; then
  APKFILE="$HOME/storage/downloads/$(basename "$APK")"
  curl -fL -# -o "$APKFILE" "$APK"
  termux-open "$APKFILE" || true
  echo "Install the app from the prompt or from Downloads: $(basename "$APKFILE")"
  echo "(If you had the other Anland variant installed, uninstall it first.)"
else
  warn "No storage access. Download and install this APK yourself: $APK"
fi

# ------------------------------------------------------------ X11 session ----
# True Plasma X11 session on the Termux:X11 display app. Native Wayland Plasma
# is untouched. Software rendering only: Anland's GPU path is Wayland only.

# 0 when apt would only add packages, 1 when it would remove or replace the
# patched Wayland stack (kwin-anland, Anland, XWayland, Mesa, LayerShellQt).
x11_pkgs_safe() {
  local sim
  sim=$(apt-get -s install "$@" 2>&1) || return 1
  if grep -Eq '^(Remv|Purg) |^Inst (kwin|kwin-anland|anland|xwayland|mesa[a-z0-9-]*|layer-shell-qt) ' <<<"$sim"; then
    return 1
  fi
  return 0
}

if [ "$DO_X11" = 1 ] || [ "$DO_XCONT" = 1 ]; then
  say "Setting up Termux:X11"
  pkg install -y termux-x11-nightly
  make_plasma_stop
fi

if [ "$DO_X11" = 1 ]; then
  say "Setting up the Plasma X11 session"

  # Newer Plasma ships the X11 session as separate packages. Add them only if
  # the repo has them, and only if apt leaves the Wayland packages alone.
  X11_WANT=()
  if ! command -v kwin_x11 >/dev/null 2>&1 && apt-cache show kwin-x11 >/dev/null 2>&1; then
    X11_WANT+=(kwin-x11)
  fi
  if ! command -v startplasma-x11 >/dev/null 2>&1 && apt-cache show plasma-workspace-x11 >/dev/null 2>&1; then
    X11_WANT+=(plasma-workspace-x11)
  fi
  if [ "${#X11_WANT[@]}" -gt 0 ]; then
    if x11_pkgs_safe "${X11_WANT[@]}"; then
      pkg install -y "${X11_WANT[@]}" || warn "Could not install ${X11_WANT[*]}."
    else
      warn "Skipped ${X11_WANT[*]}: it cannot be installed without changing the patched Wayland packages."
    fi
  fi

  if command -v kwin_x11 >/dev/null 2>&1 && command -v startplasma-x11 >/dev/null 2>&1; then
    X11_READY=1
  else
    warn "kwin_x11 / startplasma-x11 are not available in your Termux packages (the Anland KWin is Wayland only). 'plasma-x11' is installed but will not start until they are."
  fi

  cat > "$PREFIX/bin/plasma-x11" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Start the Plasma X11 session on the Termux:X11 display app.
if ! command -v kwin_x11 >/dev/null 2>&1 || ! command -v startplasma-x11 >/dev/null 2>&1; then
  echo "The Plasma X11 session (kwin_x11 / startplasma-x11) is not installed." >&2
  echo "Re-run anland-menu > Install / update with part 5 ticked, or see the README." >&2
  exit 1
fi
termux-wake-lock 2>/dev/null || true
plasma-stop
sleep 1
export XDG_RUNTIME_DIR="$TMPDIR/run"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
rm -f "$TMPDIR/.X11-unix/X1" "$TMPDIR/.X1-lock"
termux-x11 :1 >/dev/null 2>&1 &
for _ in $(seq 20); do [ -S "$TMPDIR/.X11-unix/X1" ] && break; sleep 1; done
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
# Plain X11 session: no Wayland variables, no Anland GPU variables.
unset WAYLAND_DISPLAY QT_QPA_PLATFORM EGL_PLATFORM MESA_LOADER_DRIVER_OVERRIDE \
      GALLIUM_DRIVER FD_FORCE_KGSL TURNIP_KMD
export DISPLAY=:1 ANLAND_SESSION=x11 XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE XDG_SESSION_DESKTOP=KDE KDE_FULL_SESSION=true
export LIBGL_ALWAYS_SOFTWARE=1
exec dbus-run-session startplasma-x11
EOF
  chmod +x "$PREFIX/bin/plasma-x11"
fi

if [ "$DO_X11" = 1 ] || [ "$DO_XCONT" = 1 ]; then
  say "Downloading the Termux:X11 display app"
  XREL=$(gh_api repos/termux/termux-x11/releases/tags/nightly 2>/dev/null || true)
  XAPK=$(jq -r '[.assets[]? | select(.name == "app-arm64-v8a-debug.apk") | .browser_download_url][0] // empty' <<<"$XREL" 2>/dev/null || true)
  if [ -z "$XAPK" ]; then
    XAPK=$(jq -r '[.assets[]? | select(.name == "app-universal-debug.apk") | .browser_download_url][0] // empty' <<<"$XREL" 2>/dev/null || true)
  fi
  if [ -z "$XAPK" ]; then
    warn "Could not find the Termux:X11 APK. Get it from https://github.com/termux/termux-x11/releases/tag/nightly"
  elif [ -d "$HOME/storage/downloads" ]; then
    XAPKFILE="$HOME/storage/downloads/$(basename "$XAPK")"
    if curl -fL -# -o "$XAPKFILE" "$XAPK"; then
      termux-open "$XAPKFILE" || true
      echo "Install the app from the prompt or from Downloads: $(basename "$XAPKFILE")"
      echo "(Keep the Termux:X11 app and the termux-x11-nightly package on the same nightly.)"
    else
      warn "Download failed. Get the APK from $XAPK"
    fi
  else
    warn "No storage access. Download and install this APK yourself: $XAPK"
  fi
fi

# ------------------------------------------------- X11 desktop containers ----
# A desktop in a proot-distro container, shown on the Termux:X11 app with software
# rendering: Plasma (X11 session) for Ubuntu and Debian, XFCE4 for Arch. No Anland
# patches are needed, so any release works as long as the image is Debian/Ubuntu-
# based (Ubuntu and Debian slots) or Arch-based (Arch slot). Runs as root, like
# ubuntush/debiansh.
# args: label name image start-command custom-image(0/1) desktop(plasma|xfce) family(debian|arch)
setup_x11_container() {
  local label=$1 name=$2 image=$3 startcmd=$4 custom=$5 desktop=$6 family=$7
  local fresh=0 fam got want got_desktop

  say "Setting up the $label X11 desktop container '$name'"
  if ! proot-distro login "$name" -- true >/dev/null 2>&1; then
    proot-distro install "$image" --name "$name"
    fresh=1
  elif [ "$custom" = 1 ]; then
    warn "Container '$name' already exists, so the chosen image is not used. To switch: proot-distro remove $name"
  fi

  # The package manager (and so the desktop packages) depend on the distro family.
  fam=$(proot-distro login "$name" -- sh -c '. /etc/os-release 2>/dev/null; printf "%s %s" "${ID:-}" "${ID_LIKE:-}"' 2>/dev/null || true)
  case $fam in
    *debian*|*ubuntu*) got=debian ;;
    *arch*) got=arch ;;
    *) got= ;;
  esac
  if [ "$got" != "$family" ]; then
    if [ "$fresh" = 1 ]; then proot-distro remove "$name" >/dev/null 2>&1 || true; fi
    if [ "$family" = debian ]; then want="a Debian- or Ubuntu-based"; else want="an Arch-based"; fi
    die "Container '$name' is '${fam:-unknown}': the $label slot needs $want image."
  fi

# Written to the shared tmp folder, which the container sees as /tmp.
cat > "$TMPDIR/x11-container-setup.sh" <<'XC_EOF'
#!/bin/bash
set -eu
export DEBIAN_FRONTEND=noninteractive
retry() {
  n=0
  until "$@"; do
    n=$((n + 1))
    [ "$n" -ge 5 ] && return 1
    echo "Download failed, retrying ($n/5)..."; sleep 5
  done
}
. /etc/os-release
SESSION=xfce
case "${ID:-} ${ID_LIKE:-}" in
  *debian*|*ubuntu*)
    retry apt-get update
    retry apt-get install -y dbus-x11 fonts-dejavu-core mesa-utils
    if [ "${DESKTOP:-plasma}" = plasma ]; then
      # "sddm-" keeps the login manager out: there is no systemd in proot.
      retry apt-get install -y plasma-desktop plasma-workspace konsole dolphin sddm-
      # Newer Plasma ships the X11 session as separate packages: add them if offered.
      for p in kwin-x11 plasma-workspace-x11; do
        if ! dpkg -s "$p" >/dev/null 2>&1 && apt-cache show "$p" >/dev/null 2>&1; then
          retry apt-get install -y "$p" || echo "Could not install $p."
        fi
      done
      if command -v startplasma-x11 >/dev/null 2>&1 && command -v kwin_x11 >/dev/null 2>&1; then
        SESSION=plasma
      else
        echo "!! This image has no Plasma X11 session: installing XFCE4 instead."
        retry apt-get install -y xfce4 xfce4-terminal
      fi
    else
      retry apt-get install -y xfce4 xfce4-terminal
    fi
    ;;
  *arch*)
    CONF=/etc/pacman.conf
    # Same pacman settings as the Arch terminal container (proot has no sandbox).
    grep -q '^DisableSandbox' "$CONF" || sed -i '/^\[options\]/a DisableSandbox' "$CONF"
    grep -q '^DisableDownloadTimeout' "$CONF" || sed -i '/^\[options\]/a DisableDownloadTimeout' "$CONF"
    grep -q '^IgnorePkg' "$CONF" || \
      sed -i '/^\[options\]/a IgnorePkg = linux-aarch64 linux-aarch64-headers linux-firmware' "$CONF"
    pacman-key --init
    pacman-key --populate
    retry pacman -Syu --noconfirm
    retry pacman -S --needed --noconfirm xfce4 xfce4-terminal ttf-dejavu mesa-utils
    ;;
esac

# The one command the Termux side runs to start the desktop.
if [ "$SESSION" = plasma ]; then
  cat > /usr/local/bin/x11-session <<'EOS'
#!/bin/sh
export XDG_CURRENT_DESKTOP=KDE XDG_SESSION_DESKTOP=KDE XDG_SESSION_TYPE=x11 KDE_FULL_SESSION=true
exec dbus-run-session -- startplasma-x11
EOS
else
  cat > /usr/local/bin/x11-session <<'EOS'
#!/bin/sh
exec dbus-run-session -- startxfce4
EOS
fi
chmod +x /usr/local/bin/x11-session
printf '%s' "$SESSION" > /tmp/x11-desktop-result
XC_EOF

  say "Installing the $desktop desktop in '$name' (this takes a while)"
  proot-distro login "$name" --shared-tmp -- env DESKTOP="$desktop" bash /tmp/x11-container-setup.sh
  got_desktop=$(cat "$TMPDIR/x11-desktop-result" 2>/dev/null || true)
  rm -f "$TMPDIR/x11-container-setup.sh" "$TMPDIR/x11-desktop-result"
  if [ -n "$got_desktop" ] && [ "$got_desktop" != "$desktop" ]; then
    warn "$label: no Plasma X11 session in this image, so XFCE4 was installed instead."
    X11_FALLBACK="$X11_FALLBACK $label"
  fi

  say "Installing the '$startcmd' command"
  make_plasma_stop
  cat > "$PREFIX/bin/$startcmd" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Start the X11 desktop of container @NAME@ on the Termux:X11 app.
termux-wake-lock 2>/dev/null || true
plasma-stop
sleep 1
rm -f "$TMPDIR/.X11-unix/X1" "$TMPDIR/.X1-lock"
termux-x11 :1 >/dev/null 2>&1 &
for _ in $(seq 20); do [ -S "$TMPDIR/.X11-unix/X1" ] && break; sleep 1; done
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
exec proot-distro login @NAME@ --shared-tmp -- env DISPLAY=:1 XDG_RUNTIME_DIR=/tmp/run \
  LIBGL_ALWAYS_SOFTWARE=1 LANG=C.UTF-8 \
  bash -c 'mkdir -p /tmp/run; chmod 700 /tmp/run; exec /usr/local/bin/x11-session'
EOF
  sed -i "s/@NAME@/$name/g" "$PREFIX/bin/$startcmd"
  chmod +x "$PREFIX/bin/$startcmd"
}

if [ "$DO_XUBUNTU" = 1 ]; then
  setup_x11_container Ubuntu "$XUBUNTU_NAME" "$XUBUNTU_IMAGE" x11-ubuntu \
    "$([ "$XUBUNTU_IMAGE" = "$XUBUNTU_IMAGE_DEFAULT" ] && echo 0 || echo 1)" plasma debian
fi
if [ "$DO_XDEBIAN" = 1 ]; then
  setup_x11_container Debian "$XDEBIAN_NAME" "$XDEBIAN_IMAGE" x11-debian \
    "$([ "$XDEBIAN_IMAGE" = "$XDEBIAN_IMAGE_DEFAULT" ] && echo 0 || echo 1)" plasma debian
fi
if [ "$DO_XARCH" = 1 ]; then
  setup_x11_container Arch "$XARCH_NAME" "$XARCH_IMAGE" x11-arch \
    "$([ "$XARCH_IMAGE" = "$XARCH_IMAGE_DEFAULT" ] && echo 0 || echo 1)" xfce arch
fi

# ------------------------------------------------- Ubuntu and Debian part ----
# Ubuntu 26.04 and Debian 13 share one routine: Anland's prebuilt image, then the
# patched XWayland and KWin and the distro's build of the GPU driver (Mesa).
# args: label name image xwayland-deb kwin-zip mesa-asset-regex shell-cmd plasma-cmd
#       release-codename custom-image(0/1)
setup_container() {
  local label=$1 name=$2 image=$3 xway=$4 kwin=$5 mesa_re=$6 shcmd=$7 plcmd=$8
  local codename=$9 custom=${10}
  local mesa udl fresh=0 have_cn

  say "Setting up the $label container '$name'"
  if ! proot-distro login "$name" -- true >/dev/null 2>&1; then
    proot-distro install "$image" --name "$name"
    fresh=1
  elif [ "$custom" = 1 ]; then
    warn "Container '$name' already exists, so the chosen image is not used. To switch: proot-distro remove $name"
  fi

  # The patched XWayland/KWin/Mesa only fit one release. For a custom image, check
  # the release first (a container made just now is removed again if it is wrong).
  if [ "$custom" = 1 ]; then
    have_cn=$(proot-distro login "$name" -- sh -c '. /etc/os-release 2>/dev/null; printf %s "${VERSION_CODENAME:-}"' 2>/dev/null || true)
    if [ "$have_cn" != "$codename" ]; then
      if [ "$fresh" = 1 ]; then proot-distro remove "$name" >/dev/null 2>&1 || true; fi
      die "Container '$name' is '${have_cn:-unknown}', not $label ($codename): the patched packages only fit $codename."
    fi
  fi

  say "Downloading Anland's patched XWayland/KWin for $label and its Mesa"
  mesa=$(mesa_url "$mesa_re")
  [ -n "$mesa" ] || die "No $label Mesa package found in mesa-for-android-container (rate limit? set GITHUB_TOKEN)."
  udl="$TMPDIR/container-setup"
  rm -rf "$udl"; mkdir -p "$udl"
  ( cd "$udl" && fetch "$xway" && fetch "$kwin" && fetch "$mesa" )

# Written to the shared tmp folder, which the container sees as /tmp.
cat > "$TMPDIR/container-root-setup.sh" <<'CT_EOF'
#!/bin/bash
set -eu
export DEBIAN_FRONTEND=noninteractive
D=/tmp/container-setup
cd "$D"

retry() {
  n=0
  until "$@"; do
    n=$((n + 1))
    [ "$n" -ge 5 ] && return 1
    echo "Download failed, retrying ($n/5)..."; sleep 5
  done
}
# --allow-change-held-packages lets a re-run replace packages pinned by an earlier run.
APT="apt-get install -y --reinstall --allow-downgrades --allow-change-held-packages"

# The Mesa archive is a plain file tree to extract over the system. Refuse it if
# it contains anything outside /usr, before any system file is touched.
MESA=$(ls "$D"/mesa-for-android-container*.tar.gz 2>/dev/null | head -n1 || true)
[ -n "$MESA" ] || { echo "Mesa archive not found in $D." >&2; exit 1; }
if tar -tzf "$MESA" | grep -v -E '^(\./)?usr(/|$)' | grep -v -x './' | grep -q .; then
  echo "Unexpected paths in the Mesa archive; not installing it." >&2
  exit 1
fi

retry apt-get update
retry apt-get install -y unzip
# Optional extras (audio for Plasma, mesa-utils for the GPU check); not fatal.
retry apt-get install -y mesa-utils pipewire-audio libcanberra-pulse || echo "Optional packages skipped."
retry apt-get install -y pipewire-libcamera || echo "pipewire-libcamera skipped."

# Anland's patched XWayland and KWin.
$APT "$D"/xwayland_*_arm64.deb
rm -rf "$D/kwin-debs"; mkdir -p "$D/kwin-debs"
unzip -o -q "$D"/kwin_anland-*.zip -d "$D/kwin-debs"
KDEBS=$(find "$D/kwin-debs" -name '*.deb')
[ -n "$KDEBS" ] || { echo "No .deb files in the KWin zip." >&2; exit 1; }
$APT $KDEBS

# Patched Mesa (KGSL / Adreno): extract over the system.
tar -xzf "$MESA" -C / --no-overwrite-dir
ldconfig

# Pin the patched packages so apt upgrade does not replace them.
for p in xwayland libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 mesa-libgallium \
         mesa-vulkan-drivers kwin-common kwin-data kwin-wayland libkwin6; do
  dpkg -s "$p" >/dev/null 2>&1 && apt-mark hold "$p" >/dev/null || true
done
rm -rf "$D"
CT_EOF

  say "Configuring $label (this takes a while)"
  proot-distro login "$name" --shared-tmp -- bash /tmp/container-root-setup.sh
  rm -rf "$udl" "$TMPDIR/container-root-setup.sh"

  say "Installing the '$shcmd' and '$plcmd' commands"
  make_plasma_stop
  printf '#!%s/bin/bash\nexec proot-distro login %s --shared-tmp "$@"\n' \
    "$PREFIX" "$name" > "$PREFIX/bin/$shcmd"
  printf '#!%s/bin/bash\nplasma-stop\nsleep 1\nanland >/dev/null 2>&1 &\nexec proot-distro login %s --shared-tmp -- bash -c "startplasma-anland"\n' \
    "$PREFIX" "$name" > "$PREFIX/bin/$plcmd"
  chmod +x "$PREFIX/bin/$shcmd" "$PREFIX/bin/$plcmd"
}

if [ "$DO_UBUNTU" = 1 ]; then
  setup_container "Ubuntu 26.04" "$UBUNTU_NAME" "$UBUNTU_IMAGE" "$UXWAY" "$UKWIN" \
    '^mesa-for-android-container.*ubuntu_resolute_arm64\.tar\.gz$' ubuntush plasma-ubuntu \
    resolute "$([ "$UBUNTU_IMAGE" = "$UBUNTU_IMAGE_DEFAULT" ] && echo 0 || echo 1)"
fi
if [ "$DO_DEBIAN" = 1 ]; then
  setup_container "Debian 13" "$DEBIAN_NAME" "$DEBIAN_IMAGE" "$DXWAY" "$DKWIN" \
    '^mesa-for-android-container.*debian_trixie_arm64\.tar\.gz$' debiansh plasma-debian \
    trixie "$([ "$DEBIAN_IMAGE" = "$DEBIAN_IMAGE_DEFAULT" ] && echo 0 || echo 1)"
fi

if [ "$DO_ARCH" = 1 ]; then
# -------------------------------------------------------------- Arch part ----
arch_cleanup() {
  proot-distro login "$ARCH_NAME" -- rm -f /etc/sudoers.d/99-setup-nopasswd >/dev/null 2>&1 || true
  rm -f "$TMPDIR/arch-root-setup.sh"
}

say "Setting up the Arch Linux ARM container '$ARCH_NAME'"
if ! proot-distro login "$ARCH_NAME" -- true >/dev/null 2>&1; then
  cd "$WORK"
  if [ -n "$ARCH_ROOTFS" ] && [[ $ARCH_ROOTFS != http://* && $ARCH_ROOTFS != https://* ]]; then
    # A local rootfs file chosen by the user.
    [ -s "$ARCH_ROOTFS" ] || die "Arch rootfs file not found: $ARCH_ROOTFS"
    ROOTFS_FILE=$ARCH_ROOTFS
  else
    if [ -n "$ARCH_ROOTFS" ]; then
      ROOTFS=${ARCH_ROOTFS##*/}; ROOTFS=${ROOTFS%%\?*}
      [ -n "$ROOTFS" ] || die "Cannot get a file name from ARCH_ROOTFS: $ARCH_ROOTFS"
      ROOTFS_URLS=("$ARCH_ROOTFS")
    else
      ROOTFS=ArchLinuxARM-aarch64-latest.tar.gz
      ROOTFS_URLS=("https://os.archlinuxarm.org/os/$ROOTFS" "http://os.archlinuxarm.org/os/$ROOTFS")
    fi
    if [ ! -s "$ROOTFS" ]; then
      # The rootfs is not signature-checked here; HTTPS is tried first.
      ROOTFS_OK=0
      for u in "${ROOTFS_URLS[@]}"; do
        if curl -fL -# -o "$ROOTFS.part" "$u"; then ROOTFS_OK=1; break; fi
      done
      [ "$ROOTFS_OK" = 1 ] || die "Could not download the Arch rootfs."
      mv "$ROOTFS.part" "$ROOTFS"
    fi
    ROOTFS_FILE=./$ROOTFS
  fi
  proot-distro install "$ROOTFS_FILE" --name "$ARCH_NAME"
  # The rest of the script needs pacman and the Arch Linux ARM keyring.
  if [ -n "$ARCH_ROOTFS" ] \
     && ! proot-distro login "$ARCH_NAME" -- sh -c 'grep -Eqi "^(ID|ID_LIKE)=.*arch" /etc/os-release' >/dev/null 2>&1; then
    proot-distro remove "$ARCH_NAME" >/dev/null 2>&1 || true
    die "'$ARCH_ROOTFS' is not an Arch Linux ARM rootfs."
  fi
elif [ -n "$ARCH_ROOTFS" ]; then
  warn "Container '$ARCH_NAME' already exists, so the chosen rootfs is not used. To switch: proot-distro remove $ARCH_NAME"
fi

say "Downloading the patched Mesa for Arch"
MESA_URL=$(mesa_url '^mesa-for-android-container.*archlinux_arm64\.tar$')
[ -n "$MESA_URL" ] || die "No Arch Mesa package found in mesa-for-android-container (rate limit? set GITHUB_TOKEN)."
rm -f "$TMPDIR"/mesa-for-android-container*.tar
( cd "$TMPDIR" && curl -fL -# -O "$MESA_URL" )

# Written to the shared tmp folder, which the container sees as /tmp.
cat > "$TMPDIR/arch-root-setup.sh" <<'ROOT_EOF'
#!/bin/bash
set -eu
: "${ARCH_USER:?}" "${ARCH_NAME:?}"
CONF=/etc/pacman.conf

# pacman's sandbox needs kernel features proot does not have; do not let
# kernel updates build initramfs images inside a container.
grep -q '^DisableSandbox' "$CONF" || sed -i '/^\[options\]/a DisableSandbox' "$CONF"
# Slow phone connections trip pacman's "Operation too slow" abort.
grep -q '^DisableDownloadTimeout' "$CONF" || sed -i '/^\[options\]/a DisableDownloadTimeout' "$CONF"

# Retry network steps; pacman keeps already-downloaded packages in its cache.
retry() {
  n=0
  until "$@"; do
    n=$((n + 1))
    [ "$n" -ge 5 ] && return 1
    echo "Download failed, retrying ($n/5)..."; sleep 5
  done
}
grep -q '^IgnorePkg' "$CONF" || \
  sed -i '/^\[options\]/a IgnorePkg = linux-aarch64 linux-aarch64-headers linux-firmware' "$CONF"

pacman-key --init
pacman-key --populate archlinuxarm
retry pacman -Syu --noconfirm
retry pacman -S --needed --noconfirm sudo base-devel git ttf-dejavu ttf-liberation qt6-wayland

# Patched Mesa (KGSL / Adreno), then pin it so updates do not replace it.
rm -rf /tmp/mesa-arch; mkdir -p /tmp/mesa-arch
tar -xf /tmp/mesa-for-android-container*archlinux_arm64.tar -C /tmp/mesa-arch
pacman -U --noconfirm /tmp/mesa-arch/*.pkg.tar.*
retry pacman -S --needed --noconfirm mesa-utils
grep -q 'vulkan-freedreno' "$CONF" || \
  sed -i '/^IgnorePkg/ s/$/ mesa mesa-docs vulkan-freedreno vulkan-mesa-layers vulkan-mesa-implicit-layers/' "$CONF"
rm -rf /tmp/mesa-arch /tmp/mesa-for-android-container*.tar

# Normal user with sudo (temporary passwordless sudo is removed afterwards).
id "$ARCH_USER" >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash "$ARCH_USER"
printf '%s ALL=(ALL:ALL) ALL\n' "$ARCH_USER" > "/etc/sudoers.d/$ARCH_USER"
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$ARCH_USER" > /etc/sudoers.d/99-setup-nopasswd
chmod 440 "/etc/sudoers.d/$ARCH_USER" /etc/sudoers.d/99-setup-nopasswd

# Locale and fonts (without these Qt shows boxes instead of text).
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
fc-cache -f

# Kickoff sync: mirror Arch .desktop files into the Plasma menu, each one
# launching through the container with 'archrun' (on the Termux side), which
# picks the display settings of the running session: Wayland + GPU, or X11.
cat > /usr/local/bin/sync-kickoff <<'SYNC_EOF'
#!/bin/bash
OUT=${KICKOFF_OUT:-/termux-apps}
SRC=${KICKOFF_SRC:-/usr/share/applications}
[ -d "$OUT" ] || exit 0
rm -f "$OUT"/arch-*.desktop
for f in "$SRC"/*.desktop; do
  [ -e "$f" ] || continue
  sed -E \
    -e '/^(TryExec|DBusActivatable)=/d' \
    -e 's|^Exec=(.*)|Exec=archrun \1|' \
    -e 's|^Name=|Name=[Arch] |' \
    "$f" > "$OUT/arch-$(basename "$f")"
done
SYNC_EOF
chmod +x /usr/local/bin/sync-kickoff

mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/kickoff.hook <<'HOOK_EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Path
Target = usr/share/applications/*.desktop

[Action]
Description = Syncing apps to KDE Kickoff
When = PostTransaction
Exec = /usr/local/bin/sync-kickoff
HOOK_EOF
ROOT_EOF

trap arch_cleanup EXIT
say "Configuring Arch (this takes a while)"
proot-distro login "$ARCH_NAME" --shared-tmp -- \
  env ARCH_USER="$ARCH_USER" ARCH_NAME="$ARCH_NAME" bash /tmp/arch-root-setup.sh

say "Password for '$ARCH_USER' inside Arch"
if [ "$(proot-distro login "$ARCH_NAME" -- passwd -S "$ARCH_USER" 2>/dev/null | awk '{print $2}')" != P ]; then
  proot-distro login "$ARCH_NAME" -- passwd "$ARCH_USER"
fi

say "Installing yay"
proot-distro login "$ARCH_NAME" --user "$ARCH_USER" --shared-tmp -- bash -c '
  set -e
  command -v yay >/dev/null && exit 0
  cd ~ && rm -rf yay-bin
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git
  cd yay-bin && makepkg -si --noconfirm
  cd ~ && rm -rf yay-bin
'

say "Installing the 'archsh', 'archrun' and 'ksync' commands"
mkdir -p "$HOME/.local/share/applications"
cat > "$PREFIX/bin/archsh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login @ARCH_NAME@ --user @ARCH_USER@ --shared-tmp --bind "$HOME/.local/share/applications:/termux-apps" "$@"
EOF
# archrun: launched by the [Arch] Kickoff entries. Runs a command in the container
# with the display settings of the running session. Without ANLAND_SESSION it
# behaves as the Wayland session (the original behaviour).
cat > "$PREFIX/bin/archrun" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
case ${ANLAND_SESSION:-wayland} in
  x11)
    ENVV=(LANG=en_US.UTF-8 XDG_RUNTIME_DIR=/tmp/run DISPLAY="${DISPLAY:-:1}"
          QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1) ;;
  *)
    ENVV=(MESA_LOADER_DRIVER_OVERRIDE=kgsl TURNIP_KMD=kgsl GALLIUM_DRIVER=freedreno
          FD_FORCE_KGSL=1 LANG=en_US.UTF-8 XDG_RUNTIME_DIR=/tmp/run
          WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland) ;;
esac
exec proot-distro login @ARCH_NAME@ --user @ARCH_USER@ --shared-tmp -- env "${ENVV[@]}" "$@"
EOF
cat > "$PREFIX/bin/ksync" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec archsh -- /usr/local/bin/sync-kickoff
EOF
sed -i "s/@ARCH_NAME@/$ARCH_NAME/g; s/@ARCH_USER@/$ARCH_USER/g" "$PREFIX/bin/archsh" "$PREFIX/bin/archrun"
chmod +x "$PREFIX/bin/archsh" "$PREFIX/bin/archrun" "$PREFIX/bin/ksync"
ksync
fi

# Keep a copy of this script as the "anland-menu" command.
if [ -f "$SELF" ] && grep -q 'anland-arch-setup' "$SELF" && ! [ "$SELF" -ef "$PREFIX/bin/anland-menu" ]; then
  cp "$SELF" "$PREFIX/bin/anland-menu.new"
  chmod +x "$PREFIX/bin/anland-menu.new"
  mv -f "$PREFIX/bin/anland-menu.new" "$PREFIX/bin/anland-menu"
fi

# ------------------------------------------------------------------ summary ----
cat <<'MSG'

All done. Run  anland-menu  any time to get the menu.

  1. Install the Anland display app if you have not yet (see the prompt above).
  2. Start ONE desktop at a time from the Termux app, then open "Anland Termux":
MSG
if [ "$DO_NATIVE" = 1 ]; then echo "       plasma          native Plasma"; fi
if [ "$DO_X11" = 1 ]; then echo "       plasma-x11      Plasma X11 session (Termux:X11 app, software rendering)"; fi
if [ "$DO_XUBUNTU" = 1 ]; then echo "       x11-ubuntu      Ubuntu Plasma desktop (Termux:X11 app, software rendering)"; fi
if [ "$DO_XDEBIAN" = 1 ]; then echo "       x11-debian      Debian Plasma desktop (Termux:X11 app, software rendering)"; fi
if [ "$DO_XARCH" = 1 ]; then echo "       x11-arch        Arch XFCE4 desktop (Termux:X11 app, software rendering)"; fi
if [ "$DO_UBUNTU" = 1 ]; then echo "       plasma-ubuntu   Ubuntu 26.04 Plasma"; fi
if [ "$DO_DEBIAN" = 1 ]; then echo "       plasma-debian   Debian 13 Plasma"; fi
echo "       plasma-stop     stop whichever desktop is running"
if [ "$DO_X11" = 1 ] && [ "$X11_READY" = 0 ]; then
  echo; echo "  Note: the X11 session is not usable yet (kwin_x11 / startplasma-x11 missing); Wayland is unaffected."
fi
if [ -n "$X11_FALLBACK" ]; then
  echo; echo "  Note: no Plasma X11 session was available for$X11_FALLBACK, so XFCE4 was installed there instead."
fi
if [ "$DO_ARCH" = 1 ]; then
cat <<'MSG'
  3. Arch:   archsh   then: yay -S <app>   (it appears in Kickoff by itself)

Check the GPU for Arch apps from Konsole inside native Plasma:
  archsh -- env MESA_LOADER_DRIVER_OVERRIDE=kgsl TURNIP_KMD=kgsl GALLIUM_DRIVER=freedreno \
    FD_FORCE_KGSL=1 XDG_RUNTIME_DIR=/tmp/run WAYLAND_DISPLAY=wayland-0 eglinfo -B
Look for "FD6xx" (freedreno) under the Wayland platform; "llvmpipe" means CPU only.
MSG
fi
if [ "$DO_UBUNTU" = 1 ]; then
cat <<'MSG'

Ubuntu: ubuntush   then: apt install <app>   (it appears in Ubuntu's Kickoff)
Check its GPU from Konsole inside the Ubuntu desktop: eglinfo -B  (look for "FD6xx").
MSG
fi
if [ "$DO_DEBIAN" = 1 ]; then
cat <<'MSG'

Debian: debiansh   then: apt install <app>   (it appears in Debian's Kickoff)
Check its GPU from Konsole inside the Debian desktop: eglinfo -B  (look for "FD6xx").
MSG
fi
