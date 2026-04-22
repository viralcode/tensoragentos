<p align="center">
  <img src="packages/whaleos/assets/whale_logo.png" alt="TensorAgent OS" width="110" />
</p>

<h1 align="center">TensorAgent OS</h1>

<p align="center">
  <strong>An experimental AI-native operating system.</strong><br/>
  No app launcher. No file manager. Just you, an AI agent, and the kernel.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.2.0--alpha-orange" />
  <img src="https://img.shields.io/badge/status-EARLY%20%E2%80%94%20EXPECT%20BUGS-red" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
  <img src="https://img.shields.io/badge/arch-x86__64%20%7C%20ARM64-blue" />
  <img src="https://img.shields.io/badge/powered_by-OpenWhale-blueviolet" />
</p>

---

> ## ⚠️ Early Version — Here Be Dragons
>
> **TensorAgent OS is in very early development. It has many, many bugs.**
>
> Treat it as a research prototype, not a daily driver. Expect:
>
> - **The x86_64 build is not ready.** Only the ARM64 path (UTM / QEMU on
>   Apple Silicon) is currently usable end-to-end. The `build-iso.sh` x86_64
>   pipeline runs but produces an ISO that does not boot cleanly yet.
> - Boot failures on certain hosts / firmware combinations.
> - The QML shell crashing, freezing, or rendering blank windows.
> - OpenWhale agent runs that hang, leak memory, or silently fail.
> - Cloud-init that gets stuck on first boot for several minutes (or forever).
> - Cross-arch (ARM64 ↔ x86_64) builds breaking without warning.
> - Half-written features behind menu entries that do nothing.
> - Breaking changes between commits with no migration path.
>
> If you’re looking for something stable, this isn’t it — yet. If you want to
> hack on an AI-first OS and don’t mind a broken build now and then, welcome.
> Please file issues with logs (`journalctl -u openwhale -u ainux-gui -b`).

---

## What is TensorAgent OS?

TensorAgent OS is a bootable Linux-based OS where an **AI agent is the
primary user interface**. Instead of clicking through menus, you talk to the
system. The agent has native access to:

- The **kernel** (system calls, processes, namespaces)
- **Hardware** (battery, sensors, audio, displays via `systeminformation`)
- The **filesystem** and network stack
- **systemd services** and package management
- A **WebMCP-enabled Chromium** for tool use inside web pages
- A pluggable **skills + tools** layer through OpenWhale

It ships as either a full bootable ISO (via `debootstrap` + Debian Bookworm)
or as a pre-built UTM/QEMU image you can boot in seconds on macOS.

### Architecture at a glance

| Layer | Component | Tech |
|-------|-----------|------|
| AI engine | [OpenWhale](packages/openwhale/) | TypeScript, multi-agent, MCP, tools, skills |
| Desktop shell | [WhaleOS](packages/whaleos/) | Qt6 / QML, native C++ helpers |
| Core orchestrator | [@ainux/core](packages/core/) | Node.js — IPC, process mgmt, hardware bridge |
| Browser | [ainux-chromium](packages/chromium/) | Chromium + WebMCP patches, kiosk/agentic mode |
| Optional GUI | [packages/gui](packages/gui/) | React + Vite (alternative to QML shell) |
| Build system | [scripts/build-iso.sh](scripts/build-iso.sh) | debootstrap + xorriso + (optional) Buildroot |

---

## Quick Start — UTM on macOS (recommended, easiest)

The fastest path. Double-click and boot.

```bash
brew install --cask utm
open utm_build/TensorAgentOS.utm
```

**Login:** `ainux` / `ainux`

Pre-configured with 6 GB RAM, 6 cores, ARM64 virtualisation, and host port
forwarding:

| Host port | Guest service |
|-----------|---------------|
| `7777`    | OpenWhale API / dashboard |
| `2222`    | SSH |

> ⚠️ If the VM hangs at the EFI shell or the desktop never appears, that's a
> known issue — try a cold restart from UTM and give it 2–3 more minutes.
> First boot runs cloud-init and can take a while.

---

## Quick Start — QEMU on macOS (ARM64, HVF accelerated)

