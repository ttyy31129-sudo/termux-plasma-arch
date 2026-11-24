# termux-plasma-arch

KDE Plasma on Android: a native, GPU-accelerated Plasma desktop in Termux (via [Anland](https://github.com/lfdevs/anland-termux)), plus an Arch Linux container whose `yay`/`pacman` apps show up in the Plasma Kickoff menu and draw on the same desktop with the Adreno GPU. No root needed.

One script sets up everything and gives you a menu to run it. It can also add an **Ubuntu 26.04** and a **Debian 13** container, each with its own Plasma desktop, and an optional **X11** side: a Plasma X11 session and X11 desktop containers (Ubuntu and Debian with Plasma, Arch with XFCE4). Wayland stays the default and is never replaced. Every container image can be chosen from the menu.

## What you get

- **Native Plasma (Wayland)** running in Termux, with Konsole and Dolphin, using the KGSL driver for GPU acceleration.
- **An Arch Linux ARM container** (proot-distro) with a normal user, `sudo`, fonts, locale and [`yay`](https://github.com/Jguer/yay).
- **Kickoff menu sync**: every app you install in Arch appears in Kickoff as `[Arch] <app>`. A pacman hook keeps the menu up to date after every install, upgrade or removal.
- **GPU for Arch apps**: a patched Mesa (Freedreno/KGSL) is installed in Arch and pinned so `pacman -Syu` doesn't replace it.
- **Optional Ubuntu 26.04 and Debian 13 desktops**: Anland's prebuilt images with Plasma, the patched KWin/XWayland and the distro's GPU driver, with `apt` apps in their own Kickoff menu.
- **Optional X11 session** (extra, next to Wayland): a Plasma X11 session on the separate **Termux:X11** app, with GPU through KGSL (the Adreno directly) and the CPU as the fallback.
- **Optional X11 desktop containers** on Termux:X11: **Ubuntu** and **Debian** with Plasma (X11 session), **Arch** with XFCE4.
- **Choose the images**: the Ubuntu, Debian and Arch images, and the three X11 container images, can be picked from the menu or set with variables.
- **A main menu** (`anland-menu`) to install, start and stop desktops and open the shells, plus short commands: `plasma`, `plasma-ubuntu`, `plasma-debian`, `plasma-x11`, `x11-ubuntu`, `x11-debian`, `x11-arch`, `plasma-stop`, `archsh`, `ubuntush`, `debiansh`, `ksync`.

## Requirements

- A **Snapdragon (Adreno GPU)** phone, arm64. The Anland GPU path needs Adreno.
- **Termux** from GitHub releases or F-Droid (not the Play Store build).
- Wi-Fi and roughly 6 GB of free storage (more for each extra container; a Plasma desktop container needs several GB).
- The script picks the matching **Anland Termux** display app for your Termux build and offers to install it.
- For the X11 options only: the **Termux:X11** app. The script downloads it to your Downloads folder and offers to install it, like the Anland app.

## Install

Run this in Termux (not inside a container):

```
curl -LO https://raw.githubusercontent.com/ttyy31129-sudo/termux-plasma-arch/main/anland-arch-setup.sh
bash anland-arch-setup.sh
```

Download it first rather than piping into `bash`: the script asks for the password of your Arch user, and a pipe breaks that prompt.

The script opens the main menu. Choose **1) Install / update**, tick the parts you want, then press `g`:

```
  Install / update
   [x] 1  Native Plasma in Termux (GPU)
   [x] 2  Arch Linux container + yay + Kickoff sync (needs 1)
   [ ] 3  Ubuntu 26.04 desktop container
   [ ] 4  Debian 13 desktop container
   [ ] 5  Plasma X11 session, Termux:X11 app (extra, needs 1)
   [ ] 6  Ubuntu Plasma X11 container
   [ ] 7  Debian Plasma X11 container
   [ ] 8  Arch XFCE4 X11 container

  Images: default

  1-8 = tick / untick   i = choose images
  g = go   b = back
```

Arch (2) and the X11 session (5) need native Plasma, so ticking one of them ticks 1, and unticking 1 unticks 2 and 5. The X11 containers (6 to 8) do not: untick 1 and 2 and tick only 6 to 8 to install them without native Plasma or the Anland display app. If you tick Arch, it asks for the username (it keeps the one from an earlier run). Press `i` to choose the images (see [Choosing images](#choosing-images)).

The install takes a while (large downloads). When it finishes:

1. Install the Anland display app if you haven't yet. The script downloads it to your Downloads folder and tries to open it. If you ticked an X11 part, do the same for the Termux:X11 app.
2. Run `anland-menu` and choose **2) Start native Plasma**, then switch to the **Anland Termux** app.

### Main menu

The script keeps a copy of itself as the `anland-menu` command, so the menu is one word away:

| Menu entry                      | What it does                                                          |
| ------------------------------- | --------------------------------------------------------------------- |
| 1) Install / update             | Tick the parts, choose images, then install or repair them            |
| 2) Start native Plasma          | Runs `plasma`                                                         |
| 3) Start Ubuntu Plasma          | Runs `plasma-ubuntu`                                                  |
| 4) Start Debian Plasma          | Runs `plasma-debian`                                                  |
| 5) Stop the running desktop     | Runs `plasma-stop`                                                    |
| 6) Arch shell (yay)             | Runs `archsh`                                                         |
| 7) Ubuntu shell (apt)           | Runs `ubuntush`                                                       |
| 8) Debian shell (apt)           | Runs `debiansh`                                                       |
| 9) Sync Arch apps to Kickoff    | Runs `ksync`                                                          |
| x) X11 desktops (Termux:X11)    | Opens a submenu: Plasma X11 (native), Ubuntu, Debian or Arch X11      |
| u) Update this menu from GitHub | Downloads the newest script and restarts the menu                     |

