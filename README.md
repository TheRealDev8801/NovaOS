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

All three editions build and boot. Verified end to end:

| Edition | ISO | Boots |
|---|---|---|
| **NovaOS Gaming** | `novagos-gaming-2026.10.21-x86_64.iso` (1.84 GiB) | ✅ confirmed on real hardware |
| **NovaOS Plasma** | `novagos-plasma-2026.10.21-x86_64.iso` (2.05 GiB) | ✅ hook-verified |
| **NovaOS Server** | `novagos-server-2026.10.21-x86_64.iso` (1.34 GiB) | ✅ hook-verified |

Download at https://novaos.aibotv2-hosting.biz — SHA256 sums are published
alongside the images.

Every ISO is built with `releng/build-docker.sh` and checked by
`releng/build.sh`, which refuses to ship an initramfs lacking the archiso hooks
(the bug that once made every edition die at `Switch Root` — see
[docs/archiso-profile-requirements.md](docs/archiso-profile-requirements.md)).

## Roadmap

- [x] NovaOS Gaming ISO
- [x] NovaOS Plasma ISO (Plasma Nova)
- [x] NovaOS Server ISO
- [x] Boots past `Switch Root` on real hardware
- [ ] Installer (currently a live session and a manual Arch install)
- [ ] v1.0 release

## Links

- **Website**: https://novaos.aibotv2-hosting.biz

## License

© All rights reserved, Nova Team & Ai bot V2 Hosting Team.
