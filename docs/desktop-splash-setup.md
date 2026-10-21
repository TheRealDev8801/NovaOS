# NovaOS desktop, splash and setup

How the NovaOS desktop, the boot animation and the installer fit together, and
how to change them.

## The desktop (Plasma Nova)

Two editions ship a desktop, and they are deliberately identical:

| Edition | Desktop | Login |
|---|---|---|
| **Gaming** | Plasma Nova + gaming stack | SDDM, autologin as `nova` |
| **Plasma** | Plasma Nova | SDDM, autologin as `nova` |
| **Server** | none (console) | `getty` on tty1, autologin as root |

Both use **`plasma-desktop`, not `plasma-meta`**. The meta package drags in
`discover`, `flatpak`, `krdp`, `kup`, `plasma-vault`, `print-manager` and
`knighttime`, which cost hundreds of MB and are not wanted here. If you add a
Plasma component, add it explicitly to both
`releng/novaos-gaming/packages.x86_64` and
`releng/novaos-plasma/packages.x86_64` so the editions do not drift.

### The files that make login work

A package list alone is not enough. These three files create and configure the
desktop user, and without them SDDM autologin has nobody to log in as:

- `airootfs/usr/lib/sysusers.d/nova.conf` — creates group `nova` (1000) and
  user `nova`. **`systemd-sysusers` accepts exactly one group per `m` line**;
  multiple groups on one line abort the whole file with "Trailing garbage",
  silently producing an ISO with no live user. One `m` line per group.
- `airootfs/usr/lib/tmpfiles.d/nova-home.conf` — `/home/nova`
- `airootfs/etc/sddm.conf.d/nova.conf` — autologin and session selection

## The boot animation

Two stages, so something Nova-branded is on screen from the first frame:

1. **Bootloader** — `airootfs/../syslinux/archiso_head.cfg` themes the BIOS
   `vesamenu`, and `syslinux/splash.png` is its background.
2. **Plymouth** — the `nova-starlight` theme, from early boot until SDDM draws.

### How Plymouth is wired in

Three pieces must agree, or you get a black screen instead of a splash:

| Piece | Where | Purpose |
|---|---|---|
| `plymouth` mkinitcpio hook | `airootfs/etc/mkinitcpio.conf.d/archiso.conf` | puts the theme into the initramfs |
| `splash` kernel parameter | `kernel_params` in `profiledef.sh` | `plymouth-start.service` is gated on `ConditionKernelCommandLine=splash` |
| `Theme=` | `airootfs/etc/plymouth/plymouthd.conf` | selects the theme |

The hook is placed **after `kms`** so the framebuffer exists before the splash
starts, and **before `block`/`archiso`** so it takes over early and archiso then
mounts the squashfs underneath it.

`airootfs/etc/systemd/system/sddm.service.d/plymouth.conf` makes SDDM wait for
`plymouth-quit-wait.service`. Without it the splash can linger over the login
screen, or SDDM can grab the DRM device while Plymouth still holds it.

### The hard constraint

`airootfs/etc/mkinitcpio.conf.d/archiso.conf` is the file whose absence once
made every edition die at `Switch Root` (see
[archiso-profile-requirements.md](archiso-profile-requirements.md)). Editing it
to add `plymouth` touches exactly the thing that was broken. The guard in
`releng/build.sh` fails the build if the generated initramfs has no archiso
hooks, so **this must keep passing**:

```
==> novaos-server: initramfs archiso hooks present
```

If you ever see `ERROR: initramfs has no archiso hooks`, stop — the ISO would
not boot.

### Theme assets

`branding/plymouth/generate-assets.py` writes `star.png` and `logo.png` using
only the Python standard library, so no Pillow, ImageMagick or SVG rasteriser
is needed at build time. Re-run it after editing:

```bash
python3 branding/plymouth/generate-assets.py
```

`logo.png` is drawn from a 5x7 bitmap font defined in the script. To check it
still spells "NOVA OS" without opening the image, decode it:

```bash
python3 - <<'PY'
import zlib, struct
# (see docs for the full decoder; it prints the glyphs as ASCII)
PY
```

The animation lives in `nova-starlight.script`. Plymouth's scripting language
has **no particle system**, so the starfield is a fixed, deterministic list of
sprites each carrying its own `phase`/`speed`/`base` property, and nothing
allocates per frame. The script deliberately never calls `sleep()`, so it
cannot stall the boot.

## The setup wizard

`nova-setup/nova-setup` offers **Try** or **Install**:

```bash
nova-setup            # chooser
nova-setup --try      # describe the live session
nova-setup --install  # straight to the installer
nova-setup --check    # validate config generation, touch no disks
```

`--check` is the one to run after editing the script — it writes both config
files to a temp dir and parses them as JSON.

### Why archinstall and not Calamares

`calamares` is **not in the Arch repositories** — only `calamares-git` in the
AUR. Shipping it would mean compiling a large Qt/KDE tree inside every ISO
build: slow and brittle. `archinstall` is an official package
(`extra/archinstall`) and takes a declarative config:

```bash
archinstall --config user_configuration.json --creds user_credentials.json
```

The wizard generates those two files, then applies NovaOS defaults the installer
has no opinion about (wheel sudo access, branding, SDDM autologin) in
`post_install()`.

**Caveat:** the archinstall config schema is version-specific and changes
between releases. The generated JSON is checked for *valid JSON*, not for
*schema correctness*. After a major archinstall upgrade, test a real install
before shipping.

### First-login helper

`nova-setup/nova-first-login` runs from `etc/xdg/autostart/` on the desktop
editions. It offers the wizard **once**, then writes a marker
(`~/.config/novaos/.first-login-done`) and stays silent. It also checks whether
the system is actually a live session and exits on an installed system, so it
does not nag after installation.

## Regenerating the MOTD

The three profiles used to carry three drifting copies of the same text.

```bash
cd releng
for p in gaming plasma server; do ./make-motd.sh "$p" > novaos-$p/airootfs/etc/motd; done
```
