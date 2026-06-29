# Homelab
[![SSH Deploy K8s](https://github.com/lubbaragaki/homelab/actions/workflows/kubes-deploy.yml/badge.svg)](https://github.com/lubbaragaki/homelab/actions/workflows/kubes-deploy.yml)

# Raspberry Pi 4B 

First, I used rpi-imager to write raspberry pi OS onto my 2TB hard disk, while configuring it with my ssh key and user/password, then connected it to a USB port on the rpi4 and booted it. After it finished installation of the OS, I ssh into it before moving on to the more complex part.
I plan on installing a samba server on it, and I want to be able to use quotas, so I will transform the /srv directory into a btrfs filesystem, which has a native and easy way to put quotas on subvolumes.

Let the rpi install the OS on the HDD, then reboot from a USB running rpi OS configured the same way and connect back the hdd, bcause we need to be offline to do our modifications.
In the following instructions I am assuming that the HDD is `sda` however you should replace it with whatever disk name appeared for you.

First we resize the ext4 filesystem so that it matches our shrinked partition: `resize2fs /dev/sda2 900G`.


Then we need to modify the partitioning of the disk. We will resize the root partition, then create a new partition.
```
root@shinsengumi:~# parted /dev/sda
GNU Parted 3.6
Using /dev/sda
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) h
  align-check TYPE N                       check partition N for TYPE(min|opt) alignment
  help [COMMAND]                           print general help, or help on COMMAND
  mklabel,mktable LABEL-TYPE               create a new disklabel (partition table)
  mkpart PART-TYPE [FS-TYPE] START END     make a partition
  name NUMBER NAME                         name partition NUMBER as NAME
  print [devices|free|list,all]            display the partition table, or available devices, or free
        space, or all found partitions
  quit                                     exit program
  rescue START END                         rescue a lost partition near START and END
  resizepart NUMBER END                    resize partition NUMBER
  rm NUMBER                                delete partition NUMBER
  select DEVICE                            choose the device to edit
  disk_set FLAG STATE                      change the FLAG on selected device
  disk_toggle [FLAG]                       toggle the state of FLAG on selected device
  set NUMBER FLAG STATE                    change the FLAG on partition NUMBER
  toggle [NUMBER [FLAG]]                   toggle the state of FLAG on partition NUMBER
  type NUMBER TYPE-ID or TYPE-UUID         type set TYPE-ID or TYPE-UUID of partition NUMBER
  unit UNIT                                set the default unit to UNIT
  version                                  display the version number and copyright information of GNU
        Parted
(parted) print
Model: Seagate Expansion (scsi)
Disk /dev/sda: 2000GB
Sector size (logical/physical): 512B/4096B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
 1      8389kB  545MB   537MB   primary  fat32        lba
 2      545MB   2000GB  2000GB  primary  ext4
```
The partition that uses the `fat32` filesystem is the boot partition, so partition number 2 is our root partition. As we can see from the help menu, we will use the `resizepart` command.
```
(parted) resizepart 2 1000GB
Warning: Partition /dev/sda2 is being used. Are you sure you want to continue?
Yes/No? y
Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
Yes/No? y
```
This is a new installation, so resizing will not result in data loss as the rest of the disk has not been used anyway. Looking at the help menu again, the next command to use is `mkpart`, like so:
```
(parted) mkpart primary btrfs 1000GB 2000GB
(parted) print
Model: Seagate Expansion (scsi)
Disk /dev/sda: 2000GB
Sector size (logical/physical): 512B/4096B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
 1      8389kB  545MB   537MB   primary  fat32        lba
 2      545MB   1000GB  999GB   primary  ext4
 3      1000GB  2000GB  1000GB  primary  btrfs
 ```
 Now simply type `quit` to go back to the shell prompt. We can check that the partitioning is correct:
 ```
 root@shinsengumi:~# lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0     2G  0 loop
sda      8:0    0   1.8T  0 disk
├─sda1   8:1    0   512M  0 part /boot/firmware
├─sda2   8:2    0 930.8G  0 part /
└─sda3   8:3    0 931.7G  0 part
zram0  254:0    0     2G  0 disk [SWAP]
```

For the next part, we need to install the required programs first: `apt install -y btrfs-progs`.
First we format the parition as a btrfs filesystem:
```
root@shinsengumi:~# mkfs.btrfs -f --csum xxhash -L Samba /dev/sda3
btrfs-progs v6.14
See https://btrfs.readthedocs.io for more information.

NOTE: several default settings have changed in version 5.15, please make sure
      this does not affect your deployments:
      - DUP for metadata (-m dup)
      - enabled no-holes (-O no-holes)
      - enabled free-space-tree (-R free-space-tree)

Label:              Samba
UUID:               33e5a789-473d-4cd6-b48b-2647761892ba
Node size:          16384
Sector size:        4096	(CPU page size: 4096)
Filesystem size:    931.69GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         DUP               1.00GiB
  System:           DUP               8.00MiB
SSD detected:       no
Zoned device:       no
Features:           extref, skinny-metadata, no-holes, free-space-tree
Checksum:           xxhash64
Number of devices:  1
Devices:
   ID        SIZE  PATH
    1   931.69GiB  /dev/sda3
```
We can check again:
```
root@shinsengumi:~# lsblk -f
NAME   FSTYPE FSVER LABEL  UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
loop0  swap   1
sda
├─sda1 vfat   FAT32 bootfs 18D4-404A                             425.6M    16% /boot/firmware
├─sda2 ext4   1.0   rootfs ed6c7f1b-238b-41a1-b4b6-7bcdef3270fe    1.7T     0% /
└─sda3 btrfs        Samba  33e5a789-473d-4cd6-b48b-2647761892ba
zram0  swap   1     zram0  d283294e-6fca-45e0-9c7c-bd4079d0af36                [SWAP]
```
Now run `mount /dev/sda2 /mnt && cd /mnt` then edit `./etc/fstab`, adding this line (adjust accordingly):
This command is useful because we now have the UUID of the partition, which we can use to update the `/etc/fstab` file. This file tells Linux where and how to mount which filesystems. The additional line in the file should look something like this:
```
UUID=33e5a789-473d-4cd6-b48b-2647761892ba /srv btrfs defaults 0 0
```
Then `umount /mnt`, and reboot into the hard drive instead of the usb.
After rebooting, this should be the result:
```
saku@shinsengumi:~ $ lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0     2G  0 loop
sda      8:0    0   1.8T  0 disk
├─sda1   8:1    0   512M  0 part /boot/firmware
├─sda2   8:2    0 930.8G  0 part /
└─sda3   8:3    0 931.7G  0 part /srv
zram0  254:0    0     2G  0 disk [SWAP]
```

Run `apt install -y btrfs-progs`.
Now we will configure our btrfs filesystem. Enable compression on it and create a subvolume which will be used by samba.
```
root@shinsengumi:~# btrfs property set /srv compression zstd
root@shinsengumi:~# btrfs property get /srv compression
compression=zstd
root@shinsengumi:~# btrfs subvolume create /srv/samba
Create subvolume '/srv/samba'
root@shinsengumi:~# btrfs subvolume create /srv/snapshots
Create subvolume '/srv/snapshots'
root@shinsengumi:~# ls -l /srv
total 0
drwxr-xr-x 1 root root 0 Jun 13 14:43 samba
drwxr-xr-x 1 root root 0 Jun 13 14:46 snapshots
```

