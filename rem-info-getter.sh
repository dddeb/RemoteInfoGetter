#!/bin/bash

#to run this script, use command "sudo bash <nameofthisfile.sh>"

#Contents:
#Scope 1, Part 1 - Installations and Anonymity Check:
#[1] Check if needed applications are installed, if yes THEN go to next step. ELSE install.
#[2a] Check if network connection is anonymous (Nipe service on) If service disabled, turn on.
#[2b] If unable to connect to Nipe, alert user, and exit script.
#[2c] If sucessfully connected to Nipe, display the spoofed IP and Country.

#Scope 1, Part 2 - Scan the remote server:
#[2-1] User specify domain or IP address to scan
#[2-2] Connect to remote server using sshpass
#[2-3] Show remote server's info - uptime, ip address, country

#Scope 1, Part 3 - Whois & Nmap save data and log:
#[3-1] Save remote server's Whois data to file, in local machine.
#[3-2] Create a log file on local machine for this data collection. Include day, date, time, domain/ip that was scanned.

###################################################################################################################

#~ to do:

	#~ test full script on fresh kali without installing anything
	#~ test scanning on public domains
	#~ adding exit or break scripts when any error line appears
		#~ example error lines that appeared:
		#~ 1. Usage: geoiplookup [-h] [-?] [-d custom_dir] [-f custom_file] [-v] [-i] [-l] <ipaddress|hostname>
		#~ 2. Usage: whois [OPTION]... OBJECT...

	#~ improve to use nipe even if saved in different directory
	#~ improve method to check if nipe is installed
	#~ to save time, do a check before running sudo apt-get update. if tools can be installed without update(?), don't run update.
	#~ do final check on installation status after installing apps. or exit then restart.
	#~ geoiplookup vs geoip-bin?

###################################################################################################################

#text colours
G='\033[0;32m'	#green
R='\033[0;31m'	#red
NC='\033[0m'	#normal

#[1] Check if needed applications are installed, IF yes THEN go to next step. ELSE install.

#list of tools needed for this script
apps=(
tor
sshpass
geoiplookup
)

#for loop check all apps are installed or not
for appcheck in "${apps[@]}"
do
	echo "Checking if $appcheck is installed..."
	if command -v $appcheck &> /dev/null #if installed
		then
		echo -e "${G}$appcheck is already installed.${NC}"
		sleep 1
		else #if not installed
		echo -e "${R}$appcheck is not installed. ${NC}"
		echo "Proceeding to install $appcheck. This may take awhile..."
		sleep 1
		sudo apt-get update
		sudo apt-get install $appcheck
		echo -e "${G}$appcheck has been installed.${NC}"
		echo
	fi
done

###################################################################################################################

echo "Checking if Nipe and dependant files are installed in this directory..."
sleep 1
#function to install nipe folder
function install_nipe() {
	git clone https://github.com/htrgouvea/nipe
	sudo apt-get install cpanminus
	cpanm --installdeps . 
	sudo cpan install Switch JSON LWP::UserAgent Config::Simple
	sudo perl nipe.pl install
}

#list of nipe files/folders needed
nipe_files=(
nipe.pl
cpanfile
Dockerfile
lib
)

