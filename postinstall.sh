#!/bin/sh

deploy()
{
    chmod +x pxedeploy.sh
    chmod +x ClonezillaInstall
    echo "Installing/updating required packages..." 
    pkg install -y sudo nano bash dnsmasq ipxe samba413 apache24
    ./pxedeploy.sh
}

echo "Welcome to the PXE Server Deployment Script Program v2.1.2!"
echo ""
echo "Deployment Script Program will be prompting and executing the following actions:"
echo ""
echo "  - Install/update required packages to system for running PXE server"
echo "  - Rename hostname of server"
echo "  - Configure an administrator account"
echo "  - Configure networking and DHCP server"
echo "  - Create or import storage pool for operating system restore images"
echo "  - Enable ZFS automatic RAID rebuild on disk failure"
echo "  - Configure network sharing access to restore images"
echo "  - Configure a basic web server"
echo "  - Download and install latest version of Clonezilla and PXE Management Application"
echo "  - Create a default boot entry menu for backing up images and booting Clonezilla"
echo ""
while :
do
    read -e -p "Proceed with setting up and installing PXE Server ? (y/n): " deploy_prompt
    case $deploy_prompt in
        y)
            deploy
            break
            ;;
        n)
            echo "Program terminated"
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done