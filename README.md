# tor-ddos-firewall-rules
Tor DDoS firewall rules script

This script is based on the script(s) of https://github.com/Enkidu-6/tor-ddos. It should create more or less same firewall rules. The names of the ipsets, recent lists and hash limits differs. Also the iptables parameter for the destination ports are unified.

After downloading the script, you must edit the variables `U_OR_4_PORTS` and `U_OR_6_PORTS` to reflect the IPs and ports used by your Tor relay.

If you don't have an IPv6 address, set the variable `U_OR_6_PORTS` to `""`.

If you don't want to specify the IP address, use the form of `*:9001` or `[::]:9001`.

The script currently knows two argument: `setup` or `refresh`. With `setup`, the firewall rules are installed. With `refresh`, the allow list will be refreshed with the new Tor authority and snowflake IPs.

Executing the script with only the parameters above will print the commands without executing them. To execute the commands, specify the second paramter `exec`.

`./tor_ddos_setup_firewall.sh setup` will print only the commands of setup.

`./tor_ddos_setup_firewall.sh setup exec` will execute the commands of setup.

`./tor_ddos_setup_firewall.sh refresh` will print only the commands of refresh.

`./tor_ddos_setup_firewall.sh refresh` will execute the commands of refresh.

Currently missing is a command for cleaning up the blocking ipsets.