Each entry shows whether its part is installed. Use the menu from the Termux app, not from Konsole inside Plasma: starting or stopping a desktop closes the one you are in.

### Options (skip the menu)

Options install straight away without the menu, which is useful for re-running or scripting. Without a terminal (for example piped) and without options, it installs native Plasma and Arch.

| Option / variable | Meaning | Default |
| ----------------- | ------- | ------- |
| `--no-arch` | Skip the Arch container | off |
| `--ubuntu` | Also set up the Ubuntu 26.04 container | off |
| `--debian` | Also set up the Debian 13 container | off |
| `--ubuntu-only` | Only Anland and the Ubuntu container (no native Plasma, no Arch) | off |
| `--debian-only` | Only Anland and the Debian container (no native Plasma, no Arch) | off |
| `--x11-only` | Only the X11 containers you add with `--x11-ubuntu`, `--x11-debian` or `--x11-arch`: no native Plasma, no Anland, no Arch terminal container | off |
| `--x11` | Also set up the Plasma X11 session (Termux:X11 app) | off |
| `--x11-ubuntu` | Also set up an Ubuntu Plasma (X11) container | off |
| `--x11-debian` | Also set up a Debian Plasma (X11) container | off |
| `--x11-arch` | Also set up an Arch XFCE4 container | off |
| `ARCH_USER` | Username created in Arch (the menu offers it as the default) | `arch` |
| `ARCH_NAME` | Arch container name | `archlinux` |
| `UBUNTU_NAME` | Ubuntu container name | `ubuntu-anland` |
| `DEBIAN_NAME` | Debian container name | `debian-anland` |
| `XUBUNTU_NAME` | Ubuntu X11 container name | `ubuntu-x11` |
| `XDEBIAN_NAME` | Debian X11 container name | `debian-x11` |
| `XARCH_NAME` | Arch X11 container name | `arch-x11` |
| `UBUNTU_IMAGE` | Image for the Ubuntu 26.04 container | Anland's 26.04 image |
| `DEBIAN_IMAGE` | Image for the Debian 13 container | Anland's 13 image |
| `ARCH_ROOTFS` | Arch rootfs: a local file or an https URL | Arch Linux ARM latest |
| `XUBUNTU_IMAGE` | Image for the Ubuntu X11 container | `ubuntu` |
| `XDEBIAN_IMAGE` | Image for the Debian X11 container | `debian` |
| `XARCH_IMAGE` | Image for the Arch X11 container | `archlinux` |
| `ANLAND_DIR` | Download/work folder | `~/anland` |
| `GITHUB_TOKEN` | Optional, avoids GitHub API rate limits | unset |

