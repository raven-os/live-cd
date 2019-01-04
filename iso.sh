#!/usr/bin/env bash

set -e -u

declare script_dir="$(realpath $(dirname $0))"
declare isofs="$script_dir/build/isofs"
declare mnt_efi="$script_dir/build/mnt_efi/"
declare mnt_linux="$script_dir/build/mnt_linux/"
declare overlay="$script_dir/overlay/"
declare build_iso="$script_dir/build/raven-os.iso"
declare final_iso="$script_dir/raven-os.iso"
declare grub="grub"

# Tests if a given command exists. Exit otherwise.
function test_command() {
    if ! which $1 > /dev/null 2>&1; then
        echo "The \"$1\" command is missing but is required by this script."
        echo "Please install the required packages and make sure your \$PATH is valid."
        exit 1
    fi
}

# Populates the content of the partition
function populate_isofs() {
    yes | nest --chroot="$isofs" pull
    yes | nest --chroot="$isofs" install corefs
    yes | nest --chroot="$isofs" install essentials linux busybox-bin

    # Rename vmlinuz to make the grub config easier
    mv "$isofs/boot/vmlinuz-"* "$isofs/boot/vmlinuz"

    # Make some symbolink links because we don't have packages for these binaries (yet)
    ln -s /bin/busybox "$isofs/bin/hostname"
    ln -s /bin/busybox "$isofs/bin/vi"

    # Copy the overlay directory into the ISO, overwriting existing files
    cp -r "$overlay"/* "$isofs"/

    # Cleanup the unneeded files
    rm -rf \
        "$isofs"/boot/System.map-* \
        "$isofs"/boot/config-* \
        "$isofs"/var/nest

    # Move it to the Linux mountpoint
    mv "$isofs"/* "$mnt_linux/"
}

# Generates the Grub configuration (grub.cfg)
#
# Takes the name of the root partition as parameter
function generate_grub_cfg() {
    cat << EOF
menuentry 'Live' {
	linux /boot/vmlinuz rootwait root=$1 quiet
}

menuentry 'Graphical install' {
	linux /boot/vmlinuz rootwait root=$1 quiet
}

menuentry 'Manual install' {
	linux /boot/vmlinuz rootwait root=$1 quiet
}
EOF
}

# Creates a bootable ISO and all the needed files to make it (like grub config)
function make_iso() {
    dd if=/dev/zero of="$build_iso" count=300 bs=1048576

    # Create two partitions:
    #  * EFI system partition (EF00), 50MiB in size
    #  * Linux partition, filling the remaining space
    parted --script "$build_iso" \
        mklabel msdos \
        mkpart p fat32 1 50MiB \
        mkpart p ext2 50MiB 100% \
        set 1 esp on \
        set 2 boot on

    sync

    losetup -fP "$build_iso"

    declare device_list=$(losetup -ln)
    declare device="$(echo $device_list | grep "$build_iso" | awk '{print $1}' | head -n 1)"
    declare partition_efi=${device}p1
    declare partition_linux=${device}p2

    echo "Device: $device"
    echo "Partition EFI: $partition_efi"
    echo "Partition Linux: $partition_linux"

    # Create and mount the partitions
    mkfs.fat -F32 "$partition_efi" && sync
    mkfs.ext2 "$partition_linux" && sync

    mount -t vfat "$partition_efi" "$mnt_efi"
    mount -t ext2 "$partition_linux" "$mnt_linux"

    # Populate the content of the partition
    populate_isofs

    # Install EFI grub
    grub-install --target=x86_64-efi --themes= --recheck --removable --efi-directory="$mnt_efi" --boot-directory="$mnt_linux/boot" && sync

    # Install BIOS grub
    grub-install --target=i386-pc --themes= --recheck --boot-directory="$mnt_linux/boot" "$device" && sync

    # Retrieve main partition's UUID
    partuuid=$(blkid -s PARTUUID -o value "$partition_linux")

    echo "PartUUID=$partuuid"

    # Generate grub partition
    #
    # We use a partition UUID here so it's unambiguous which partition is the root
    # one.
    generate_grub_cfg "PARTUUID=$partuuid" >> "$mnt_linux/boot/grub/grub.cfg"

    # Unmount and remove the loopback devices
    umount -R "$mnt_linux"
    umount -R "$mnt_efi"
    losetup -d "$device"

    sync

    # Move the iso to it's final destination
    mv "$build_iso" "$final_iso"
}

function main() {
    # Some distro package Grub 1.97+ as grub, and others as grub2.
    # Quick check to know which one to use.
    grub=$(which grub2-install > /dev/null 2>&1 && echo grub2 || echo grub)

    test_command "nest"
    test_command "parted"
    test_command "mkfs.fat"
    test_command "mkfs.ext2"
    test_command "losetup"
    test_command "$grub-install"

    # Clean previous trials
    umount -R "$mnt_efi" || :
    umount -R "$mnt_linux" || :
    losetup -D
    rm -rf build

    mkdir -p "$isofs" "$mnt_efi" "$mnt_linux"

    make_iso

    echo
    echo "Done. The iso is located at \"$final_iso\"."
}

main $@
