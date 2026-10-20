# linux-mac

Custom Linux kernel for the Mac Pro 6,1 (Late 2013): the infamous "Trash Can". CachyOS-based with BORE scheduler, built-in drivers, embedded GPU firmware — boots to desktop with no initramfs required.

## What This Is

A kernel config and PKGBUILD targeting Mac Pro 6,1 hardware, with official Linux 7.3 as the project default. The BORE and AMDGPU patches apply to 7.3; package preparation and a repeat `olddefconfig` preserve the critical built-in drivers. The `linux-macpro61` 7.3-1 kernel and headers packages built successfully. A CachyOS MacPro ArchISO containing 7.3-1 was live-booted on a Mac Pro 6,1; `uname -r` reported `7.3.0-macpro61`.

On that live ISO, both FirePro D700 GPUs (Tahiti, PCI `1002:6798`) bound to `amdgpu`; OpenGL direct rendering used accelerated Mesa `radeonsi` 26.2.4 for the default GPU and with `DRI_PRIME=1`. The `enp11s0` BCM57762 bound to `tg3`, linked, and passed 5/5 pings to `1.1.1.1`; `enp12s0` was `NO-CARRIER` and not tested. CS4208 analog and HDMI audio enumerated, but audible playback was not reported. NVMe advertised discard; xHCI exposed a USB 3 root hub, with attached storage operating at 480M (no USB 3 device-speed test). The BCM4360 Wi-Fi bound to `bcma-pci-bridge`, but wireless connectivity was not tested. `vulkaninfo` found no drivers because this ISO lacked `vulkan-radeon`; a sibling ISO profile now includes it for a future, not-yet-tested rebuild. The ISO's `macfanctld` reported `failed`; this was traced to old preflight/daemon expectations for a legacy sysfs path, not the installed-system service status. These are live-ISO observations on the tested D700 system, not comprehensive 7.3 validation; the hardware table describes prior-baseline experience.

The installed Mac Pro 6,1 now runs `linux-macpro61` 7.3-1 (`uname -r`: `7.3.0-macpro61`). With `macpro61-support` 1-11 and `macfanctld` 0.6-5 installed, `macfanctld.service` is active/running; applesmc reports `pwm1_enable=2` (AUTO), `fan1_min=1327`, and `fan1_input=1327` RPM. This installed-system fan result supersedes the older live ISO's failed service observation. An ISO containing the updated fan packages has not yet been verified on hardware.

- **All GPU variants** — D300 (Pitcairn), D500 (Tahiti), D700 (Tahiti XT), firmware baked in
- **CachyOS performance** — BORE scheduler, BBR3 congestion control, `-march=ivybridge -O3`
- **KVM built-in** — run macOS Monterey in QEMU
- **NVMe + TRIM** — aftermarket NVMe drives work out of the box

## Hardware Support

| Feature | Status | Notes |
|---------|--------|-------|
| GPU | D700 observed | Both Tahiti GPUs bound to amdgpu; accelerated OpenGL/radeonsi 26.2.4 observed. D300/D500 not tested here. |
| Display (DP/HDMI) | Historical | Prior baseline used amdgpu + DC; the tested live ISO boots with `amdgpu.dc=0` |
| Vulkan / OpenGL | Partial | OpenGL acceleration observed; Vulkan unavailable in tested ISO (`vulkan-radeon` absent), functionality unverified |
| GPU Compute | Limited | OpenCL via rusticl or Vulkan — no ROCm for Southern Islands |
| Ethernet | Partial | `enp11s0` linked and ping passed; `enp12s0` NO-CARRIER, not tested |
| Wi-Fi | Proprietary | `broadcom-wl-dkms` (AUR) + headers package |
| Audio | Enumerated | CS4208 analog and HDMI; audible playback not reported |
| USB | Partial | xHCI USB 3 root hub present; attached storage ran at 480M, no USB 3 speed test |
| Thunderbolt 2 | Partial | Works with log spam |
| NVMe + TRIM | Working | Built-in; enable `fstrim.timer` |
| Bluetooth | Working | Broadcom via btusb |
| KVM | Working | macOS Monterey virtualization (without GPU passthrough for now) |
| Fans / Thermal | Working (installed system) | `macfanctld` active; applesmc AUTO, fan at 1327 RPM. The older live ISO's service failed due to legacy sysfs-path expectations. |
| Sleep/Wake | Disabled | Unreliable on this hardware |

## Quick Start

Before replacing an installed kernel, verify an independently bootable fallback and sufficient ESP space; a successful live-USB boot does not establish a safe rollback path.

```bash
git clone https://github.com/flammafex/linux-mac.git
cd linux-mac/packaging/arch
makepkg -s
sudo pacman -U linux-macpro61-*.pkg.tar.zst
sudo poweroff  # Apple EFI needs cold boot — never reboot when switching kernels
```

## Important

**Always power off (not reboot) when switching kernels.** Apple EFI needs a cold boot to reinitialize the GPU.

## CachyOS Patches

- **BORE** — Burst-Oriented Response Enhancer scheduler
- **BBR3** — Google TCP congestion control v3
- **CachyOS tweaks** — kernel optimizations
- **HDMI improvements** — display fixes

## Documentation

- [GPU Acceleration Guide](docs/gpu-acceleration.md) -- full stack explainer, what works, performance tuning, roadmap
- [Mesa Setup](docs/mesa.md) -- driver config, environment variables, multi-GPU
- [macOS Monterey KVM](docs/kvm-macos.md) -- run macOS in a VM on this kernel (without GPU passthrough)
- [PVG Roadmap](docs/pvg-linux.md) -- GPU acceleration for macOS VMs
- [CachyOS ISO](https://github.com/flammafex/cachyos-macpro-iso) -- ready-to-build installer ISO

## Roadmap

| Status | Milestone |
|--------|-----------|
| Done | Build Linux 7.3 kernel and headers packages |
| Done | Live-boot CachyOS MacPro ArchISO with 7.3-1 on Mac Pro 6,1 (`uname -r`: `7.3.0-macpro61`) |
| In progress | Verify Vulkan with the updated ISO, second NIC, and audio playback; updated ISO not yet boot-tested |
| Done | All GPU variants, verified against lspci |
| Done | KVM + macOS Monterey virtualization |
| Done | CachyOS-based Mac Pro ISO (KDE Plasma) — [cachyos-macpro-iso](https://github.com/flammafex/cachyos-macpro-iso) |
| Done | Driver trimming — removed ~3000 unused config options for faster builds |


## Boot Configuration

Boot setup varies by installation. On the development Mac Pro installation, `/boot` is the ESP and OpenCore's OpenLinuxBoot reads `/boot/loader/entries/macpro61.conf`; mkinitcpio's preset copies the kernel there and builds the initramfs. The separate `macpro61-support` package installs support hooks. The kernel package itself does not provide a custom boot-sync hook. The live USB has its own boot layout and entry.

### Gotchas

1. **Check your boot path** - Confirm your ESP mount, bootloader entry, and kernel/initramfs destinations match your own installation; do not assume a `/boot/efi` sync mechanism.

2. **Keep an independent fallback** - Before upgrading, ensure a separately bootable fallback kernel/entry exists and is not overwritten. No independent fallback was confirmed on the development installation.

3. **Cold boot** - A full power-off may be needed when switching kernels on Apple hardware; this kernel package does not mask reboot or redirect it to poweroff.

## License

GPL-2.0 (same as the Linux kernel)
