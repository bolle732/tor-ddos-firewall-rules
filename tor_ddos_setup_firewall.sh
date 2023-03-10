#!/bin/bash
# set -x

U_OR_4_PORTS="*:80 192.0.2.2:443 203.0.113.2:9001"
U_OR_6_PORTS="[::]:80 [2001:DB8::2]:443 [2001:DB8::3]:995"

G_TMP_PATH="/var/tmp"

G_TOR_REPRO="https://raw.githubusercontent.com/Enkidu-6/tor-relay-lists/main"
G_TOR_4_ALLOW_FILES="$G_TOR_REPRO/authorities-v4.txt $G_TOR_REPRO/snowflake.txt"
G_TOR_6_ALLOW_FILES="$G_TOR_REPRO/authorities-v6.txt $G_TOR_REPRO/snowflake-v6.txt"
G_TOR_4_OR_DUAL_FILE="$G_TOR_REPRO/2-or.txt"
G_TOR_6_OR_DUAL_FILE="$G_TOR_REPRO/2-or-v6.txt"
G_TOR_4_OR_QUAD_FILE="$G_TOR_REPRO/above2-or.txt"
G_TOR_6_OR_QUAD_FILE="$G_TOR_REPRO/above2-or-v6.txt"

G_POX_MODE=""

G_INFO="v1.5.3 - 20230220 - bolle@geodb.org"

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
		return $?
	;;
	esac
	return
}

