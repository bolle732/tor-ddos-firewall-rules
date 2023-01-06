#!/bin/bash
# set -x

U_OR_4_PORTS="192.0.2.1:443 203.0.113.1:9001"
U_OR_6_PORTS="[2001:DB8::1]:995 [2001:DB8::2]:80"

G_TMP_PATH="/var/tmp"

G_TOR_REPRO="https://raw.githubusercontent.com/Enkidu-6/tor-relay-lists/main"
G_TOR_4_FILES="$G_TOR_REPRO/authorities-v4.txt $G_TOR_REPRO/snowflake.txt"
G_TOR_6_FILES="$G_TOR_REPRO/authorities-v6.txt $G_TOR_REPRO/snowflake-v6.txt"

G_POX_MODE=""

declare -A G_IP4=(
	[b]="iptables" [f]="inet" [m]="32" [v]="4"
)

declare -A G_IP6=(
	[b]="ip6tables" [f]="inet6" [m]="128" [v]="6"
)

porx()
{
	case "$G_POX_MODE" in
	"test" )
		echo "$1"
	;;
	"exec" )
		eval "$1"
	;;
	esac
	return
}

setupSystem()
{
	echo "### Setting up system configuration and modules..."
	# GH: sysctl net.ipv4.ip_local_port_range="1025 65000"
	porx "echo 20 > /proc/sys/net/ipv4/tcp_fin_timeout"
	porx "modprobe xt_recent ip_list_tot=10000"
	echo ""
	return
}

backupRules() {
	local -n L_IP="$1"
	echo "### Backing up current iptable rules..."
	porx "${L_IP[b]}-save > $G_TMP_PATH/tor-${L_IP[v]}-rules-backup"
	echo ""
	return
}

cleanupRules() {
	local -n L_IP="$1"
	echo "### Cleaning up current iptable rules..."
	porx "${L_IP[b]} -t mangle -F"
	echo ""
	return
}

cleanupSets() {
	echo "### Cleaning up current iptable sets..."
	porx "sleep 1"
	porx "ipset destroy"
	echo ""
	return
}

downloadTorAllowFiles() {
	local -n L_IP="$1"
	echo "### Downloading Tor authorities and snowflakes allow files..."
	t=$G_TMP_PATH/tor-${L_IP[v]}-allow-list
	porx "truncate -s 0 $t"
	for i in $2
	do
		echo "##  Getting file '"$i"'..."
		porx "curl -s '$i' | sed -e '1,3d' >> $t"
	done
	echo ""
	return
}

createTorAllowList() {
	local -n L_IP="$1"
	echo "### Creating Tor authorities and snowflakes allow list..."
	porx "ipset create -exist tor_${L_IP[v]}_is_allow hash:ip family ${L_IP[f]}"
	echo ""
	return
}

loadTorAllowList() {
	local -n L_IP="$1"
	echo "### Loading Tor authorities and snowflakes allow list..."
	for i in `cat $G_TMP_PATH/tor-${L_IP[v]}-allow-list`
	do
		porx "ipset add -exist tor_${L_IP[v]}_is_allow $i"
	done
	echo ""
	return
}

flushTorAllowList()
{
	local -n L_IP="$1"
	echo "### Flushing Tor authorities and snowflakes allow list..."
	porx "ipset flush tor_${L_IP[v]}_is_allow"
	echo ""
	return
}

setupTorDDoSRules()
{
	local -n L_IP="$1"
	echo "### Setting up Tor DDoS firewall rules..."
	for i in $2
	do
		echo "##  Processing OR port list element '"$i"'..."
		a=$i ; a=${a%:*} ; a=${a/[/} ; a=${a/]/}
		p=${i##*:}
		if [[ ${#a} -gt 6 ]]
		then
			d="--destination $a --dport $p"
			n=$a ; n=${n//./-} ; n=${n//:/-} ; n="${n:${#n}<15?0:-15}"
		else
			d="--dport $p"
			n="any"
		fi
		s1="tor_${L_IP[v]}_is_${n}_${p}"
		s2="tor_${L_IP[v]}_rt_${n}_${p}"
		s3="tor_${L_IP[v]}_hl_${n}_${p}"
		o1="-t mangle -I PREROUTING -p tcp"
		o2="-t mangle -A PREROUTING -p tcp"
		porx "ipset create -exist $s1 hash:ip family ${L_IP[f]} hashsize 4096 timeout 43200"
		porx "${L_IP[b]} $o1 $d -m set --match-set tor_${L_IP[v]}_is_allow src -j ACCEPT"
		porx "${L_IP[b]} $o2 $d -m recent --name $s2 --set"
		porx "${L_IP[b]} $o2 $d -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-above 2 -j SET --add-set $s1 src"
		porx "${L_IP[b]} $o2 $d -m set --match-set $s1 src -j DROP"
		porx "${L_IP[b]} $o2 --syn $d -m hashlimit --hashlimit-name $s3 --hashlimit-mode srcip --hashlimit-srcmask 32 --hashlimit-above 30/hour --hashlimit-burst 4 --hashlimit-htable-expire 120000 -j DROP"
		porx "${L_IP[b]} $o2 --syn $d -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-above 2 -j DROP"
		porx "${L_IP[b]} $o2 $d -j ACCEPT"
		echo ""
	done
	return
}




# MAIN

case "$2" in
"exec" )
	G_POX_MODE="exec"
;;
* )
	G_POX_MODE="test"
esac
echo "### Mode is $G_POX_MODE"
echo ""

case "$1" in
"setup" )
	if [[ ! -z "$U_OR_4_PORTS" ]]
	then
		backupRules G_IP4
		cleanupRules G_IP4
	fi
	if [[ ! -z "$U_OR_6_PORTS" ]]
	then
		backupRules G_IP6
		cleanupRules G_IP6
	fi
	cleanupSets
	setupSystem
	if [[ ! -z "$U_OR_4_PORTS" ]]
	then
		downloadTorAllowFiles G_IP4 "$G_TOR_4_FILES"
		createTorAllowList G_IP4
		loadTorAllowList G_IP4
		setupTorDDoSRules G_IP4 "$U_OR_4_PORTS"
	fi
	if [[ ! -z "$U_OR_6_PORTS" ]]
	then
		downloadTorAllowFiles G_IP6 "$G_TOR_6_FILES"
		createTorAllowList G_IP6
		loadTorAllowList G_IP6
		setupTorDDoSRules G_IP6 "$U_OR_6_PORTS"
	fi
;;
"refresh" )
	if [[ ! -z "$U_OR_4_PORTS" ]]
	then
		downloadTorAllowFiles G_IP4 "$G_TOR_4_FILES"
		flushTorAllowList G_IP4
		loadTorAllowList G_IP4
	fi
	if [[ ! -z "$U_OR_6_PORTS" ]]
	then
		downloadTorAllowFiles G_IP6 "$G_TOR_6_FILES"
		flushTorAllowList G_IP6
		loadTorAllowList G_IP6
	fi
;;
* )
	echo "### NO OPTION SPECIFIED"
	exit 1
esac
echo "### Action finished."
echo ""

exit 0

