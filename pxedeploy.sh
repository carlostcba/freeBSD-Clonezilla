#!/usr/local/bin/bash

function ip_validity {
	ip=${1:-$1}
	re='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'
	re+='0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))$'
	if [[ $ip =~ $re ]]; then
		return 0
	else
		return 1
	fi
}

function netmask_validity {
	echo $1 | grep -w -E -o '^(254|252|248|240|224|192|128)\.0\.0\.0|255\.(254|252|248|240|224|192|128|0)\.0\.0|255\.255\.(254|252|248|240|224|192|128|0)\.0|255\.255\.255\.(254|252|248|240|224|192|128|0)' > /dev/null
	if [ $? -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

function clonezilla_install {
	./ClonezillaInstall $2
	chown -R nobody:wheel /"$2"/images
	chown -R $1:wheel /"$2"/tftp
}

function configure_hostname {
	local __returnvar=$1
	local new_hostname
	read -e -p "Enter hostname of PXE server: " new_hostname
	sed -i '' "s/hostname=.*/hostname=\"$new_hostname\"/" /etc/rc.conf
	echo "Hostname updated to $new_hostname"
	printf -v "$__returnvar" '%s' "$new_hostname"
}

function configure_admin_account {
	local __returnvar=$1
	local admin_account
	read -e -p "Enter username for creating admin account: " admin_account
	echo -n "Enter "
	pw useradd -n $admin_account -m -s /usr/local/bin/bash -G wheel -h 0 -L default
	echo -n "Setting $admin_account with administrative privileges..."
	sed -i '' "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /usr/local/etc/sudoers
	echo 'Defaults:admin timestamp_timeout=30' >> /usr/local/etc/sudoers
	echo "done"
	printf -v "$__returnvar" '%s' "$admin_account"
}

function configure_ip {
	rm /usr/local/etc/dnsmasq.conf
	echo "NOTE: Configure only one network interface card with static IP address"
    for int in $(ifconfig -l ether); do
		while true; do
			networkname=$(pciconf -lv | grep -A 2 $int | awk -F"'" '{print $2}' | paste -sd " " -)
			echo "NIC $int detected as$networkname"
			read -e -p "Configure $int? (DHCP|static|skip|exit): " int_prompt
			if [ $int_prompt == "DHCP" ]; then
				grep -q ifconfig_$int /etc/rc.conf
				if [ $? -eq 0 ]; then
					sed -i '' "s/ifconfig_$int=.*/ifconfig_$int=\"DHCP\"/" /etc/rc.conf
				else
					echo "ifconfig_$int=\"DHCP\"" >> /etc/rc.conf
				fi
				echo "Network interface $int set to DHCP"
				break
			elif [ $int_prompt == "static" ]; then
				while true; do
               		read -e -p "Enter IP Address for $int: " int_ip
					if ip_validity $int_ip; then
						break
					else
						echo "Invalid IP address"
					fi
				done
				while true; do
					read -e -p "Enter Netmask for $int: " netmask
					if netmask_validity $netmask; then
						grep -q ifconfig_$int /etc/rc.conf
						if [ $? -eq 0 ]; then
							sed -i '' "s/ifconfig_$int=.*/ifconfig_$int=\"inet $int_ip netmask $netmask\"/" /etc/rc.conf
						else
							echo "ifconfig_$int=\"inet $int_ip netmask $netmask\"" >> /etc/rc.conf
						fi
						echo "Network interface $int set to IP: $int_ip, Netmask: $netmask"
						break
					else
						echo "Invalid Netmask address"
					fi
				done
				while true; do
					read -e -p "Do you want to configure DHCP, NFS and PXE on interface ${int}? (y/n): " dhcp_prompt
					if [ $dhcp_prompt == 'y' ]; then
						if [[ -f /usr/local/etc/dnsmasq.conf ]]; then
							echo "DHCP and PXE configuration already configured on another interface"
						else
							configure_boot_ipxe $int_ip $1
							configure_dhcp $int $int_ip $1
							configure_nfs $1
							configure_apache $int_ip $1
							break
						fi
					elif [ $dhcp_prompt == 'n' ]; then
						break
					else
						echo "Invalid option"
					fi
				done
				break
			elif [ $int_prompt == "skip" ]; then
				break
			elif [ $int_prompt == "exit" ]; then
				return 0
			else
				echo "Invalid option"
			fi
		done
	done
}

function configure_dhcp {
	while true; do
		read -e -p "Enter starting IP address DHCP range for interface $1: " low_ip
		if ip_validity $low_ip; then
			break
		else
			echo "Invalid IP Address"
		fi
	done
	while true; do
		read -e -p "Enter ending IP address range: " high_ip
		if ip_validity $high_ip; then
			write_dhcp_file $1 $2 $low_ip $high_ip $3
			break
		else
			echo "Invalid IP Address"
		fi
	done
}

function write_dhcp_file {
	echo -n "Writing DHCP configuration..."
	echo "interface=$1
port=0
log-dhcp
listen-address=$2
no-hosts
dhcp-range=$3,$4,1h
dhcp-match=set:bios,60,PXEClient:Arch:00000
dhcp-boot=tag:bios,ipxe.pxe,$2
dhcp-match=set:efibc,60,PXEClient:Arch:00007
dhcp-boot=tag:efibc,ipxe.efi,$2
dhcp-match=set:efi64,60,PXEClient:Arch:00009
dhcp-boot=tag:efi64,ipxe.efi,$2
dhcp-match=set:iPXE,175
dhcp-boot=tag:iPXE,boot.ipxe
enable-tftp
tftp-root=/$5/tftp" > /usr/local/etc/dnsmasq.conf
	echo 'dnsmasq_enable="YES"' >> /etc/rc.conf
	echo "done"
}

function configure_nfs {
	echo "/"$1" -alldirs" > /etc/exports
	echo 'nfs_server_enable="YES"
mountd_enable="YES"
rpcbind_enable="YES"' >> /etc/rc.conf
}

function configure_samba {
	touch /usr/local/etc/smb4.conf
	while true; do
		echo "Enter Samba password for $3 account for file access from Windows client"
		pdbedit -a $3
		if [ $? -eq 0 ]; then
			break
		else
			continue
		fi
	done
	echo "Configuring Samba for Windows access..."
	echo "[global]
workgroup = WORKGROUP
server string = $1 Samba Server
netbios name = $1
wins support = Yes
security = user
passdb backend = tdbsam

[OS]
path = /$2/os
valid users = $3
writable = yes
browsable = yes
read only = no
guest ok = no
public = no
create mask = 0770
directory mask = 0770

[Images]
path = /$2/images
valid users = $3
writable = yes
browsable = yes
read only = no
guest ok = no
public = no
create mask = 0770
directory mask = 0770" > /usr/local/etc/smb4.conf
	echo 'samba_server_enable="YES"' >> /etc/rc.conf
	echo "done"
}

function configure_apache {
	echo -n "Configuring Apache..."
	sed -i '' "s/#ServerName.*/ServerName $1:80/" /usr/local/etc/apache24/httpd.conf
	echo "alias /images /"$2"
<Directory /"$2">
	Options Indexes FollowSymLinks MultiViews
	Require all granted
</Directory>" >> /usr/local/etc/apache24/httpd.conf
	echo 'apache24_enable="YES"' >> /etc/rc.conf
	echo "done."
}

function configure_boot_ipxe {
	echo -n "Configuring iPXE..."
	cp /usr/local/share/ipxe/ipxe.pxe /"$2"/tftp/
	cp /usr/local/share/ipxe/ipxe.efi-x86_64 /"$2"/tftp/
	mv /"$2"/tftp/ipxe.efi-x86_64 /"$2"/tftp/ipxe.efi
	echo "#!ipxe

:start
menu PXE Server Boot Menu
item clonezilla Boot Clonezilla
item disk Backup Disk to Image
item partition Backup Partitions to Image
item shell Enter Shell
item exit Exit

choose --default shell option && goto \${option}

:clonezilla
set cz_root nfs://$1/$2/tftp/clonezilla/live
kernel \${cz_root}/vmlinuz initrd=initrd.img boot=live username=user \
union=overlay config components noswap edd=on nomodeset nodmraid \
locales=en_US.UTF-8 keyboard-layouts=NONE ocs_live_run=\"ocs-live-general\" \
ocs_live_extra_param=\"\" ocs_live_batch=no net.ifnames=0 nosplash noprompt \
dhcp netboot=nfs nfsroot=$1:/$2/tftp/clonezilla
initrd \${cz_root}/initrd.img
imgstat
boot
:disk
set cz_root nfs://$1/$2/tftp/clonezilla/live
kernel \${cz_root}/vmlinuz initrd=initrd.img boot=live username=user \
union=overlay config components noswap edd=on nomodeset nodmraid \
locales=en_US.UTF-8 keyboard-layouts=NONE ocs_live_run=\"ocs-live-general\" \
ocs_live_extra_param=\"\" ocs_live_batch=no net.ifnames=0 nosplash noprompt \
dhcp netboot=nfs nfsroot=$1:/$2/tftp/clonezilla \
ocs_prerun1=\"mount -t nfs $1:/$2/images /home/partimag -o \
noatime,nodiratime,\" oscprerun2=\"sleep 10\" ocs_live_run=\"/usr/sbin/ocs-sr \
-q2 -j2 -nogui -z1p -i 1000000 -fsck-y -senc -p reboot savedisk ask_user \
ask_user\"
initrd \${cz_root}/initrd.img
imgstat
boot
:partition
set cz_root nfs://$1/$2/tftp/clonezilla/live
kernel \${cz_root}/vmlinuz initrd=initrd.img boot=live username=user \
union=overlay config components noswap edd=on nomodeset nodmraid \
locales=en_US.UTF-8 keyboard-layouts=NONE ocs_live_run=\"ocs-live-general\" \
ocs_live_extra_param=\"\" ocs_live_batch=no net.ifnames=0 nosplash noprompt \
dhcp netboot=nfs nfsroot=$1:/$2/tftp/clonezilla \
ocs_prerun1=\"mount -t nfs $1:/$2/images /home/partimag -o \
noatime,nodiratime,\" oscprerun2=\"sleep 10\" ocs_live_run=\"/usr/sbin/ocs-sr \
-q2 -j2 -nogui -z1p -i 1000000 -fsck-y -senc -p reboot saveparts ask_user \
ask_user\"
initrd \${cz_root}/initrd.img
imgstat
boot
:shell
shell
:exit
exit" > /"$2"/tftp/boot.ipxe
	echo "done"
}

function create_storage_pool {
	local __returnvar=$1
	local pool_name
	while true; do
		read -p "Enter name of new storage pool (small letters only): " pool_name
		echo "List of Available Disks: "
		echo ""
		for disks in $(geom disk list | grep Name | awk '{print $3}' | paste -sd " " -); do
			diskmodel=$(geom disk list $disks | grep -E -- 'descr|ident' | awk -F":" '{print $2}' | paste -sd " " -)
			disksize=$(geom disk list $disks | grep Mediasize | awk '{print $3}' | tr -d '()')
			echo "${disks}: - $diskmodel - Size: $disksize"
		done
		echo ""
		echo "List of RAID options:"
		echo ""
		echo "1: Single disk"
		echo "2: RAID 1 (minimum 2 disks required, 1 disk failure max)"
		echo "3: RAID 5 (minimum 3 disks required, 1 disk failure max)"
		echo "4: RAID 6 (minimum 3 disks required, 2 disk failures max)"
		echo "5: RAID 10 (minimum 4 disks required, 1 disk failure max per mirror set)"
		echo ""
		read -p "Select RAID option for creating storage pool (1-5): " raid_option
		case $raid_option in
			1)
				read -p "Enter disk dev name (e.g. ada1): " mirror_disks
				zpool create $pool_name $mirror_disks
				if [ $? -ne 0 ]; then
					continue
				else
					echo "Single disk storage pool $pool_name created successfully"
					break
				fi
				;;
			2)
				read -p "Enter disk dev names with spaces (e.g. ada1 ada2): " mirror_disks
				zpool create $pool_name mirror $mirror_disks
				if [ $? -ne 0 ]; then
					continue
				else
					echo "RAID 1 storage pool $pool_name created successfully"
					break
				fi
				;;
			3)
				read -p "Enter disk dev names with spaces (e.g. ada1 ada2): " mirror_disks
				zpool create $pool_name raidz $mirror_disks
				if [ $? -ne 0 ]; then
					continue
				else
					echo "RAID 5 (1 parity disk) storage pool $pool_name created successfully"
					break
				fi
				;;
			4)
				read -p "Enter disk dev names with spaces (e.g. ada1 ada2): " mirror_disks
				zpool create $pool_name raidz2 $mirror_disks
				if [ $? -ne 0 ]; then
					continue
				else
					echo "RAID 5 (2 parity disks) storage pool $pool_name created successfully"
					break
				fi
				;;
			5)
				read -p "Enter disk dev names for first mirror set (e.g. ada1 ada2): " mirror_disk_set1
				read -p "Enter disk dev names for second mirror set (e.g. ada3 ada4): " mirror_disk_set2
				zpool create $pool_name mirror $mirror_disk_set1 mirror $mirror_disk_set2
				if [ $? -ne 0 ]; then
					continue
				else
					echo "RAID 10 storage pool $pool_name created successfully"
					break
				fi
				;;
			*)
				echo "Invalid Option"
				;;
		esac
	done
	echo 'zfs_enable="YES"' >> /etc/rc.conf
	printf -v "$__returnvar" '%s' "$pool_name"
}

