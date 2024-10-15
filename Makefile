.PHONY: run recreate-disk

all: initramfs.igz

# busybox
busybox:
	wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
	chmod +x busybox

initramfs/busybox: busybox
	cp busybox initramfs/busybox

# init
initramfs/init: src/init
	cp src/init initramfs/init


initramfs.igz: cryptsetup/cryptsetup initramfs/init initramfs/bin initramfs/busybox initramfs/init
	cp util-linux/sfdisk.static initramfs/bin/sfdisk
	bash ./build.sh

run: initramfs.igz
	qemu-system-x86_64  -drive file=./disk.img,media=disk,if=virtio,format=raw\
						-m 2000m\
						-kernel ./vmlinuz-6.8.0-41-generic\
						-initrd ./initramfs.igz\
						-nographic\
						 -serial mon:stdio \
						 -enable-kvm \
						 -append console=ttyS0,115200n8


cryptsetup/cryptsetup:
	echo "Please build cryptsetup. See readme" && exit 1


recreate-disk:
	rm disk.img; truncate -s 1000MB disk.img
