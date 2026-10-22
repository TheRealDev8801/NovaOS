# NovaOS

**The most magical all-in-one Operating System based on Linux. Arch-powered operating system for gamers and servers.**

## Vision

NovaOS takes the raw power of Arch Linux — the latest kernel, drivers, and software — and packages it into two purpose-built experiences:

1. **For gamers**: out-of-the-box performance. Latest kernel, Mesa/Vulkan, Proton and Steam integration, tuned for low latency and high FPS.
2. **For servers**: rolling stability, latest security patches, container-ready, minimal footprint option for headless deployments.

No assembly required.

## Editions

| Edition | Target | Highlights |
|---|---|---|
| **NovaOS Gaming** | Desktops, handhelds, consoles | Optimized kernel, gaming toolchain, performance tweaks |
| **NovaOS Plasma** | Desktops, laptops, VMs (QEMU/SPICE) | Lean Plasma Nova desktop + curated goodies + VM guest support |
| **NovaOS Server** | Bare metal, VPS, homelabs | Minimal footprint, containers, systemd services |

## Base

- **Linux**: Arch Linux (rolling release)
- **Package manager**: pacman + AUR

## Status

All three editions build and boot.

| Edition | ISO | Size | Desktop | State |
|---|---|---|---|---|
| **NovaOS Gaming** | `novagos-gaming-2026.10.22-x86_64.iso` | 2.71 GiB | Plasma Nova + gaming stack | ✅ boots on real hardware; installer unproven |
| **NovaOS Plasma** | `novagos-plasma-2026.10.22-x86_64.iso` | 2.33 GiB | Plasma Nova | ✅ UEFI boot menu verified; installer unproven |
| **NovaOS Server** | `novagos-server-2026.10.22-x86_64.iso` | 1.54 GiB | console only | ✅ hook-verified; installer unproven |

"Installer unproven" means the generated archinstall config is validated against
the real 4.5 schema (`nova-setup --check` accepts it and rejects a bad one), but
no full install has been run to completion yet.

Download at https://novaos.aibotv2-hosting.biz — SHA256 sums are published
alongside the images.

The `2026.10.22` images are the current release and the only ones served; the
older `2026.10.21` and `-r2` sets have been removed. Version names carry the
build date rather than a revision suffix, so a filename identifies exactly one
build — an ISO is never overwritten in place, which would otherwise hand a
stale image to anyone holding a cached copy.

Every ISO is built with `releng/build-docker.sh` and checked by
`releng/build.sh`, which refuses to ship an initramfs lacking the archiso hooks
(the bug that once made every edition die at `Switch Root` — see
[docs/archiso-profile-requirements.md](docs/archiso-profile-requirements.md)).
Adding Plymouth to the splash touched that same file, so the guard passing is
load-bearing rather than decorative.

### Known constraint: Plasma 6 is Wayland-only

Arch ships Plasma 6 with a Wayland session and no X11 fallback, and Wayland
needs a real DRM device. In QEMU that means the choice of `-vga` decides whether
the desktop starts:

| `-vga` | Result |
|---|---|
| `virtio-gpu-pci` / `-device virtio-vga` | desktop starts |
| `qxl` | works (SPICE/VNC clients) |
| `std` (bochs) | splash shows, desktop may not start |

If the Starlight splash appears and then you get a black screen or a text
console, that is a display choice rather than a broken image — switch to
`virtio-gpu-pci`. Details in
[docs/qemu-android.md](docs/qemu-android.md).

## Roadmap

- [x] NovaOS Gaming ISO
- [x] NovaOS Plasma ISO (Plasma Nova)
- [x] NovaOS Server ISO
- [x] Boots past `Switch Root` on real hardware
- [x] Nova Desktop on Gaming and Plasma
- [x] Animated boot splash (Starlight)
- [x] `nova-setup` installer and welcome flow
- [ ] Installer confirmed against a real install
- [ ] v1.0 release

## Links

- **Website**: https://novaos.aibotv2-hosting.biz

## License

© All rights reserved, Nova Team & Ai bot V2 Hosting Team.
