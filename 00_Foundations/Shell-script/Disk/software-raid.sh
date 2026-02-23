### Preliminary 
# Atleast 2 empty disk
# All data on diks will be delete!!!

apt update
apt install mdadm

mdadm --create --verbose /dev/[raid-name] \
--level=[0,1,5,6,10] --raid-devices=[number-of-raid-devices] \
[/dev/sda] [/dev/sdb] [if-more]...[device]

# Verify
cat proc/mdstat

# Create file system on raid and mount
mkfs.ext4 /dev/[raid-name]
mkdir [new-dir-to-mount]
mount [raid-name] [dir-to-mount]

# Verify
df -h

# save raid config .conf read when boot tell about which disks belong to whick raid
# 'tee' write output to a file '-a' mean append 
# can't use >> cause when pipe it handle by the shell   
# if your shell not root it permission denied (shell root sudo -i)
mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
# initramfs = temporary mini filesystem loaded during early boot.
update-initramfs -u

# See UUID 
blkid /dev/[raid-name]
# Add UUID to /etc/fstab
UUID=xxxx-xxxx [dir-to-mount] ext4 defaults 0 0
