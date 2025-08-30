#!/bin/bash
mem=$(free -m | awk '/Mem.:/ {printf("%.0f/%.0fMB (%.2f%%)", $3, $2, ($3/$2 * 100))}')
dsk=$(df -h --total | awk '/total/{print $3"/"$2" ("$5")"}')
cpu=$(mpstat 1 1 | awk '/Média/ {printf("%.2f%%", 100 - $NF)}')

message="###############################################################################
###_Architecture: $(uname -a)
###_CPU physical: $(lscpu | awk '/Soquete/ {print $2}')
###_vCPU: $(nproc --all)
###_Memory Usage: $mem
###_Disk Usage: $dsk
###_CPU load: $cpu 
###_Last boot: $(uptime -s)
###_LVM use: $(lsblk | grep lvm -q && echo "yes" || echo "no")
###_Connections TCP: $(ss -a | grep tcp | grep ESTAB | wc -l) ESTABLISHED
###_Users logged: $(uptime | grep -o '[0-9]\+ user' | awk '{print $1}')
###_Network: IP $(ip a | grep inet | awk 'NR == 3 {print $2}' | cut -d/ -f1) ($(ifconfig | awk '/ether/ {print $2}'))
###_Sudo: $(cat /var/log/sudo/sudo.log | grep COMMAND | wc -l) cmd
###############################################################################"

terminals="$(who | awk '/pts/{print $3}')"

for terminal in $terminals
do
	echo "$message" > /dev/$terminal
done

wall "$message"