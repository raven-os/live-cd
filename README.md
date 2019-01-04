# Raven's ISO

The installation ISO for Raven-OS

## Dependencies

The following commands are used by `iso.sh`:
  * [`nest`](https://github.com/raven-os/nest) (You don't need to be on Raven-OS, but to have compiled Nest and made it available in your `$PATH`).
  * `parted`
  * `mkfs.fat`
  * `mkfs.ext2`
  * `losetup`
  * `grub-install` or `grub2-install`, with grub 2.02 (Check with `grub-install --version`)

## Running

To make the iso, you can simply run `./iso.sh`.
Be careful, the script needs to be run as `root`.

```bash
root $ ./iso.sh
```

If the script succeeds, the message `Done. The iso is located at "/path/to/raven-os.iso".` is displayed.


## Trying Raven-OS on real hardware

The iso can be burned on an external device (like an USB flash drive or an optical disk) using `dd`:

```bash
dd if=/path/to/raven-os.iso of=/dev/sdx
```

Where `sdx` is the device you want to burn the iso on.

The computer can be booted from the selected device by tweaking some BIOS/UEFI settings, commonly referred to as the boot order. You want to make sure the device will be the first loaded, before the main hard drive. See your motherboard's manual for more details.

When the Raven-OS menu appears, select the "Live" entry if you want to try Raven-OS, or "Graphical Install" or "Manual Install" if you want to install Raven-OS on your system.

# Trying the ISO

You can also try Raven-OS through a virtual machine, like QEMU, VirtualBox or VMWare.

Example with QEMU:

```bash
qemu-system-x86_64 -drive file=/path/to/raven-os.iso
```
