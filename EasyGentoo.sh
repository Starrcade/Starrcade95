#!/bin/bash
clear

ssh=""
install_ssh=""
internet=""
root_part=""
efi_boot_part=""
bios_boot_part=""
home_part=""
swap_part=""
profile_no=
timezone=""
locale=
interface=""
pcmcia=""
cron_support=""
file_indexing=""
bios_efi=""
grub_part=""
reboot=""
username=""
delete_tarball=""

echo "Welcome to the Easy Gentoo Installer!"
echo "brought to you by Pascal3366"
echo "this is free software lying under the GPLv3"
echo "feel free to fork, share or contribute!"
echo "This script needs to be run under root."
echo "------------------------------------"
echo "Getting IP address through DHCP..."
dhcpcd
echo "Testing Internet Access ..."
ping -c 3 www.gentoo.org
echo "Does the Internet Access work? (yes/no)"
read internet

if [ "$internet" = "no" ]
then
    net-setup eth0
else
    echo ""
fi

echo "Would you like to start an SSH-Server for remote installation? (yes/no)"
read ssh

if [ "$ssh" = "yes" ]
then
    /etc/init.d/sshd start
else
    echo ""
fi

    echo "Partitioning"
    echo "(Please input just the block device without /dev/)"
    echo "------------------------------------"
    echo "Choose the block device for the root partition:"
    lsblk
    echo "Input:"
    read root_part
    mkfs.ext4 /dev/$root_part
    echo "Choose the block device for the efi boot partition:"
    lsblk
    echo "Input:"
    read boot_part
    mkfs.vfat /dev/$efi_boot_part
    echo "Choose the block device for the BIOS boot partition:"
    lsblk
    echo "Input:"
    read bios_boot_part
    mkfs.ext2 /dev/$bios_boot_part
    echo "Choose the block device for the home partition:"
    lsblk
    echo "Input:"
    read home_part
    mkfs.ext4 /dev/$home_part
    echo "Choose the block device for the swap partition:"
    lsblk
    echo "Input:"
    read swap_part
    mkswap /dev/$swap_part
    swapon /dev/$swap_part
    echo "Mounting the partitions..."
    mount /dev/$root_part /mnt/gentoo
    mkdir /mnt/gentoo/boot
    mkdir /mnt/gentoo/boot/efi
    mkdir /mnt/gentoo/home
    mount /dev/$efi_boot_part /mnt/gentoo/boot/efi
    mount /dev/$bios_boot_part /mnt/gentoo/boot
    mount /dev/$home_part /mnt/gentoo/home
    echo "Getting the newest stage3 tarball..."
    cd /mnt/gentoo
    wget http://ftp.halifax.rwth-aachen.de/gentoo/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-20160526.tar.bz2
    tar xvjpf stage3-*.tar.bz2 --xattrs
    read -p "Press any key to edit your make.conf" -n1 -s
    nano -w /mnt/gentoo/etc/portage/make.conf
    echo "Selecting the best mirror..."
    mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
    echo "Creating portage repos ..."
    mkdir /mnt/gentoo/etc/portage/repos.conf
    cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
    echo "saving DNS Info to installation"
    cp -L /etc/resolv.conf /mnt/gentoo/etc/
    echo "Mounting all neccessary filesystems for chrooting ..."
    mount -t proc proc /mnt/gentoo/proc
    mount --rbind /sys /mnt/gentoo/sys
    mount --make-rslave /mnt/gentoo/sys
    mount --rbind /dev /mnt/gentoo/dev
    mount --make-rslave /mnt/gentoo/dev
    echo "Getting into the new created chroot ..."
    chroot /mnt/gentoo /bin/bash
    source /etc/profile
    export PS1="(chroot) $PS1"
    echo "fetching the latest portage snapshot ..."
    emerge-webrsync
    echo "Updating the whole portage tree... This can take some time, please be patient ..."
    emerge --sync --quiet
    echo "Done."
    echo "Please select a system profile for your installation."
    eselect profile list
    echo "Profile No.:"
    read profile_no
    eselect profile set $profile_no
    echo "Now we need to re-merge the whole world set ..."
    emerge --update --deep --newuse @world
    echo "Done."
    echo "At this point you need to configure your USE flags..."
    echo "Your system should work with the following USE flags:"
    emerge --info | grep ^USE
    read -p "Press any key to edit your make.conf and set your USE flags..." -n1 -s
    nano -w /etc/portage/make.conf
    echo "Now setting timezone settings..."
    ls /usr/share/zoneinfo
    echo "Select Timezone"
    echo "timezone:"
    read timezone
    echo $timezone > /etc/timezone
    emerge --config sys-libs/timezone-data
    echo "Configuring locales ..."
    read -p "Press any key to edit your locale settings. Uncomment all of your wanted language entries."
    nano -w /etc/locale.gen
    locale-gen
    echo "Now you will need to set the locale settings system wide."
    read -p "Press any key to show the locale list and set your locale number." -n1 -s
    eselect locale list
    echo "locale:"
    read locale
    eselect locale set $locale
    echo "Reloading Environemnt ..."
    env-update && source /etc/profile && export PS1="(chroot) $PS1"
    echo "Compiling and installing the kernel ..."
    emerge sys-kernel/genkernel
    echo "Done."
    echo "Next you need edit your fstab file."
    echo "Here are your partitons:"
    lsblk
    read -p "Press any key to edit your fstab file, this is neccessary." -n1 -s
    nano -w /etc/fstab
    echo "Now compiling the kernel... Please be patient."
    genkernel all
    echo "Configuring Kernel Modules:"
    find /lib/modules/<kernel version>/ -type f -iname '*.o' -or -iname '*.ko' | less
    read -p "Press any key to edit your modules conf and submit the modules you need." -n1 -s
    nano -w /etc/conf.d/modules
    echo "Now installing the linux-firmware for wifi and other stuff..."
    emerge sys-kernel/linux-firmware
    read -p "Press any key to set your hostname." -n1 -s
    nano -w /etc/conf.d/hostname
    read -p "Press any key to set your domain name." -n1 -s
    nano -w /etc/conf.d/net
    echo "Now configuring the network."
    emerge --noreplace net-misc/netifrc
    echo "again edit the net file but this time enter dhcp if using dhcp or an ip for static ip"
    echo "for the field ´config_eth0=´"
    echo "or any other of your used LAN/WIFI interfaces."
    read -p "Press any key to edit this file..." -n1 -s
    nano -w /etc/conf.d/net
    echo "Please specify your main LAN/WIFI interface :"
    echo "interface:"
    read interface
    echo "enabling interface at boot."
    ln -s /etc/init.d/net.lo net.$interface
    rc-update add net.$interface default
    echo "Done."
    echo "Now Configuring your hosts file. (this is optional)"
    read -p "Press any key to edit your Hosts file." -n1 -s
    nano -w /etc/hosts
    echo "Are you using a PCMCIA card? (y/n)"
    read pcmcia

    if [ "$pcmcia" = "y" ]
    then
	emerge sys-apps/pcmciautils
    else
	echo ""
    fi
    
    echo "Now setting the root password."
    passwd
    echo "now review the rc.conf file and make changes if neccessary for booting."
    read -p "Press any key to do this..." -n1 -s
    nano -w /etc/rc.conf
    echo "and now the file to specify the keyboard layout to use..."
    read -p "Press any key to do this..." -n1 -s
    nano -w /etc/conf.d/keymaps
    echo "finally edit the settings for the hardware clock..."
    read -p "Press any key to do this..." -n1 -s
    nano -w /etc/conf.d/hwclock
    echo "Installing the System Logger package..."
    emerge --ask app-admin/sysklogd
    rc-update add sysklogd default
    echo "Would you like to install a cronjob daemon? (y/n)"
    read cron_support

    if [ "$cron_support" = "y" ]
    then
	 emerge sys-process/cronie;
	 rc-update add cronie default;
	 crontab /etc/crontab
    else
	echo ""
    fi
    
    echo "Would you like to enable file indexing? (y/n)"
    read file_indexing

    if [ "$file_indexing" = "y" ]
    then
	emerge sys-apps/mlocate
    else
	echo ""
    fi
    
    echo "Would you like to install the SSH-Server? (y/n)"
    read install_ssh
    
    if [ "$install_ssh" = "y" ]
    then emerge --ask --changed-use net-misc/openssh;
	 /usr/bin/ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N "";
	 /usr/bin/ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "";
	 nano -w /etc/ssh/sshd_config;
	 rc-update add sshd default;
	 rc-service sshd start
    else
	echo ""
    fi
    
    echo "Installing additional filesystem tools..."
    emerge sys-fs/e2fsprogs
    emerge sys-fs/dosfstools
    echo "Installing DHCP Service ..."
    emerge net-misc/dhcpcd
    echo "Now installing the bootloader."
    echo "We will use Grub2."
    emerge sys-boot/grub:2
    echo "Now set the line GRUB_PLATFORMS= in /etc/portage/make.conf"
    read -p "Press any key to edit the file..." -n1 -s
    nano -w /etc/portage/make.conf
    echo "Now Installing Grub2..."
    emerge sys-boot/grub:2
    echo "are you using bios or efi?"
    echo "enter bios or efi"
    echo "input:"
    read bios_efi
    echo "and specify your partition to install grub to ..."
    echo "partition:"
    read grub_part

    if [ "$bios_efi" = "bios" ]
    then
	grub2-install $grub_part
    else
	grub2-install --target=x86_64-efi --efi-directory=/boot/efi
    fi
    
    echo "Generating grub.cfg..."
    grub2-mkconfig -o /boot/grub/grub.cfg
    echo "Done."
    echo "Congratulations! The Basic Installation Is now finished!"
    echo "Now coming to the Post Installation Part..."
    echo "Creating a new User account:"
    echo "Username: "
    read username
    useradd -m -G users,wheel,audio -s /bin/bash $username
    passwd $username
    echo "Would you like to delete the downloaded tarball package?"
    echo "It is not needed anymore and can safely be removed."
    echo "(y/n)"
    read delete_tarball

    if [ "$delete_tarball" = "y" ]
    then
	rm /stage3-*.tar.bz2*
    else
	echo ""
    fi
    
    echo "Unmounting everything ..."
    umount -a
    echo "Please note: It is recommendet to do an eix-sync -v and an emerge -uvDNa --with-bdeps=y @world and also an etc-update after reboot."
    echo "Would you like to reboot? (y/n)"
    read reboot

    if [ "$reboot" = "y" ]
    then
	reboot
    else
	exit
    fi
