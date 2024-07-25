#!/bin/bash
VERSION="1.0.0"
CONTACT="crowdstrikefix@gmail.com"

RED="\e[31m"
YELLOW="\e[43m"
GREEN="\e[42m"
ENDCOL="\e[0m"


echo "***************STARTING***************"
echo -e "\n\n"
echo "Welcome to the Debian Rescue Environment"
echo "  Version: ${VERSION}"
echo -e "\n\n"
echo "**************************************"
echo -e "\nThis tool is designed to remove the offending files causing Windows to BSOD."
echo "There will be few prompts, after which you can reboot your machine, or" 
echo "drop into a console and inspect the damage more closely.  This is a live-system,"
echo "meaning that any changes made directly to this system will not persist."
echo -e "\n\n"
echo -e "The maker of this software shall not be held responsible for any\n actions taken by users while using the software. Users assume all responsibility\n for any outcomes resulting from the use of this software.\n"

# find media to mount
echo -e "${YELLOW}Finding media to mount...${ENDCOL}\n"
drives=$(cat /proc/partitions | awk '{ print $4 }' | tail -n +3)
target=""
for d in $drives
do 
    echo "Found drive partition /dev/${d}"
    cat /proc/mounts | grep -q "/dev/${d}"
    if [ $? -eq 1 ]
    then
        # didn't find existing mount, try to mount
        mkdir -p /mnt/$d
        fstype=$(lsblk -f /dev/$d | tail -n +2)
        if [[ -n $(echo $fstype | grep "Bitlocker") ]]; then
            drive_unlocked=0
            echo -e "${YELLOW}\nFound a Bitlocker encrypted drive /dev/$d. You'll need to provide a key to access it${ENDCOL}"

            read -p "Please enter the Bitlocker recovery key for this drive, exactely as it is: " btkey
            mkdir -p /mnt/bitlocker_vol
            echo -e "${YELLOW}\nAttempting to open encrypted volume.  Please wait...${ENDCOL}"
            dislocker -v -V /dev/$d --recovery-password=$btkey /media/bitlocker_vol
            if [ $? -eq 0 ]; then
                drive_unlocked=1 
                echo "Successfull."
                mount -o loop,rw /media/bitlocker_vol/dislocker-file /mnt/$d
                if [[ -e /mnt/$d/Windows ]]; then 
                    echo "Found Windows system on /dev/$d"
                    echo "Looking for Crowdstrike file in /mnt/${d}/Windows/System32/drivers/CrowdStrike/.  There may be more than one."
                    file=$(find /mnt/$d/Windows/System32/drivers/CrowdStrike/ -name "C-00000291*.sys")
                    # get last modified time
                    for f in $(file); do
                        mtime=$(ls -l --time-style=+%s $f | awk '{ print $6 }')
                        if [[ $mtime -le 1721362140 ]]; then 
                            read -p "Found offending file $f. Would you like to remove it?" confirm
                            if [[ $confirm == "y" ]]; then
                                echo "Removing file ${f}" 
                                rm -f $f
                                echo "Done.  Unmounting volumes..."
                                umount /dev/$d
                                umount /mnt/bitlocker_vol
                                echo "Done."
                            else
                                echo -e "Did not remove file.  Are you sure?\n"
                                echo "Unmounting volumes..."
                                umount /dev/$d
                                umount /mnt/bitlocker_vol
                                echo -e "Done.\n\n"
                                echo -e "${YELLOW}You can run this script again by typing the command /usr/local/bin/cs_fix.sh${ENDCOL}"
                            fi
                        fi
                    done
                fi
            fi 
        else
            mount -t auto /dev/$d /mnt/$d
            if [ $? -ne 0 ]
            then
                # mount was unsuccessful. umount (just in case_ and remove orig mount point
                umount -q /dev/$d
                rm -r /mnt/$d
                # Go to next loop iteration if there was an error mounting this drive
                continue
            fi
            echo  "Successfully mounted /dev/${d} to /mnt/${d}. Looking for Windows filesystem..."
            if [[ -e /mnt/$d/Windows ]]
            then
                echo "Found Windows system on /dev/$d"
                echo "Looking for Crowdstrike file in /mnt/${d}/Windows/System32.  There may be more than one..."
                file=$(find /mnt/$d/Windows/System32/drivers/CrowdStrike/ -name "C-00000291*.sys")
                # get last modified time
                for f in $file
                do 
                    mtime=$(ls -l --time-style=+%s $f | awk '{ print $6 }')
	     	    # confirm existence of C-00000291*.sys” with timestamp of 2024-07-19 0409 UTC 
		    if [[ $mtime -le 1721362140 ]]
                    then
                        read -p "Found offending file $f.  Would you like to remove this file? y/n" confirm
                        if [[ $confirm == y ]]
                        then
                            echo "Removing file ${f}..."
                            rm -f $f
                            umount /dev/$d
                        else
                            echo "NOT removing file $f.  Was this intentional?"
                        fi
                    fi
                done
            else
                echo "No Windows system found on /dev/$d"
            fi
        fi
    fi
    echo -e "\n"
done
# Cleanup
if [ -n "$drives" ]
then
    echo "Cleaning up..."
    for d in $drives
    do
        umount /dev/$d
    done
    echo "Done."
fi

echo -e "\n\n"
echo "Script has finished.  If you need to run the script again,"
echo -e "select console at the following prompt, then run the command\n"
echo "sudo /bin/bash /usr/local/bin/cs_fix.sh"
echo -e "\n"
echo "Let us know about bugs at crowdstrikefix@gmail.com"
echo 'You can also donate to improving this software at https://cash.app/$crowdstrikefix '
echo -e "\n\n"

read -p "Would you like to reboot? Selecting n will drop you into a user shell: (y/n)" response
if [[ $response == y ]]
then 
    echo "Rebooting Now..."
    systemctl reboot
else
    exit 0
fi

exit 0