#count array length
nipe_files_num=${#nipe_files[@]}

#count current array line
count=0

#for loop check if all nipe files exist
for nipecheck in "${nipe_files[@]}"
do
	if test -e $nipecheck #check inside this folder if these files exist
		then
		count=$((count+1))
		echo -e "${G}$nipecheck is already installed${NC} [${count}/${nipe_files_num}]"
		sleep 1
		else #if any one don't exist, do full install nipe
		echo -e "${R}$nipecheck doesn't exist. ${NC}Proceeding to install Nipe. This may take awhile..."
		install_nipe
		echo -e "${G}Nipe has been installed.${NC}"
	fi
done
echo
sleep 1

###################################################################################################################

#[2a] Check if network connection is anonymous (Nipe service on) If service disabled, turn on.

echo "Checking if network connection is anonymous..."

nipe_status=$(sudo perl nipe.pl status | awk '{print$3}' | sed -n '2,2p') #nipe status false or true
nipe_ipa=$(sudo perl nipe.pl status | awk '{print$3}' | sed -n '3,3p') #user's external ip address (if nipe is off will be actual ip, if on is spoofed ip)
geoip_country=$(geoiplookup $nipe_ipa | awk '{print$(NF-0)}') #what country external ip address is located in (if nipe off is actual country, if on is foreign country)

if [[ $nipe_status == "false" ]] #if Nipe is off, start
	then
	echo -e "${R}Nipe service not started yet.${NC}"
	echo "Starting Nipe..."
	sudo perl nipe.pl start
	sleep 1
	if [[ $nipe_status == "false" ]] #if Nipe is still off, restart
		then
		echo -e "${R}Nipe service failed to start.${NC}"
		echo "Restarting Nipe..."
		sudo perl nipe.pl restart
		sleep 1
		#[2b] If unable to connect to Nipe, alert user, and exit script.
		if [[  $nipe_status == "false" ]]
			then
			echo -e "${R}Nipe service failed to restart.${NC}"
			echo "Cannot proceed. Closing program. To try again enter 'bash $(basename "$0")' "
			exit
		fi
	fi		
	else
	#[2c] If sucessfully connected to Nipe, display the spoofed IP and Country.
	echo -e "${G}Nipe service is on. ${NC} You are anonymous."
	echo "Spoofed IP address: $nipe_ipa"
	echo "Spoofed country: $geoip_country"
	echo
	sleep 1
fi

###################################################################################################################

#[2-1] User specify domain or IP address to scan, and username + password to login to server
echo "Connect to a remote server."
echo "Enter a Domain/IP address to scan:"
read server_input
echo "Enter a valid username to login:"
read server_user
echo "Enter the user's password:"
read user_pass
echo

###################################################################################################################

#[2-2] Connect to remote server using sshpass
#[2-3] Show remote server's info - uptime, ip address, country

echo "Connecting to remote server:"

#sshpass, server uptime
sshpass -p "$user_pass" ssh -o StrictHostKeyChecking=no ${server_user}@${server_input} 'echo "Uptime: $(uptime)"'

#sshpass, server ifconfig full info (save to txt file)
sshpass -p "$user_pass" ssh -o StrictHostKeyChecking=no ${server_user}@${server_input} 'ifconfig' > ${server_input}_ifconfig.txt

#sshpass, server ip address
sshp_ipa=$(cat ${server_input}_ifconfig.txt | grep broadcast | awk '{print$2}')
echo "IP address: $sshp_ipa"

#sshpass, server country
echo "Country: $(geoiplookup $sshp_ipa)"
echo
sleep 1

###################################################################################################################

#[3-1] Save remote server's Whois data to file, in local machine.

echo "Saving server's Whois info..."
#sshpass, server whois info (save to txt file)
sshpass -p "$user_pass" ssh -o StrictHostKeyChecking=no ${server_user}@${server_input} "whois ${sshp_ipa}" >  ${server_input}_whois.txt

#whois text file absolute file path location
who_locate=$(find "$(realpath ..)" -name ${server_input}_whois.txt)
echo "Whois data has been saved to $who_locate"

#[3-2] Save network data collection to log file. Include day, date, time, domain/ip that was scanned.
echo "$(date) - Whois data collected for: $server_input" >> /var/log/${0}.log
echo "Log records in /var/log/${0}.log has been updated."

###################################################################################################################
#SCRIPT NOT TESTED DO NOT USE
#extra content

#~ #[3-X] Save remote server's Nmap data to file, in local machine.

#~ echo "Saving server's Nmap info..."
#~ #sshpass, server nmap info (save to txt file)
#~ sshpass -p "$user_pass" ssh -o StrictHostKeyChecking=no ${server_user}@${server_input} "nmap -Pn ${sshp_ipa}" >  ${server_input}_nmap.txt

#~ #-sV, -O , --reason
#~ #-oN -oG -oX
#~ #xsltproc <xml file> -o <html filename>
#~ #open file.html

#~ #nmap text file absolute file path location
#~ nmap_locate=$(find "$(realpath ..)" -name ${server_input}_nmap.txt)
#~ echo "Nmap data has been saved to $nmap_locate"

#~ #[3-2b] Save network data collection to log file. Include day, date, time, domain/ip that was scanned.
#~ echo "$(date) - Nmap data collected for: $server_input" >> /var/log/${0}.log
#~ echo

###################################################################################################################

#END OF SCRIPT