function import_storage_pool {
	local __returnvar=$1
	local pool_name
	while true; do
		zpool import
		read -p "Enter name of pool to import (0 to exit): " pool_import
		zpool import -f $pool_import
		if [ $? -ne 0 ]; then
			echo "Cannot import storage pool"
		else
			echo 'zfs_enable="YES"' >> /etc/rc.conf
			echo "Storage pool $pool_import imported successfully"
			break
		fi
	done
	printf -v "$__returnvar" '%s' "$pool_name"
}

function create_pxe_directories {
	echo -n "Creating required PXE directories and setting permissions..."
	mkdir /"$1"/images
	mkdir -p /"$1"/tftp/clonezilla
	mkdir /"$1"/os
	mkdir /"$1"/pxe_management
	chown -R $2:wheel /"$1"
	chown -R nobody:wheel /"$1"/images
	chmod -R 770 /"$1"/images
	echo "done"
}

function copy_management {
	echo -n "Configuring PXE Management Application for startup at login..."
	chmod +x /"$2"/pxe_management/pxe_management
	echo "echo 'Loading PXE Management Application...'" >> /home/"$1"/.profile
	echo "/$2/pxe_management/pxe_management /$2" >> /home/"$1"/.profile
	chown -R $1:wheel /"$2"/pxe_management
	echo "done"
}