```bash
brew install qemu

# 1. Download a Debian ARM64 generic cloud image (~400 MB)
curl -L -o vm/debian-generic.qcow2 \
  "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"

# 2. Launch (first boot ≈ 5 minutes — cloud-init installs everything)
python3 vm/launch-ainux.py
```

After it finishes provisioning:

| Service | Where |
|---------|-------|
| Desktop | The QEMU window |
| API / Dashboard | <http://localhost:7777> |
| SSH | `ssh ainux@localhost -p 2222` |

The launcher script (`vm/launch-ainux.py`) injects all of `packages/whaleos/`,
the OpenWhale patch script, and the login HTML into the guest via cloud-init,
so any local changes are picked up on the next boot.

---

## Build a Bootable ISO from Source (Linux x86_64 host)

> ⚠️ **Heads up: the x86_64 build is not ready.** The script runs to
> completion but the resulting ISO currently fails to boot reliably (GRUB /
> initrd / service-ordering issues). Use the ARM64 UTM or QEMU path above
> for anything you actually want to run. The instructions below are kept
> for contributors who want to help fix the x86_64 pipeline.

Reproducible from-scratch ISO build. **Linux x86_64 host required**, ~16 GB
RAM and ~150 GB free disk recommended (less if you skip Chromium).

```bash
# 1. Install host build dependencies
sudo apt install -y \
  build-essential git python3 wget curl xz-utils \
  gcc g++ make tar patch pkg-config \
  debootstrap xorriso grub-pc-bin grub-efi-amd64-bin \
  mtools squashfs-tools qemu-user-static binfmt-support

# 2. Build the ISO
./scripts/build-iso.sh                # x86_64, full build (slow)
./scripts/build-iso.sh --skip-chromium  # use Debian's chromium, much faster
./scripts/build-iso.sh --arch=aarch64   # cross-build ARM64 ISO
./scripts/build-iso.sh --clean          # nuke ./build and start over

# 3. Smoke-test in QEMU
./scripts/run-qemu.sh
```

The build pipeline (see [scripts/build-iso.sh](scripts/build-iso.sh)) does:

1. `debootstrap` a Debian Bookworm rootfs.
2. Install Qt6, Node.js, PAM, Wayland, and other system packages.
3. Drop in [rootfs-overlay/](rootfs-overlay/) (systemd units, configs).
4. Build & install OpenWhale + WhaleOS into `/opt/ainux/`.
5. Install the GRUB bootloader and generate the ISO with `xorriso`.

### Flash to USB

```bash
# Replace /dev/sdX with the right device — this WILL erase it.
sudo dd if=ainux.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

---

## Build a UTM Bundle (macOS)

Wrap a generated qcow2 disk into a ready-to-double-click UTM VM:

```bash
# 1. Produce vm/ainux.qcow2 first
python3 vm/launch-ainux.py

# 2. Stage the bundle
mkdir -p utm_build/TensorAgentOS.utm/Data
cp vm/ainux.qcow2 utm_build/TensorAgentOS.utm/Data/ainux.qcow2

# 3. Drop in the config.plist (template lives in utm_build/)

