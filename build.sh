echo building initramfs.igz ...
set -euo pipefail

copy_ldd_libs() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: copy_ldd_libs <binary> <destination_directory>"
        return 1
    fi

    local binary="$1"
    local dest_dir="$2"

    # Check if the base destination directory exists
    if [ ! -d "$dest_dir" ]; then
        echo "Error: Base destination directory '$dest_dir' does not exist."
        return 1
    fi

    # Use ldd and awk to get the paths and copy them
    ldd "$binary" | awk '$3 != "" { print $3 }' | while read -r lib; do
        if [ -n "$lib" ] && [ -e "$lib" ]; then
            # Create subdirectory structure in destination
            local sub_dir=$(dirname "$lib")
            local new_dir="$dest_dir$(echo "$sub_dir" | sed "s|^/||")"

            mkdir -p "$new_dir"  # Create the necessary subdirectories

            cp "$lib" "$new_dir"  # Copy the library to the new directory
            echo "Copied $lib to $new_dir"
        else
            echo "Library not found: $lib"
        fi
    done
}


echo "Copying cryptsetup and dependencies"
cp  cryptsetup/cryptsetup initramfs/bin/cryptsetup
mkdir -p  initramfs/lib64/
cp /lib64/ld-linux-x86-64.so.2 initramfs/lib64/
copy_ldd_libs cryptsetup/cryptsetup initramfs/

# dmsetup
cp cryptsetup/LVM2.2.03.26/libdm/dm-tools/dmsetup.static initramfs/bin/

cd initramfs
find . -printf "%P\n" -type f | cpio -H newc -o > ../initramfs.cpio
cd ..
cat initramfs.cpio | gzip > initramfs.igz

echo "...done"
