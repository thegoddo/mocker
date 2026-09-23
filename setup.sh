sudo truncate -s 10G /var/bocker.img
sudo mkfs.btrfs /var/bocker.img
sudo mkdir -p /var/bocker
sudo mount -o loop /var/bocker.img /var/bocker
sudo ip link add dev bridge0 type bridgesudo ip addr add 10.0.0.1/24 dev bridge0sudo ip link set dev bridge0 up
