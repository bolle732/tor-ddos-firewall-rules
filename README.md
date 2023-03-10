# Tor DDoS firewall rules

## Preface

This script is based on the script(s) of https://github.com/Enkidu-6/tor-ddos. You can find there more information. This script should create more or less the same firewall rules. But the names of the ipsets and recent lists differs. Also the iptables parameter for the destination ports are unified.

## Basic

To run the script you must have installed BASH. The script uses a lot of BASHs built-in array and string handling functionality.

After downloading the script, you must edit the variables `U_OR_4_PORTS` and `U_OR_6_PORTS` to reflect the IPs and ports used by your Tor relay.

If you don't have an IPv6 address, set the variable `U_OR_6_PORTS` to an empty string (`""`).

If you don't want to specify an IP address, use the form of `*:9001` (IPv4) or `[::]:9001` (IPv6).

## Execution

The script is executed in this form:

`./tor_ddos_setup_firewall.sh <ACTION> [OPTION]`

The script currently knows five actions specified by the first argument:

- Use `config` to print the script variables to the console.
- Use `setup` to setup system and install the firewall rules.
- Use `refresh` to update the allow ipsets with the current Tor authorities, snowflakes and Tor relays with dual IPs.
- Use `unblock-dual` to remove Tor relays with 2 instances from the block ipset.
- Use `unblock-quad` to remove Tor relays with more then 2 instances from the block ipset.

Starting the script without an option as the second argument will only print the commands to the console without executing them. To really execute the commands, you must specify the option `exec`.

## Examples

`./tor_ddos_setup_firewall.sh config` will print the script configuration.

`./tor_ddos_setup_firewall.sh setup` will print only the commands of setup.

`./tor_ddos_setup_firewall.sh setup exec` will execute the commands of setup.

`./tor_ddos_setup_firewall.sh refresh` will print only the commands of refresh.

`./tor_ddos_setup_firewall.sh refresh exec` will execute the commands of refresh.

`./tor_ddos_setup_firewall.sh unblock-dual` will print only the commands of unblocking Tor relays with 2 instances.

`./tor_ddos_setup_firewall.sh unblock-dual exec` will execute the commands of unblocking Tor relays with 2 instances.

`./tor_ddos_setup_firewall.sh unblock-quad` will print only the commands of unblocking Tor relays with more then 2 instances.

`./tor_ddos_setup_firewall.sh unblock-quad exec` will execute the commands of unblocking Tor relays with more then 2 instances.

## Installation
You must install the script by hand.

- Edit the user variables to reflect your configuration

- Copy the configured script to the system folder
```
cp tor_ddos_setup_firewall.sh /usr/local/bin/
```
- Set up the file permissions
```
chmod 755 /usr/local/bin/tor_ddos_setup_firewall.sh
chown root: /usr/local/bin/tor_ddos_setup_firewall.sh
```

## SystemD integration
You can use SystemD to execute the script during startup.

- Create companion folder for SystemD network daemon
```
mkdir /etc/systemd/system/systemd-networkd.service.d
```

- Create a configuration file that will be executed after network startup
```
vi /etc/systemd/system/systemd-networkd.service.d/tor-ddos-setup-firewall.conf
```
with this content
```
[Service]
ExecStartPost=/usr/local/bin/tor_ddos_setup_firewall.sh setup exec
```

- Reload SystemD configuration
```
systemctl daemon-reload
```

## Refresh Tor allow IPs
You should regulary refresh the IP addresses of the Tor authorities and snowflakes.

- Edit your Cron configuration file
```
crontab -e
```
and add this line
```
0 18 * * * /usr/local/bin/tor_ddos_setup_firewall.sh refresh exec
```
