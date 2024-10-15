#  Initramfs for Browser Confidential VM


# Overview

An initramfs (initial RAM filesystem) is a temporary root filesystem loaded into memory during the Linux boot process. It contains essential files and drivers needed to initialize the system before the real root filesystem is mounted.
It can be passed directly to QEMU alongside a kernel, using the `-initrd` option, by passing the standard boot process and GRUB. 

We will use a custom initramfs passed directly to QEMU to create an encrypted partition during the first boot. The following sections will explain how to build this custom initramfs: retrieve and build the software included, miniumum setup, how we assemble the image.

We include a Makefile that automate most of it. The final build artefact is the initramfs.igz that is a compressed version of the initramfs. It is created by the build.sh script.

# Building the initramfs
## Requirements
This is designed to run on linux, has been tested on Ubuntu.

Apart from the dependencies mentioned further, You will need at least`cpio` and `wget`. Installable via `apt install cpio wget` 


# Busybox 
We include BusyBox in our custom initramfs because it provides essential Unix utilities in a compact, single executable, enabling a lightweight and efficient environment for system initialization and recovery tasks.

For this we will use a prebuilt version that we download from the official website since they already offer a static binary.

```shell
wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
```

Busybox works via a system of link, these are done in the build script.

## Download and build a cryptsetup
Cryptsetup is a Linux utils used to encrypt and decrypt partion and disk.

We need to build a version of it suitable to be included inside the initramfs. The git version is use there. 

```sh
sudo apt install build-essential git
git clone https://gitlab.com/cryptsetup/cryptsetup.git
apt install libpopt-dev autopoint libtool libjson-c-dev/noble
./configure --disable-shared --enable-static  --disable-nls  --disable-asciidoc  --disable-ssh-token  --disable-udev
make
```

The most important flag is the `--enable-static`. The other flag are used in order to build the less possible, reducing the dependencies the size and resource needed  as well as  what need to be included in the binary.

Flag used:

* `--disable-shared` Do not build shared libs
* `--disable-nls` No translation support
* `--disable-asciidoc` No docs
* `--disable-ssh-token` No ssh token auth support
* `--disable-udev` No udev support

The output of this process is the cryptsetup binary and the dependencies it uses. Those are discovered via ldd to be copied in the initrd (see relevant section in the build script) 

## Note:
### Aborted Attempt to build a cryptsetup binary
At first, we tried to build a fully static `cryptsetup` binary with the option `--enable-static-cryptsetup` (the `--enable-static` paramter is only for the lib part). But we aborted that approach and used the same approach as Debian, and that is explained in the Cryptsetup FAQ. That way disover the module dependencies via ldd and copy them in the initramfs.

Still, I'm documenting what has been discovered and done here in case we want to resume this attempt latter.

The static approach required rebuild too many dependencies, as lib packaged in Debian lib*-dev packages only include the `.so` files required for dynamic linking but no the `.a` files needed for static linking.



Here is the commands used to build the cryptsetup part:

```sh
./configure --enable-static  --disable-nls  --disable-asciidoc  --disable-ssh-token --enable-static-cryptsetup DEVMAPPER_CFLAGS="-I$BUILDROOT/system/usr/include"  DEVMAPPER_LIBS="-L$BUILDROOT/system/usr/lib -ldevmapper"  --disable-shared
make
```

This required DM libdevmapper, part of the LVM2 packages:
```sh
export BUILDROOT=$CWD
wget http://mirrors.kernel.org/sourceware/lvm2/LVM2.2.03.26.tgz
tar xvf LVM2.2.03.26.tgz
cd LVM2.2.03.26
./configure --enable-static_link    --enable-devmapper --disable-selinux --disable-systemd-journal --without-systemd  --with-udev
make
make install DESTDIR=$BUILDROOT/system/
```

Building libdevmapper worked.
However, cryptsetup also required rebuilding udev, as even with `--disable-udev` option, the static binary build requires it). I stopped there


# Init script
In src/init we have the init script we built and that is run as soon as the kernel is loaded.

It does the minimal setup needed.


# Test the setup
To test  the initramfs file you can run it using the following qemu command.
Where vmlinuz is a Linux kernel. You should be able to use the one in your /boot partition, just copy it in the current folder and chown it to your user.

```shell
qemu-system-x86_64  -drive file=./disk.img,media=disk,if=virtio,format=raw\
					-m 2000m\
					-kernel ./vmlinuz-6.8.0-41-generic\
					-initrd ./initramfs.igz\
```

And the empty disk can be created and recreated using `truncate -s 100MB disk.img`


## mkfs.ext4
Busybox only provide mkfs.ext2
`mkfs.ext4` is provided by the `e2fsprog` package

Installation
```shell
wget https://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git/snapshot/e2fsprogs-1.47.1.tar.gz
tar xvf e2fsprogs-1.47.1.tar.gz
cd e2fsprogs-1.47.1
./configure --disable-debugfs  --disable-imager --disable-nls --disable-fuse2fs
make all-static 
```

Result is in  misc/mke2fs.static
```shell
% file misc/mke2fs.static 
misc/mke2fs.static: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, BuildID[sha1]=daec63b237f1a5e9a5e865245065421eb1bca7e2, for GNU/Linux 3.2.0, with debug_info, not stripped
```