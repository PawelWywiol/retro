# Library disk

A dedicated ext4 disk for the library and app data. Example for a USB drive on Arch Linux.

**Formatting erases the disk.** Use the `/dev/disk/by-id/...` path, never `/dev/sdX`, which can change between boots.

```sh
ls -l /dev/disk/by-id/ | grep usb                  # find the disk
DISK=/dev/disk/by-id/usb-<vendor>_<model>_<serial>-0:0
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE "$DISK"     # confirm it is the right one

sudo wipefs --all "$DISK"-part* "$DISK"            # remove old signatures (ZFS, NTFS, ...)
sudo parted --script "$DISK" mklabel gpt mkpart retro ext4 0% 100%
sudo udevadm settle
sudo mkfs.ext4 -L retro -m 0 "$DISK"-part1
```

## Mount at boot

```sh
sudo mkdir -p /mnt/retro
sudo chattr +i /mnt/retro                          # nothing can be written there while the disk is not mounted
UUID=$(sudo blkid -s UUID -o value "$DISK"-part1)
echo "UUID=$UUID /mnt/retro ext4 defaults,noatime,nofail,x-systemd.device-timeout=10s 0 2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount /mnt/retro
sudo chown "$(id -u):$(id -g)" /mnt/retro
findmnt /mnt/retro
```

`nofail` lets the machine boot without the disk. The immutable empty mount point makes containers fail instead of silently writing to the system disk.

Then in `.env`:

```sh
LIBRARY_PATH=/mnt/retro/library
DATA_PATH=/mnt/retro/data
```