# 4. Open
open utm_build/TensorAgentOS.utm
```

> **Note:** UTM does not run cloud-init on its own. Make sure the disk image
> already has `systemd-networkd` DHCP configured, otherwise the VM will boot
> with no network and the agent will look broken.

---

## Project Layout

```
ainux/
├── packages/
│   ├── openwhale/        # OpenWhale AI engine (TS) — agents, MCP, skills, tools
│   ├── whaleos/          # Qt6 / QML desktop shell — main.qml, ChatBar, Desktop, …
│   ├── core/             # Node.js core orchestrator — IPC, hardware, process mgmt
│   ├── chromium/         # Chromium patches: WebMCP-on, AInux hooks, kiosk mode
│   └── gui/              # Optional React/Vite shell (alternative front-end)
├── buildroot-external/   # Custom Buildroot packages (ainux-shell, ainux-gui, …)
├── board/ainux/          # Bootloader configuration (GRUB)
├── configs/              # Buildroot defconfig + kernel .config
├── rootfs-overlay/       # Files copied into the rootfs (systemd units, /etc, /opt)
├── scripts/
│   ├── build-iso.sh      # Master build script (Debian-based)
│   ├── run-qemu.sh       # Launch the built ISO in QEMU
│   ├── integrate-openwhale.sh
│   ├── configure-rendering.sh
│   ├── post-build.sh / post-image.sh
│   └── ainux-update.sh   # In-guest updater
├── vm/
│   ├── launch-ainux.py   # One-command QEMU launcher (ARM64 + HVF on macOS)
│   ├── boot-ainux.sh     # Plain boot script
│   ├── auto-setup.sh     # In-guest first-boot setup
│   └── cidata/           # cloud-init seed (meta-data / user-data)
├── utm_build/            # Pre-built UTM virtual machine bundle
├── docs/                 # Project docs (HTML)
└── package.json          # npm workspace root
```

---

## Development Workflow

Hot-reload changes into a running VM over SSH:

```bash
# WhaleOS (QML) — restart shell after copying
scp -P 2222 packages/whaleos/*.qml ainux@localhost:/opt/ainux/whaleos/
ssh -p 2222 ainux@localhost "sudo systemctl restart ainux-gui"

# OpenWhale (TypeScript) — rebuild + restart in-guest
scp -P 2222 packages/openwhale/src/**/*.ts ainux@localhost:/tmp/
ssh -p 2222 ainux@localhost "
  sudo cp /tmp/*.ts /opt/ainux/openwhale/src/ &&
  cd /opt/ainux/openwhale && sudo npm run build &&
  sudo systemctl restart openwhale
"

# Tail logs
ssh -p 2222 ainux@localhost "journalctl -u openwhale -u ainux-gui -f"
```

There's also a convenience script: [scripts/dev-push.sh](scripts/dev-push.sh).

### NPM scripts (host side)

```bash
npm run dev            # Run OpenWhale directly on the host (no VM)
npm run build:shell    # Build the WhaleOS QML shell locally
npm run build:iso      # Build the x86_64 ISO
npm run build:iso:arm64
npm run setup:vm       # Provision vm/ contents
npm run test:qemu      # Boot the latest ISO in QEMU
npm run lint
```

**Default credentials everywhere:** `ainux` / `ainux` (login, sudo, SSH).
Change them before exposing the VM to anything other than `localhost`.

---

## Known Issues / Rough Edges

A non-exhaustive list — please add to it via GitHub issues:

- **x86_64 ISO does not boot cleanly.** The full `build-iso.sh` pipeline is
  incomplete — only ARM64 (UTM / QEMU on macOS) is currently usable.
- **First-boot cloud-init can hang.** If you don't see the desktop after
  ~10 minutes, SSH in on `2222` and run `cloud-init status --long`.
- **WhaleOS shell crash on resize.** Resizing the QEMU/UTM window can take
  the QML shell down. Restart with `sudo systemctl restart ainux-gui`.
- **OpenWhale agents may stall** waiting on a tool call that never returns.
  Restart with `sudo systemctl restart openwhale`.
- **Chromium kiosk patches** are out of date for some upstream versions; use
  `--skip-chromium` if the build fails.
- **ARM64 cross-build** of Chromium is essentially untested.
- **No installer.** The ISO currently boots live; persistence is whatever
  the underlying VM disk gives you.
- **Networking in UTM** can come up without a route on some macOS versions.
  `sudo dhclient enp0s1` (or similar) usually fixes it.

---

## Contributing

Issues and PRs welcome — especially:

- Reproducible bug reports (host OS, arch, exact command, full log).
- Cleanups in `scripts/build-iso.sh` (it's grown organically).
- Additional OpenWhale skills under [packages/openwhale/skills/](packages/openwhale/skills/).
- New QML apps under [packages/whaleos/](packages/whaleos/).

Please keep changes focused and avoid bundling unrelated refactors.

---

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <strong>Author:</strong> JIJO JOHN — <a href="https://jijojohn.me">https://jijojohn.me</a>
</p>
