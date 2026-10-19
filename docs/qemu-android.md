# Running NovaOS in QEMU (desktop, servers, and Android)

NovaOS ships VM support in the **Plasma** profile: `qemu-guest-agent`,
`spice-vdagent` and the QXL driver are included, so the guest reports its IP,
syncs the clock, and auto-resizes the display out of the box.

Build the image first:

```bash
cd novaos/releng
./build-docker.sh plasma     # or ./build.sh plasma on an Arch host
```

---

## Desktop / laptop QEMU (fast, KVM)

```bash
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 4 -m 4096 \
  -machine q35 \
  -drive file=../out/novagos-plasma-*.iso,media=cdrom,readonly=on \
  -boot d \
  -device virtio-vga-gl -display gtk,gl=on \
  -nic user,model=virtio-net-pci
```

- `virtio-vga-gl` + `gl=on` gives VirGL 3D acceleration (Plasma feels native).
- Without GPU passthrough, drop to `-vga virtio` for a safe 2D fallback.
- `releng/run-vm.sh <iso>` is a shortcut for the basic case.

### Install to a disk (persistent system)

```bash
qemu-img create -f qcow2 novaos.qcow2 30G
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -machine q35 \
  -drive file=novaos.qcow2,if=virtio \
  -drive file=../out/novagos-plasma-*.iso,media=cdrom,readonly=on \
  -boot order=d \
  -device virtio-vga-gl -display gtk,gl=on \
  -nic user,model=virtio-net-pci
```

Then install from the live session onto `/dev/vda`. Remove the CD line and
boot `order=c` afterwards.

---

## Remote display (headless VM, laptop client)

Use SPICE (best clipboard/resolution integration):

```bash
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -machine q35 \
  -drive file=../out/novagos-plasma-*.iso,media=cdrom,readonly=on -boot d \
  -vga qxl \
  -spice port=5930,disable-ticketing=on \
  -device virtio-serial-pci -chardev spicevmc,id=vdagent,name=vdagent \
  -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
  -nic user,model=virtio-net-pci
```

Connect with `remote-viewer spice://127.0.0.1:5930` (or any SPICE client).

Or plain VNC:

```bash
  -vnc :1 -display none        # then connect a VNC client to port 5901
```

---

## Android (Termux, Limbo, QEMU-Android)

Reality check: **Android QEMU has no KVM** (unless the phone is rooted), so it
runs TCG emulation — roughly 10–50× slower than native. Practical guidance:

| Device / goal | Recommendation |
|---|---|
| Phone/tablet, curiosity, learning | **NovaOS Server** ISO (no desktop) with VNC |
| Strong tablet (8 GB+, SD 8 Gen class) | NovaOS Plasma, 2048 MB RAM, VNC, expect sluggish UI |
| Best experience | Run Plasma on a PC/server; SSH or use SPICE from the phone |

Suggested Android (Termux) invocation:

```bash
# in Termux:  pkg install qemu-system-x86-64-headless qemu-utils
qemu-img create -f qcow2 novaos.qcow2 16G

qemu-system-x86_64 \
  -cpu max -smp 2 -m 2048 -machine q35,accel=tcg \
  -drive file=novaos.qcow2,if=virtio,cache=writeback \
  -drive file=novagos-plasma.iso,media=cdrom,readonly=on -boot order=d \
  -device virtio-gpu-pci \
  -nic user,model=virtio-net-pci \
  -vnc :1 -display none
```

Then open a VNC client on the phone to `127.0.0.1:5901` (Termux) or the device
IP if the client is a separate app. Notes:

- Prefer `cache=writeback` and a qcow2 disk — live ISO reads are slow under TCG.
- Skip `-enable-kvm`, `-cpu host`, and `gl=on` (unsupported on Android).
- Use `-m 2048` maximum; Android will kill the VM if you oversubscribe RAM.
- For a snappier Android experience, install **NovaOS Server** and use SSH.

---

## Why it works out of the box

| Feature | Provided by |
|---|---|
| IP / hostname reporting, graceful shutdown | `qemu-guest-agent` (enabled) |
| Clipboard + auto-resize (SPICE) | `spice-vdagent` (enabled) |
| QXL display driver | `xf86-video-qxl` |
| VirtIO disk/net/GPU | in-kernel modules (linux) |
| 3D acceleration | `mesa` + VirGL (`virtio-vga-gl`) |
