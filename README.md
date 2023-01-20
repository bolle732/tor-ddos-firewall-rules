# Tor DDoS firewall rules

## Preface

This script is based on the script(s) of https://github.com/Enkidu-6/tor-ddos. You can find there more information. This script should create more or less the same firewall rules. Also the names of the ipsets and recent lists differs. Also the iptables parameter for the destination ports are unified.

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
- Use `setup` to install the firewall rules.
- Use `refresh` to refresh the allow list with the new Tor authority and snowflake IPs.
- Use `unblock-all` to remove all Tor relays from the block list.
- Use `unblock-dual` to remove only Tor relays with dual IPs from the block list.

Starting the script without an option as the second argument will only print the commands to the console without executing them. To really execute the commands, you must specify the option `exec`.

## Examples

`./tor_ddos_setup_firewall.sh config` will print the script configuration.

`./tor_ddos_setup_firewall.sh setup` will print only the commands of setup.

`./tor_ddos_setup_firewall.sh setup exec` will execute the commands of setup.

`./tor_ddos_setup_firewall.sh refresh` will print only the commands of refresh.

`./tor_ddos_setup_firewall.sh refresh exec` will execute the commands of refresh.

`./tor_ddos_setup_firewall.sh unblock-all` will print only the commands of unblocking all Tor relays.

`./tor_ddos_setup_firewall.sh unblock-all exec` will execute the commands of unblocking all Tor relays.

`./tor_ddos_setup_firewall.sh unblock-dual` will print only the commands of unblocking dual Tor relays.

`./tor_ddos_setup_firewall.sh unblock-dual exec` will execute the commands of unblocking dual Tor relays.

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
