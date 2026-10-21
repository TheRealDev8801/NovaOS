NovaOS Plymouth theme — "nova-starlight"
========================================

Animated boot splash shown between the bootloader and the display manager.
Palette is taken from branding/nova-plasma/color-schemes/Nova.colors and
branding/wallpapers/nova-starlight.svg so the splash, wallpaper and desktop
all agree:

  background  #05070f -> #141c3a   (radial, offset toward upper right)
  accent      #6ee7ff   cyan
  accent2     #a78bfa   violet
  text        #e8ecf8   near-white

## Files

  nova-starlight.plymouth   theme manifest
  nova-starlight.script     the animation, in Plymouth's script language
  assets/logo.png           NovaOS wordmark (generated, see brand.md)
  assets/star.png           soft point sprite used by the starfield

## How the animation works

Plymouth's script language has no real particle engine, so the starfield is a
fixed set of sprites at pre-chosen coordinates, each with its own pulse phase.
That is cheap (no per-frame allocation) and looks intentional rather than
random. Three things move:

  1. stars fade in and out on out-of-phase sine curves
  2. a soft violet/cyan "nova" glow behind the wordmark breathes slowly
  3. the wordmark fades up once, near the start of boot

All timing is driven by Plymouth's `refresh`/`SetRefreshFunction` model, so the
animation advances with the splash rather than on a wall clock. Nothing here
blocks boot: the script never uses `sleep`.

## Why the theme is self-contained

Plymouth runs in the initramfs, before any of the root filesystem is available
beyond what the hooks pull in. Every asset the script touches must therefore be
installed into the initramfs via the `plymouth` hook. Keep assets small and few.
