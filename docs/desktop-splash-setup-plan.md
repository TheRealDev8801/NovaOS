# NovaOS desktop, boot splash, and setup — implementation plan

Status: in progress. Work is being done on branch `feat/desktop-splash-setup`.

Three requests, and what each actually needs:

1. **A DE for the Gaming edition** — it currently ships a gaming stack and no
   desktop at all.
2. **A custom boot animation** — both a themed bootloader *and* a Plymouth
   splash.
3. **A custom setup** — an installer plus a welcome app, so a user can either
   install NovaOS to disk or just explore the live session.

## Findings that shape the work

| Package | Where it is | Consequence |
|---|---|---|
| `plymouth` | `extra/plymouth` 26.134.222 | Boot splash is easy — official repo. |
| `archinstall` | `extra/archinstall` 4.5 | Official, scriptable Arch installer. |
| `calamares` | **AUR only** (`calamares-git`) | The familiar graphical installer is *not* in Arch's repos. |

**Decision — installer:** ship **archinstall** (official, in-repo) wrapped in a
NovaOS wizard, rather than Calamares. Calamares would have to be compiled from
the AUR inside every ISO build: slow, brittle, and it drags in a large Qt/KDE
build dependency tree. If a graphical installer is wanted later, it can be added
as an optional path without disturbing this.

## Where the files live

- `branding/` — visual identity (wallpaper, KDE look-and-feel, SDDM theme).
  Extend this rather than inventing a parallel tree.
- `packages/` — NovaOS packages. `nova-desktop` and `nova-goodies` are
  metapackages.
- `releng/novaos-*/airootfs/` — files baked into each ISO.
- `nova-setup/` — **new**: the installer wizard and welcome app (see below).

## Known inconsistency to fix

`packages/nova-desktop/PKGBUILD` depends on `plasma-meta`, but the Plasma
profile deliberately uses `plasma-desktop` instead, to avoid pulling
discover/flatpak/krdp/kup/plasma-vault/print-manager/knighttime. The two should
agree; the lean set wins.

## Work plan

1. Add the Plasma desktop to the Gaming edition, reusing the Plasma edition's
   proven package set plus the gaming stack.
2. Plymouth splash: theme assets + `plymouthd` in the initramfs (the archiso
   `mkinitcpio.conf.d/archiso.conf` hooks must include `plymouth`), enabled on
   the kernel command line. Must not break the `Switch Root` fix.
3. Bootloader theming for `bios.syslinux` and `uefi.systemd-boot`.
4. `nova-setup`: a first-boot welcome app offering *Try NovaOS* or *Install*,
   and a wizard that drives `archinstall` with NovaOS defaults.
5. Reconcile the metapackages with the lean package sets.
6. Rebuild, verify the initramfs still has the archiso hooks, confirm boot.

## The one hard constraint

The `Switch Root` bug was a missing `mkinitcpio.conf.d/archiso.conf`. Adding
`plymouth` to the hooks touches that same file. The build-time guard in
`releng/build.sh` must keep passing at every step — an unbootable ISO is worse
than a plain splash screen.