function enable_autoreplace {
	echo -n "Enabling autoreplace feature on ZFS pool $1..."
	if [ $? -eq 0 ]; then
		zpool set autoreplace=on $1
		echo "done"
	else
		echo "error. ZFS pool name /$1 does not exist."
	fi
}

configure_hostname new_server_hostname ; server_hostname=${new_server_hostname}
configure_admin_account new_admin ; admin_username=${new_admin}
while true; do
	read -p "Create new storage pool or import working storage pool? (create|import): " storage_option
	case $storage_option in
		create)
			create_storage_pool new_zfs_pool ; storage_pool_name=${new_zfs_pool}
			break
			;;
		import)
			import_storage_pool existing_zfs_pool ; storage_pool_name=${existing_zfs_pool}
			break
			;;
		*)
			echo "Invalid option"
			;;
	esac
done
create_pxe_directories $storage_pool_name $admin_username
configure_samba $server_hostname $storage_pool_name $admin_username
configure_ip $storage_pool_name
clonezilla_install $admin_username $storage_pool_name
copy_management $admin_username $storage_pool_name
enable_autoreplace $storage_pool_name
while true; do
	read -p "PXE Server installation and configuration complete. Reboot server? (y/n): " reboot_prompt
	case $reboot_prompt in
		y) reboot;;
		n) exit 0;;
		*) echo "Invalid option";;
	esac
done