`--x11` (the Plasma X11 session) needs native Plasma: don't combine it with `--ubuntu-only`, `--debian-only` or `--x11-only`. The container options (`--x11-ubuntu`, `--x11-debian`, `--x11-arch`) work with or without native Plasma.

Examples:

```
ARCH_USER=bob bash anland-arch-setup.sh                   # native Plasma + Arch
bash anland-arch-setup.sh --ubuntu                        # native Plasma + Arch + Ubuntu
bash anland-arch-setup.sh --ubuntu-only                   # just Ubuntu
bash anland-arch-setup.sh --debian-only                   # just Debian
bash anland-arch-setup.sh --x11                           # add the Plasma X11 session
bash anland-arch-setup.sh --x11-ubuntu --x11-arch         # Ubuntu Plasma + Arch XFCE4 on Termux:X11
bash anland-arch-setup.sh --x11-only --x11-ubuntu         # only the Ubuntu Plasma X11 container (no native Plasma, no Anland)
ARCH_ROOTFS=~/storage/downloads/my-arch.tar.gz bash anland-arch-setup.sh
XDEBIAN_IMAGE=~/storage/downloads/debian-rootfs.tar.xz bash anland-arch-setup.sh --x11-debian
```

The script is safe to re-run: finished steps are skipped or repeated harmlessly.

## Commands

| Command         | What it does |
| --------------- | ------------ |
| `anland-menu`   | Opens the main menu. |
| `plasma`        | Starts native Plasma. Then open the **Anland Termux** app. |
| `plasma-ubuntu` | Starts the Ubuntu desktop instead (with `--ubuntu`). |
| `plasma-debian` | Starts the Debian desktop instead (with `--debian`). |
| `plasma-x11`    | Starts the Plasma X11 session and opens **Termux:X11** (with `--x11`). |
| `x11-ubuntu`    | Starts the Ubuntu Plasma X11 desktop on Termux:X11 (with `--x11-ubuntu`). |
| `x11-debian`    | Starts the Debian Plasma X11 desktop on Termux:X11 (with `--x11-debian`). |
| `x11-arch`      | Starts the Arch XFCE4 desktop on Termux:X11 (with `--x11-arch`). |
| `plasma-stop`   | Stops whichever desktop is running (Wayland, X11 session or X11 container). |
| `archsh`        | Opens a shell in the Arch container as your user. Install apps with `yay -S <app>`. |
| `ubuntush`      | Opens a shell in the Ubuntu container (root). Install apps with `apt install <app>`. |
| `debiansh`      | Opens a shell in the Debian container (root). Install apps with `apt install <app>`. |
| `ksync`         | Rebuilds the `[Arch]` Kickoff entries by hand (normally the pacman hook does this). |
| `archrun`       | Internal. The `[Arch]` Kickoff entries use it to run an app with the right display settings. |

Run these from the Termux app, not from Konsole inside Plasma: starting a desktop stops the one that is running. For the X11 containers there are no extra shell commands; use `proot-distro login ubuntu-x11` (or `debian-x11`, `arch-x11`).

## Ubuntu and Debian desktops (optional)

Ticking **3** or **4** in the install menu (or `--ubuntu` / `--debian`) installs Anland's prebuilt image as a proot-distro container:

| Desktop                   | Image                                          | Container name  |
| ------------------------- | ---------------------------------------------- | --------------- |
| Ubuntu 26.04 ("resolute") | `ghcr.io/lfdevs/ubuntu:resolute-anland-plasma` | `ubuntu-anland` |
| Debian 13 ("trixie")      | `ghcr.io/lfdevs/debian:trixie-anland-plasma`   | `debian-anland` |