setupSystem()
{
	echo "### Setting up system configuration and modules..."
	porx "sysctl net.ipv4.ip_local_port_range=\"1025 65000\""
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

flushRules() {
	local -n L_IP="$1"
	echo "### Flushing current iptable rules..."
	porx "${L_IP[b]} -t mangle -F"
	porx "sleep 1"
	echo ""
	return
}

destroySets() {
	local -n L_IP="$1"
	echo "### Destroying current iptable sets..."
	L_SETS=$(ipset -L -n)
	for i in $L_SETS
	do
		if [[ $i =~ "tor_${L_IP[v]}_is_".* ]]
		then
			echo "### Processing ipset $i"
			porx "ipset destroy $i"
		fi
	done
	echo ""
	return
}

downloadFiles()
{
	echo "### Downloading files '$1' to '$2'"
	if [[ -e "$2" ]] && [[ -z $(find "$2" -mmin +60) ]]
	then
		return
	fi
	t="$f.tmp"
	porx "truncate -s 0 $t"
	for i in $1
	do
		porx "curl -s '$i' | sed -e '1,3d' >> $t"
		if [[ $? -gt 0 ]]
		then
			echo "### WARNING: Download '$i' has failed!"
			echo ""
			return
		fi
	done
	porx "mv $t $2"
	return
}

getIPsTorAllow() {
	local -n L_IP="$1"
	echo "### Getting IPs of Tor authorities and snowflakes..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-allow-list"
	downloadFiles "$2" "$f"
	echo ""
	return
}

getIPsTorORsDual()
{
	local -n L_IP="$1"
	echo "### Getting IPs of Tor onion routers running 2 instances..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-dual"
	downloadFiles "$2" "$f"
	echo ""
	return
}

getIPsTorORsQuad()
{
	local -n L_IP="$1"
	echo "### Getting IPs of Tor onion routers running more then 2 instances..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-quad"
	downloadFiles "$2" "$f"
	echo ""
	return
}

createListTorAllow() {
	local -n L_IP="$1"
	echo "### Creating allow list for Tor authorities and snowflakes..."
	porx "ipset create -exist tor_${L_IP[v]}_is_allow hash:ip family ${L_IP[f]}"
	echo ""
	return
}

createListTorORsDual() {
	local -n L_IP="$1"
	echo "### Creating allow list for Tor onion routers running 2 instances..."
	porx "ipset create -exist tor_${L_IP[v]}_is_dual hash:ip family ${L_IP[f]}"
	echo ""
	return
}

createListTorORsQuad() {
	local -n L_IP="$1"
	echo "### Creating allow list for Tor onion routers running more then 2 instances..."
	porx "ipset create -exist tor_${L_IP[v]}_is_quad hash:ip family ${L_IP[f]}"
	echo ""
	return
}

loadListTorAllow() {
	local -n L_IP="$1"
	echo "### Loading allow list with IPs of Tor authorities and snowflakes..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-allow-list"
	if [[ ! -f "$f" ]]
	then
		echo "### WARNING: File '$f' does not exist!"
		echo ""
		return
	fi
	for i in $(cat $f)
	do
		porx "ipset add -exist tor_${L_IP[v]}_is_allow $i"
	done
	echo ""
	return
}

loadListTorORsDual() {
	local -n L_IP="$1"
	echo "### Loading allow list with IPs of Tor onion routers running 2 instances..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-dual"
	if [[ ! -f "$f" ]]
	then
		echo "### WARNING: File '$f' does not exist!"
		echo ""
		return
	fi
	for i in $(cat $f)
	do
		porx "ipset add -exist tor_${L_IP[v]}_is_dual $i"
	done
	echo ""
	return
}

loadListTorORsQuad() {
	local -n L_IP="$1"
	echo "### Loading allow list with IPs of Tor onion routers running more then 2 instances..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-quad"
	if [[ ! -f "$f" ]]
	then
		echo "### WARNING: File '$f' does not exist!"
		echo ""
		return
	fi
	for i in $(cat $f)
	do
		porx "ipset add -exist tor_${L_IP[v]}_is_quad $i"
	done
	echo ""
	return
}

flushListTorAllow()
{
	local -n L_IP="$1"
	echo "### Flushing allow list of Tor authorities and snowflakes..."
	porx "ipset flush tor_${L_IP[v]}_is_allow"
	echo ""
	return
}

flushListTorORsDual()
{
	local -n L_IP="$1"
	echo "### Flushing allow list of Tor onion routers running 2 instances..."
	porx "ipset flush tor_${L_IP[v]}_is_dual"
	echo ""
	return
}

flushListTorORsQuad()
{
	local -n L_IP="$1"
	echo "### Flushing allow list of Tor onion routers running more then 2 instances..."
	porx "ipset flush tor_${L_IP[v]}_is_quad"
	echo ""
	return
}

setupRulesTorDDoS()
{
	local -n L_IP="$1"
	echo "### Setting up firewall rules against Tor DDoS..."
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
		o1="-t mangle -I PREROUTING -p tcp"
		o2="-t mangle -A PREROUTING -p tcp"
		porx "ipset create -exist $s1 hash:ip family ${L_IP[f]} hashsize 4096 timeout 43200"
		porx "${L_IP[b]} $o1 $d -m set --match-set tor_${L_IP[v]}_is_allow src -j ACCEPT"
		porx "${L_IP[b]} $o2 $d -m recent --name $s2 --set"
		porx "${L_IP[b]} $o2 $d -m set --match-set tor_${L_IP[v]}_is_quad src -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-upto 4 -j ACCEPT"
		porx "${L_IP[b]} $o2 $d -m set --match-set tor_${L_IP[v]}_is_dual src -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-upto 2 -j ACCEPT"
		porx "${L_IP[b]} $o2 --syn $d -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-above 2 -j SET --add-set $s1 src"
		porx "${L_IP[b]} $o2 $d -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-above 2 -j SET --add-set $s1 src"
		porx "${L_IP[b]} $o2 $d -m set --match-set $s1 src -j DROP"
		porx "${L_IP[b]} $o2 $d -m connlimit --connlimit-mask ${L_IP[m]} --connlimit-above 1 -j DROP"
		porx "${L_IP[b]} $o2 $d -j ACCEPT"
		echo ""
	done
	return
}

unblockIPs()
{
	echo "### Processing file '$2'"
	if [[ ! -f "$2" ]]
	then
		echo "### WARNING: File '$f' does not exist!"
		echo ""
		return
	fi
	L_RIPS=$(cat $2)
	L_SETS=$(ipset -L -n)
	for i in $L_SETS
	do
		if [[ $i =~ "tor_${1}_is_".*"_".* ]]
		then
			echo "### Processing ipset $i"
			for a in $(ipset -L $i | cut -d' ' -f1,2 | grep timeout | cut -d' ' -f1)
			do
				if [[ $L_RIPS =~ $a ]]
				then
					echo "### Unblocking IP address $a"
					porx "ipset del $i $a"
				fi
			done
		fi
	done
	return
}

unblockIPsTorORsDual()
{
	local -n L_IP="$1"
	echo "### Unblocking IPs of Tor onion routers running 2 instances..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-dual"
	unblockIPs "${L_IP[v]}" "$f"
	echo ""
	return
}

unblockIPsTorORsQuad()
{
	local -n L_IP="$1"
	echo "### Unblocking IPs of Tor onion routers running more then 2 instances..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-quad"
	unblockIPs "${L_IP[v]}" "$f"
	echo ""
	return
}

printConfig()
{
	echo "Script configuration:"
	echo ""
	echo "User variable   : 'U_OR_4_PORTS'"
	echo "Current value   : '$U_OR_4_PORTS'"
	echo ""
	echo " Space seperated list of local IPv4 address / OR port combinations"
	echo " of the Tor relays to be protected with this script."
	echo ""
	echo " This variable MUST not be empty!"
	echo ""
	echo " Examples:"
	echo " U_OR_4_PORTS=\"*:80 192.0.2.2:443 203.0.113.2:9001\""
	echo ""
	echo ""
	echo "User variable   : 'U_OR_6_PORTS'"
	echo "Current value   : '$U_OR_6_PORTS'"
	echo ""
	echo " Space seperated list of local IPv6 address / OR port combinations"
	echo " of the Tor relays to be protected with this script."
	echo ""
	echo " Set this variable to an empty string if not using IPv6."
	echo ""
	echo " Examples:"
	echo " U_OR_6_PORTS=\"[::]:80 [2001:DB8::2]:443 [2001:DB8::3]:995\""
	echo ""
	echo ""
	echo "Global variable : 'G_TMP_PATH'"
	echo "Current value   : '$G_TMP_PATH'"
	echo ""
	echo " The path to a folder where this script can store its files."
	echo ""
	echo " Default:"
	echo " G_TMP_PATH=\"/var/tmp\""
	echo ""
	echo ""
	echo "Other global variables:"
	echo " 'G_TOR_REPRO'          : '$G_TOR_REPRO'"
	echo " 'G_TOR_4_ALLOW_FILES'  : '$G_TOR_4_ALLOW_FILES'"
	echo " 'G_TOR_6_ALLOW_FILES'  : '$G_TOR_6_ALLOW_FILES'"
	echo " 'G_TOR_4_OR_DUAL_FILE' : '$G_TOR_4_OR_DUAL_FILE'"
	echo " 'G_TOR_6_OR_DUAL_FILE' : '$G_TOR_6_OR_DUAL_FILE'"
	echo " 'G_TOR_4_OR_QUAD_FILE' : '$G_TOR_4_OR_QUAD_FILE'"
	echo " 'G_TOR_6_OR_QUAD_FILE' : '$G_TOR_6_OR_QUAD_FILE'"
	echo ""
}

printUsage()
{
	echo "Script usage:"
	echo " ./${0##*/} <ACTION> [OPTION]"
	echo ""
	echo "<ACTION> = 'config':"
	echo " The action 'config' will print the user paramter of this"
	echo " script."
	echo ""
	echo "<ACTION> = 'setup':"
	echo " The action 'setup' will setup your system and install the"
	echo " firewall rules to defend the DDoS against your Tor relay."
	echo ""
	echo "<ACTION> = 'refresh':"
	echo " The action 'refresh' will update the firewall allow list with"
	echo " the new IP addresses of the Tor authorities and snowflakes."
	echo ""
	echo "<ACTION> = 'unblock-dual':"
	echo " The action 'unblock-dual' will remove Tor relays with 2 instances"
	echo " from the firewall block lists."
	echo ""
	echo "<ACTION> = 'unblock-quad':"
	echo " The action 'unblock-quad' will remove Tor relays with more then"
	echo " 2 instances (up to 4) from the firewall block lists."
	echo ""
	echo "<ACTION> = '*':"
	echo " Specifying an empty or a unknown action will print this usage."
	echo ""
	echo "[OPTION] = 'exec':"
	echo " By default, the script will not execute the commands. Instead,"
	echo " it will print them to the console. Please do a careful review"
	echo " the output it produces."
	echo " You must specify the option 'exec' after the action as a second"
	echo " argument to to really execute the commands."
	echo ""
	echo "[OPTION] = '*':"
	echo " With an empty or unknown option, the script will only print"
	echo " the commands without executing them."
	echo ""
}


# MAIN

echo "### Tor DDoS setup firewall script: $G_INFO"
echo ""

echo "### Action is '$1'"
case "$2" in
"exec" )
	G_POX_MODE="exec"
