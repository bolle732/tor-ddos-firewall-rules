#!/bin/bash
# set -x

U_OR_4_PORTS="*:80 192.0.2.2:443 203.0.113.2:9001"
U_OR_6_PORTS="[::]:80 [2001:DB8::2]:443 [2001:DB8::3]:995"

G_TMP_PATH="/var/tmp"

G_TOR_REPRO="https://raw.githubusercontent.com/Enkidu-6/tor-relay-lists/main"
G_TOR_4_ALLOW_FILES="$G_TOR_REPRO/authorities-v4.txt $G_TOR_REPRO/snowflake.txt"
G_TOR_6_ALLOW_FILES="$G_TOR_REPRO/authorities-v6.txt $G_TOR_REPRO/snowflake-v6.txt"
G_TOR_4_OR_ALL_FILE="$G_TOR_REPRO/relays-v4.txt"
G_TOR_4_OR_DUAL_FILE="$G_TOR_REPRO/dual-or.txt"

G_POX_MODE=""

G_INFO="v1.0.4 - 20220111 - bolle@geodb.org"

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
	echo ""
	return
}

destroySets() {
	echo "### Destroying current iptable sets..."
	porx "sleep 1"
	porx "ipset destroy"
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

getTorAllowIPs() {
	local -n L_IP="$1"
	echo "### Getting IPs of Tor authorities and snowflakes..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-allow-list"
	downloadFiles "$2" "$f"
	echo ""
	return
}

createTorAllowList() {
	local -n L_IP="$1"
	echo "### Creating allow list for Tor authorities and snowflakes..."
	porx "ipset create -exist tor_${L_IP[v]}_is_allow hash:ip family ${L_IP[f]}"
	echo ""
	return
}

loadTorAllowList() {
	local -n L_IP="$1"
	echo "### Adding IPs of Tor authorities and snowflakes to allow list..."
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

flushTorAllowList()
{
	local -n L_IP="$1"
	echo "### Flushing allow list of Tor authorities and snowflakes..."
	porx "ipset flush tor_${L_IP[v]}_is_allow"
	echo ""
	return
}

setupTorDDoSRules()
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

getTorORsIPsAll()
{
	local -n L_IP="$1"
	echo "### Getting IPs of all Tor onion routers..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-all"
	downloadFiles "$2" "$f"
	echo ""
	return
}

getTorORsIPsDual()
{
	local -n L_IP="$1"
	echo "### Getting IPs of dual Tor onion routers..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-dual"
	downloadFiles "$2" "$f"
	echo ""
	return
}

unblockIPAddresses()
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

unblockTorORsAll()
{
	local -n L_IP="$1"
	echo "### Unblocking all Tor onion routers..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-all"
	unblockIPAddresses "${L_IP[v]}" "$f"
	echo ""
	return
}

unblockTorORsDual()
{
	local -n L_IP="$1"
	echo "### Unblocking dual Tor onion routers..."
	f="$G_TMP_PATH/tor-${L_IP[v]}-or-dual"
	unblockIPAddresses "${L_IP[v]}" "$f"
	echo ""
	return
}




# MAIN

printUsage()
{
	echo "Script usage:"
	echo " ./${0##*/} <ACTION> [OPTION]"
	echo ""
	echo "<ACTION> = 'setup':"
	echo " The action 'setup' will setup your system and install the"
	echo " firewall rules to defend the DDoS against your Tor relay."
	echo ""
	echo "<ACTION> = 'refresh':"
	echo " The action 'refresh' will update the firewall allow list with"
	echo " the new IP addresses of the Tor authorities and snowflakes."
	echo ""
	echo "<ACTION> = 'unblock-all':"
	echo " The action 'unblock-all' will remove all Tor relays from the"
	echo " firewall block lists."
	echo ""
	echo "<ACTION> = 'unblock-dual':"
	echo " The action 'unblock-dual' will remove only dual Tor relays from"
	echo " the firewall block lists."
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
"setup" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		backupRules G_IP4
		flushRules G_IP4
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		backupRules G_IP6
		flushRules G_IP6
	fi
	destroySets
	setupSystem
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getTorAllowIPs G_IP4 "$G_TOR_4_ALLOW_FILES"
		createTorAllowList G_IP4
		loadTorAllowList G_IP4
		setupTorDDoSRules G_IP4 "$U_OR_4_PORTS"
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		getTorAllowIPs G_IP6 "$G_TOR_6_ALLOW_FILES"
		createTorAllowList G_IP6
		loadTorAllowList G_IP6
		setupTorDDoSRules G_IP6 "$U_OR_6_PORTS"
	fi
;;
"refresh" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getTorAllowIPs G_IP4 "$G_TOR_4_ALLOW_FILES"
		flushTorAllowList G_IP4
		loadTorAllowList G_IP4
	fi
	if [[ -n "$U_OR_6_PORTS" ]]
	then
		getTorAllowIPs G_IP6 "$G_TOR_6_ALLOW_FILES"
		flushTorAllowList G_IP6
		loadTorAllowList G_IP6
	fi
;;
"unblock-all" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getTorORsIPsAll G_IP4 "$G_TOR_4_OR_ALL_FILE"
		unblockTorORsAll G_IP4 "$G_TOR_4_OR_ALL_FILE"
	fi
;;
"unblock-dual" )
	if [[ -n "$U_OR_4_PORTS" ]]
	then
		getTorORsIPsDual G_IP4 "$G_TOR_4_OR_DUAL_FILE"
		unblockTorORsDual G_IP4 "$G_TOR_4_OR_DUAL_FILE"
	fi
;;
* )
	echo "### NO KNOWN ACTION SPECIFIED"
	echo ""
	printUsage
esac
echo "### Action finished."
echo ""

exit 0