The script then adds Anland's patched XWayland and KWin and the distro's build of the GPU driver (Mesa), and pins them so `apt upgrade` doesn't replace them.

- Start them with `plasma-ubuntu` or `plasma-debian`, then open **Anland Termux**.
- Each is a separate desktop from native Plasma. They all draw in the Anland app, so run **one at a time**; every start command stops the others first.
- Apps installed with `apt` appear in that desktop's own Kickoff menu; no sync script is needed.
- Only Ubuntu 26.04 and Debian 13 are supported.
- GPU check: open Konsole inside the desktop and run `eglinfo -B`. The renderer should be `FD6xx` (freedreno).

## X11 (optional)

Anland itself is Wayland only, so the X11 options use a different display path: the separate **Termux:X11** app. Wayland stays the default and is never replaced; you pick X11 by starting it.

**Plasma X11 session** (part 5, `--x11`, command `plasma-x11`):

- Installs the `termux-x11-nightly` package, downloads the Termux:X11 app from its nightly release, and creates `plasma-x11`.
- `plasma-x11` stops any running desktop, starts the X server on display `:1`, opens Termux:X11 and runs `startplasma-x11`.
- It needs `kwin_x11` and `startplasma-x11`. Newer Plasma ships the X11 session as separate packages (`kwin-x11`, `plasma-workspace-x11`). The script installs them only if your Termux repo has them, and only if apt would not change the patched Wayland packages. If they are missing, the script says so, Wayland is unaffected, and `plasma-x11` refuses to start with a clear message.
- **GPU through KGSL**, the same patched Mesa the Wayland desktops use, with the CPU as the fallback; see [GPU on X11](#gpu-on-x11). The Anland display app is not involved: Termux:X11 shows the picture.
- **KWin compositing is off by default** (`KWIN_COMPOSE=N`), because GL on Termux:X11 can leave the screen black. The cost is no desktop effects. To try compositing again, run `KWIN_COMPOSE=O2 plasma-x11` (OpenGL) or `KWIN_COMPOSE=Q plasma-x11` (QPainter).
- Arch apps in the Kickoff menu work in the X11 session too: the `[Arch]` entries use `archrun`, which picks X11 or Wayland+GPU settings from the running session.
- Keep the Termux:X11 app and the `termux-x11-nightly` package on the same nightly build.

**X11 desktop containers** (parts 6 to 8) are covered in the next section.

## X11 desktop containers (optional)

Ticking **6**, **7** or **8** (or `--x11-ubuntu`, `--x11-debian`, `--x11-arch`) creates a separate proot-distro container with a desktop, shown on the Termux:X11 app:

| Container | Desktop                  | Default image | Container name | Start command |
| --------- | ------------------------ | ------------- | -------------- | ------------- |
| Ubuntu    | Plasma (X11 session)     | `ubuntu`      | `ubuntu-x11`   | `x11-ubuntu`  |
| Debian    | Plasma (X11 session)     | `debian`      | `debian-x11`   | `x11-debian`  |
| Arch      | XFCE4                    | `archlinux`   | `arch-x11`     | `x11-arch`    |

- The default images are proot-distro's own `ubuntu`, `debian` and `archlinux`. No Anland patches are needed, so any release works.
- They need **neither native Plasma nor Anland**: untick 1 and 2 in the install menu and tick only 6 to 8 (or use `--x11-only` with the container options). They only need the Termux:X11 app.
- **GPU through KGSL** when a patched Mesa exists for the image's release (the script installs and pins it), otherwise the CPU. `X11_GPU=off x11-ubuntu` forces the CPU. See [GPU on X11](#gpu-on-x11).
- **Plasma fallback**: if a Ubuntu or Debian image has no Plasma X11 session, the script installs XFCE4 there instead and tells you, both during the install and in the final summary.
- Start one with its command or from the main menu (`x`). They use the same X server as the Plasma X11 session, so run **one at a time**; every start command stops the others first.
- **KWin compositing is off by default** in the Plasma containers too (set in `/usr/local/bin/x11-session` inside the container; change `KWIN_COMPOSE` there to try it).
- Plasma in a container is heavy: expect high RAM use and several GB of storage per container.
- They run as root, like `ubuntush` and `debiansh`, so some apps show root warnings or refuse to start.
- They are separate from the Arch terminal container (`archlinux`) and from the Anland Ubuntu/Debian desktops.
- If you have an `ubuntu-x11` or `debian-x11` container from an earlier XFCE-only version, remove it first (`proot-distro remove ubuntu-x11`), otherwise the script reuses it.

## Choosing images

Press `i` on the install screen to open the **Images** screen:

```
  Images
   1  Ubuntu 26.04 (Wayland)
   2  Debian 13 (Wayland)
   3  Arch rootfs (terminal)
   4  Ubuntu Plasma X11
   5  Debian Plasma X11
   6  Arch XFCE4 X11

  1-6 = change   r = reset all   b = back
```

Pick a slot, then choose the default, type an image, path or https URL, or (slots 3 to 6) pick a rootfs file (`.tar.gz`, `.tar.xz`, `.tar.zst`) found in your Downloads folder. The same choices exist as variables (`UBUNTU_IMAGE`, `DEBIAN_IMAGE`, `ARCH_ROOTFS`, `XUBUNTU_IMAGE`, `XDEBIAN_IMAGE`, `XARCH_IMAGE`; see the options table).

What each slot accepts:

| Slot | What it takes |
| ---- | ------------- |
| 1, 2 (Ubuntu and Debian, Wayland) | An image of the same release: **Ubuntu 26.04** and **Debian 13**. The patched KWin, XWayland and Mesa only fit those releases, so a custom image is checked and rejected if it is another release. This suits mirrors, pinned tags and your own builds. |
| 3 (Arch rootfs) | A local file or https URL for an **Arch Linux ARM** based rootfs. Anything that is not Arch-based is rejected. |
| 4, 5 (Ubuntu and Debian X11) | Any Debian- or Ubuntu-based image. |
| 6 (Arch X11) | Any Arch-based image. |

Good to know:

- An image is only used when its container does **not exist yet**. If it already exists you get a warning; to switch, remove it first (`proot-distro remove <name>`) and run the install again.
- A container made from a rejected image is removed again; a container that already existed is never removed.
- Local files are turned into absolute paths when you start the install.
- Custom files and URLs are not checksum-verified. The same is true for the default Arch download.

## Check that the GPU is used

In Konsole inside Plasma (Wayland):

```
archsh -- env MESA_LOADER_DRIVER_OVERRIDE=kgsl TURNIP_KMD=kgsl GALLIUM_DRIVER=freedreno \
  FD_FORCE_KGSL=1 XDG_RUNTIME_DIR=/tmp/run WAYLAND_DISPLAY=wayland-0 eglinfo -B
```

Under **Wayland platform**, the renderer should be `FD6xx` (freedreno). If it says `llvmpipe`, rendering is on the CPU. For the X11 desktops see [GPU on X11](#gpu-on-x11).

## GPU on X11

Why KGSL at all: stock Android phones don't expose the open-source Adreno driver that normal Linux Mesa uses; they use Qualcomm's own kernel interface, **KGSL** (`/dev/kgsl-3d0`). The patched Mesa builds from the [mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container) and [lfdevs/termux-packages](https://github.com/lfdevs/termux-packages) projects add a KGSL backend to Mesa's Freedreno/Turnip drivers, so open-source Mesa can use the GPU without root. **Anland** is a separate thing: the display app and patched KWin for the Wayland desktops. The X11 desktops don't use Anland, only the same KGSL Mesa, and Termux:X11 does the display.

The X11 start commands (`plasma-x11`, `x11-ubuntu`, `x11-debian`, `x11-arch`) pick a GPU mode when they start and print `GPU mode: ...`:

| Mode | What it is | When it is used |
| ---- | ---------- | --------------- |
| `kgsl` | The patched Mesa draws on the Adreno directly (`MESA_LOADER_DRIVER_OVERRIDE=kgsl`) | Default. Native session: if `/dev/kgsl-3d0` exists. Containers: if a patched Mesa was installed for the image's release. |
| `software` | The CPU (`llvmpipe`) | When KGSL isn't available, or with `X11_GPU=off`. |

- Force the CPU when starting: `X11_GPU=off x11-ubuntu`, `X11_GPU=off plasma-x11`, and so on (`auto` is the default).
- **Native session**: uses the patched `mesa` that part 1 installs and pins. It needs a recent build (the fix for presenting on Termux:X11 came in the 2026-06-10 builds); re-run the install to get the newest.
- **Containers**: the script downloads the patched Mesa that matches the image's release (for example `ubuntu_noble` or `debian_trixie` for Debian/Ubuntu images, `archlinux` for Arch), checks that the archive only writes under `/usr`, installs it and pins it so updates don't replace it. If there is no build for that release you get a warning and that container uses the CPU.
- Check it inside an X11 desktop with `glxinfo -B`: an Adreno or freedreno renderer means KGSL, `llvmpipe` means the CPU. In a container `glxinfo` is installed; in Termux run `pkg install mesa-utils` first.
- Arch apps started from the Kickoff menu in the X11 session follow the same mode.
- KWin compositing stays off by default (`KWIN_COMPOSE=N`) even with the GPU; try `KWIN_COMPOSE=O2 plasma-x11` once the GPU mode works.
- If the screen goes black or an app crashes in `kgsl` mode, try `X11_GPU=off` and tell us what happened.

## How it works

- Termux runs `kwin_wayland` and Plasma using patched packages from the Anland project. The Anland daemon and display app show the desktop.
- The Arch container shares Termux's `tmp` folder, so Arch apps connect to Plasma's Wayland socket (`wayland-0`).
- The Ubuntu and Debian containers work the same way: `--shared-tmp` lets them reach the Anland display, and their Plasma runs inside the container, started by `startplasma-anland`.
- `archsh` also bind-mounts Termux's menu folder into Arch as `/termux-apps`. `/usr/local/bin/sync-kickoff` writes `[Arch]` `.desktop` files there, each one launching the app through `archrun`. `archrun` runs it in the container with the GPU and Wayland settings, or, when you are in an X11 session, with `DISPLAY` set and the session's GPU mode (KGSL or software rendering).
- The X11 side uses the Termux:X11 server on display `:1`. The start commands pick a GPU mode (KGSL or the CPU) and give the desktop the matching environment. `plasma-x11` runs `startplasma-x11` in Termux. Each X11 container shares Termux's `tmp` folder (and so the X11 socket), and its start command runs a small `/usr/local/bin/x11-session` wrapper that starts Plasma or XFCE4 inside the container.
- `plasma-stop` stops whichever of these is running, so only one desktop is shown at a time.

## Troubleshooting

**`kwin_wayland` fails with `cannot locate symbol ...`** Termux's Qt moved ahead of the Anland KWin build. Wait for a new [Anland release](https://github.com/lfdevs/anland-termux/releases), then re-run the script. Before upgrading Termux, check: `apt list --upgradable | grep -i qt`.

**Plasma starts but the Anland app stays black** Make sure the display app matches your Termux build (GitHub build: standard APK; F-Droid build: `-compatible` APK). The two variants can't be installed together; uninstall the other first.

**Boxes instead of text in Arch apps** Fonts or locale are missing in Arch: `archsh`, then `sudo pacman -S ttf-dejavu ttf-liberation`.

**`pacman` errors about Landlock or the sandbox** The script adds `DisableSandbox` to `/etc/pacman.conf`. If you reset the config, add that line under `[options]`.

**`sudo` says your user isn't allowed** Run `proot-distro login archlinux` (as root) and create `/etc/sudoers.d/<user>` containing `<user> ALL=(ALL:ALL) ALL`, mode 440.

**An Arch app doesn't appear in Kickoff** Run `ksync`, and if needed `kbuildsycoca6 --noincremental` in Konsole inside Plasma.

**Ubuntu or Debian desktop doesn't start** Stop any other desktop first (`plasma-stop`), then run `plasma-ubuntu` or `plasma-debian` from the Termux app. If it still fails, check that the patched packages are installed: `ubuntush -- dpkg -l xwayland kwin-wayland` (or `debiansh`) should show an Anland build (xwayland `-9x`, kwin `...9x`).

**Ubuntu or Debian graphics fall back to the CPU after an update** `apt` replaced the patched Mesa or KWin. Open `anland-menu`, choose **1) Install / update**, tick that container and go (or re-run the script with `--ubuntu` / `--debian`); it reinstalls and pins them again.

**"Unexpected paths in the Mesa archive"** The script only extracts a Mesa archive that stays inside `/usr`, and refuses anything else before touching the system. If a new release changes the layout, open an issue.

**Electron or X11-only Arch apps** Qt and GTK apps use Wayland automatically. Electron/Chromium apps may need `--ozone-platform=wayland`. In the Wayland session, X11-only apps need extra XWayland setup; in the X11 session they just work (on the CPU).

**`plasma-x11` says the X11 session is not installed** Your Termux packages don't offer `kwin_x11` / `startplasma-x11` (the Anland KWin is Wayland only). Wayland is unaffected. Check again after a Termux update, then re-run the install with part 5 ticked.

**Termux:X11 stays black or won't connect** If the desktop starts but the screen is black, it is usually KWin's compositing; it is off by default (`KWIN_COMPOSE=N`), so check the script you installed is the latest one and re-run it. Otherwise, open the Termux:X11 app after starting the desktop. Keep the app and the `termux-x11-nightly` package on the same nightly build; if they differ, update both. If it doesn't connect on the F-Droid build of Termux, try the GitHub build.

**An X11 container installed XFCE4 instead of Plasma** That image has no Plasma X11 session. This is reported at the end of the install. XFCE4 works the same way; use another release or image if you want Plasma.

**"... the Ubuntu slot needs a Debian- or Ubuntu-based image" (or the Arch version)** The image you chose is another distro family. Pick a matching image on the Images screen. The container is removed again if it was just created.

**"Container ... already exists, so the chosen image is not used"** Images only apply to new containers. Run `proot-distro remove <name>` and install again.

**The X11 desktop is slow** Plasma is heavier than XFCE4; close other apps, or use the Arch XFCE4 container. Try `X11_GPU=off` before the start command and compare.

## Notes

- Not an official project. It automates the manual setup from the Anland user guide and adds the Arch container and Kickoff sync on top.
- Status: the manual steps this script automates (native Plasma, the Arch container with GPU and Kickoff sync, and the Ubuntu desktop with GPU) were verified on a Snapdragon 732G (Adreno 618) with the GitHub build of Termux. The Ubuntu and Debian installs, the main menu, the X11 session, the X11 containers and the image selection have been tested in a simulated environment but not run end to end on a phone yet. The Debian desktop in particular has not been seen running yet, the X11 KGSL mode is untested on a phone, and the X11 options depend on what your Termux repo and the chosen images offer, so please open an issue if something breaks.
- Termux's Mesa and Arch's Mesa are separate builds and may be different versions. If an app glitches, try matching them.
- Arch's kernel packages are pinned (`IgnorePkg`) because a kernel can't be installed in a container.

## Contributors

- [@ttyy31129-sudo](https://github.com/ttyy31129-sudo): maintainer
- Claude (AI assistant by [Anthropic](https://www.anthropic.com)): helped write the X11 session, the X11 desktop containers, the image selection and this documentation

## Credits

- [Anland](https://github.com/superturtlee/anland) and [anland-termux](https://github.com/lfdevs/anland-termux), including the prebuilt Ubuntu 26.04 image
- [mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container) and [lfdevs/termux-packages](https://github.com/lfdevs/termux-packages)
- [Termux](https://github.com/termux/termux-app), [Termux:X11](https://github.com/termux/termux-x11) and [proot-distro](https://github.com/termux/proot-distro)
- [Arch Linux ARM](https://archlinuxarm.org)