;;
* )
	G_POX_MODE="test"
esac
echo "### Mode is '$G_POX_MODE'"
echo ""

case "$1" in
"config" )
	printConfig
;;
"setup" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		backupRules G_IP4
		flushRules G_IP4
		destroySets G_IP4
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		backupRules G_IP6
		flushRules G_IP6
		destroySets G_IP6
	fi
	setupSystem
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getIPsTorAllow G_IP4 "$G_TOR_4_ALLOW_FILES"
		createListTorAllow G_IP4
		loadListTorAllow G_IP4
		getIPsTorORsDual G_IP4 "$G_TOR_4_OR_DUAL_FILE"
		createListTorORsDual G_IP4
		loadListTorORsDual G_IP4
		getIPsTorORsQuad G_IP4 "$G_TOR_4_OR_QUAD_FILE"
		createListTorORsQuad G_IP4
		loadListTorORsQuad G_IP4
		setupRulesTorDDoS G_IP4 "$U_OR_4_PORTS"
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		getIPsTorAllow G_IP6 "$G_TOR_6_ALLOW_FILES"
		createListTorAllow G_IP6
		loadListTorAllow G_IP6
		getIPsTorORsDual G_IP6 "$G_TOR_6_OR_DUAL_FILE"
		createListTorORsDual G_IP6
		loadListTorORsDual G_IP6
		getIPsTorORsQuad G_IP6 "$G_TOR_6_OR_QUAD_FILE"
		createListTorORsQuad G_IP6
		loadListTorORsQuad G_IP6
		setupRulesTorDDoS G_IP6 "$U_OR_6_PORTS"
	fi
