# Nova Desktop & Nova Goodies

The personality layer of NovaOS: a coherent desktop session plus a curated set of
extras — the things that make a distro feel like a *product* instead of a base.

> Fun fact: your `aibot.service` unit already describes itself as
> "Ai Bot V3.0 (Groq API Engine) | **UltraOS Core**" — the old name never left.

---

## Nova Desktop

**Vision:** a fast, gaming-first desktop session that ships with NovaOS Gaming,
branded end-to-end — login, bar, launcher, notifications, theme, wallpaper, sound.

### Technical options

| Option | Base | Pros | Cons |
|---|---|---|---|
| **A. Plasma Nova** | KDE Plasma | Mature, gaming-friendly (VRR/HDR), fastest to ship | Heavy-ish, branding surface is large |
| **B. Hypr Nova** | Hyprland (wlroots) | Very light, modern Wayland, tiling, superb latency | Must assemble bar/launcher/notifications ourselves |
| **C. GNOME Nova** | GNOME Shell | Polished, great defaults | Limited theming, not gaming-tuned |
| **D. Nova Lite** | XFCE | Tiny footprint, familiar | Oldest stack of the four |

**Decision (locked in):** **A — Plasma Nova** ships as `nova-desktop` and the
`novaos-plasma` ISO profile (VM/QEMU-friendly). **B (Hypr Nova)** is the
v1.x experiment. See `docs/qemu-android.md` for running it in QEMU.

### Brand surface (the "Nova" feel)

- Palette: deep space `#070b16` → cyan `#6ee7ff` → violet `#a78bfa`
- Login: SDDM theme
- Wallpaper set + `nova-wallpapers`
- Cursor + icon theme (derived, credited)
- Boot splash: Plymouth theme
- Sound: notification/login set

---

## Nova Goodies

Curated extras in the spirit of `xfce4-goodies`: thin metapackages that pull in a
consistent set of apps, split by persona so nobody installs what they don't want.

| Metapackage | For | Pulls in (official repos) |
|---|---|---|
| `nova-goodies` | Everyone | fastfetch, btop, neovim, fish, mpv, thunar, firefox, keepassxc, qbittorrent, flatpak |
| `nova-goodies-gaming` | Gamers | heroic-games-launcher\*, lutris, goverlay, vkbasalt, wine, winetricks, mangohud, gamemode, gamescope |
| `nova-goodies-dev` | Developers | git, base-devel, neovim, tmux, podman, code\*, docker-compose |

\* AUR-only packages are documented in the metapackage description, never built
into the ISO.

### Design principles

1. **Zero-config defaults** — good choices out of the box, tweaks optional.
2. **Gaming-first performance** — nothing in the default set fights the GPU.
3. **Public and reproducible** — every package list lives in this repo.
4. **Credit upstream** — we theme and curate; we don't fork the world.

---

## Repo layout (planned)

```
novaos/
├── packages/
│   ├── nova-desktop/          # PKGBUILD — session metapackage
│   └── nova-goodies/          # PKGBUILD — extra apps metapackage
├── branding/
│   ├── wallpapers/
│   ├── sddm-theme/
│   └── plymouth/
└── releng/
    └── novaos-gaming/         # ISO profile (now ships the desktop)
```
