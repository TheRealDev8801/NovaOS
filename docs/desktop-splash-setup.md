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

The wizard lives in **two places**, and this has already caused a silent bug:

| Path | Role |
|---|---|
| `nova-setup/nova-setup` | the source you edit |
| `releng/novaos-*/airootfs/usr/local/bin/nova-setup` | **the copy the ISO ships** |

`mkarchiso` builds from `airootfs`, so **editing `nova-setup/nova-setup` alone
changes nothing in any ISO.** An earlier fix to the archinstall config was made
in the source and never reached a build: the resulting ISO had the corrected
executable bit but the *old, broken* config, which is the worst of both — it
looks fixed.

`releng/build.sh` now copies the source into every profile before building and
then **fails the build** if any shipped copy differs. To sync by hand:

```bash
cd releng
for d in novaos-*/airootfs/usr/local/bin; do
  cp -f ../nova-setup/nova-setup ../nova-setup/nova-first-login "$d/"
  chmod 755 "$d"/nova-{setup,first-login}
done
```

`nova-setup/nova-setup` offers **Try** or **Install**:

```bash
nova-setup            # chooser
nova-setup --try      # describe the live session
nova-setup --install  # straight to the installer
nova-setup --check    # validate config generation, touch no disks
```

`--check` is the one to run after editing the script. It writes both config
files to a temp dir, confirms they parse, and — when `archinstall` is available —
runs `archinstall --dry-run` against them so a wrong field name is caught here
rather than during a real install.


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
between releases. `nova-setup --check` therefore does not merely check that the
JSON parses — when `archinstall` is present it hands the generated config to
`archinstall --dry-run` and fails if archinstall rejects it. That is the only
check that catches a wrong field name or a wrong type.

It is worth knowing *why* that matters, because it already bit once. Field names
in this schema are not the obvious ones:

| Looks right | Actually |
|---|---|
| `"bootloader": "systemd-bootctl"` | `bootloader_config.bootloader` = `"Systemd-boot"` |
| `"audio": "pipewire"` | `app_config.audio_config.audio` |
| `"profile": {...}` | `profile_config` |
| `"swap": true` | `swap`: `{enabled, algorithm}` |
| `"parallel downloads": 5` | `pacman_config.parallel_downloads` |
| `locale_config` with `sys_lang` only | needs `sys_lang` **and** `sys_enc` |
| partition without `status` | needs `dev_path`, `flags`, `status: "create"` |
| user with a `groups` list | `sudo: true` |

And one trap that is not obvious at all: **`plymouth` under `bootloader_config`
takes a theme *name*, not a boolean** — and only archinstall's own themes
(`bgrt`, `fade-in`, `glow`, `script`, `solar`, `spinner`, `spinfinity`,
`tribar`, `text`, `details`). It hard-exits on anything else, so passing
`true`, or `nova-starlight`, aborts the install. The NovaOS splash is therefore
installed and enabled by `post_install()` instead, which is the right place for
custom branding anyway.

After a major archinstall upgrade, run `nova-setup --check` before shipping.

## Installing files into the live system: permissions are not preserved

archiso does **not** copy `airootfs` permissions verbatim. Anything not named in
the profile's `file_permissions` array gets the default — which is `0644`, not
executable. So an executable in the source tree arrives in the ISO as
`-rw-r--r--`.

This bit us: `nova-setup` and `nova-first-login` were `0755` in the repo and
`0644` inside the ISO, so running the installer gave

```
-bash: /usr/local/bin/nova-setup: Permission denied
```

The fix is to declare the mode in `profiledef.sh`:

```bash
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/nova-setup"]="0:0:755"
  ["/usr/local/bin/nova-first-login"]="0:0:755"
)
```

To check what actually landed in a built ISO, rather than trusting the source
tree:

```bash
unsquashfs -l airootfs.sfs | grep nova-setup     # present?
# and extract one to see the mode:
unsquashfs -d /tmp/x airootfs.sfs usr/local/bin/nova-setup
ls -l /tmp/x/usr/local/bin/nova-setup
```

## The first-login helper

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