;;
"refresh" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getIPsTorAllow G_IP4 "$G_TOR_4_ALLOW_FILES"
		flushListTorAllow G_IP4
		loadListTorAllow G_IP4
		getIPsTorORsDual G_IP4 "$G_TOR_4_OR_DUAL_FILE"
		flushListTorORsDual G_IP4
		loadListTorORsDual G_IP4
		getIPsTorORsQuad G_IP4 "$G_TOR_4_OR_QUAD_FILE"
		flushListTorORsQuad G_IP4
		loadListTorORsQuad G_IP4
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		getIPsTorAllow G_IP6 "$G_TOR_6_ALLOW_FILES"
		flushListTorAllow G_IP6
		loadListTorAllow G_IP6
		getIPsTorORsDual G_IP6 "$G_TOR_6_OR_DUAL_FILE"
		flushListTorORsDual G_IP6
		loadListTorORsDual G_IP6
		getIPsTorORsQuad G_IP6 "$G_TOR_6_OR_QUAD_FILE"
		flushListTorORsQuad G_IP6
		loadListTorORsQuad G_IP6
	fi
;;
"unblock-dual" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getIPsTorORsDual G_IP4 "$G_TOR_4_OR_DUAL_FILE"
		unblockIPsTorORsDual G_IP4 "$G_TOR_4_OR_DUAL_FILE"
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		getIPsTorORsDual G_IP6 "$G_TOR_6_OR_DUAL_FILE"
		unblockIPsTorORsDual G_IP6 "$G_TOR_6_OR_DUAL_FILE"
	fi
;;
"unblock-quad" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getIPsTorORsQuad G_IP4 "$G_TOR_4_OR_QUAD_FILE"
		unblockIPsTorORsQuad G_IP4 "$G_TOR_4_OR_QUAD_FILE"
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		getIPsTorORsQuad G_IP6 "$G_TOR_6_OR_QUAD_FILE"
		unblockIPsTorORsQuad G_IP6 "$G_TOR_6_OR_QUAD_FILE"
	fi
;;
* )
	echo "### NONE OR UNKNOWN ACTION SPECIFIED"
	echo ""
	printUsage
esac
echo "### Action finished."
echo ""

exit 0
