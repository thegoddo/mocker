# 1. Bring down the bridge interface
sudo ip link set dev bridge0 down

# 2. Delete the network bridge
sudo ip link del dev bridge0

# 3. Unmount the Btrfs filesystem
sudo umount /var/bocker

# 4. Remove the image file and mount directory
sudo rm -f /var/bocker.img
sudo rm -rf /var/bocker
