# this should see new add disk space
lsblk

# this update partition that want to resize  
growpart /dev/sdx <partition> 

# this tell pv that partition was resize
pvresize /dev/sdxx

# verify
pvs

# this tell lv to use free pv
lvextend -L +10G /dev/[vg]/[lv]

# df -h stil see old disk space we need to tell file system
resize2fs /dev/[vg]/[lv]
