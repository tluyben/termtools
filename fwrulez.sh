#!/bin/sh
set -e

## SEE https://medium.com/@ebuschini/iptables-and-docker-95e2496f0b45

## You need to add rules in DOCKER-BLOCK AND INPUT for traffic that does not go to a container.
## You only need to add one rule if the traffic goes to the container

CWD=$(cd "$(dirname "${0}")"; pwd -P)
FILE="${CWD}/$(basename "${0}")"
chown root:root "${FILE}"
chmod o-rwx "${FILE}" 

set -x

install_docker_block() {
	## One time install rules for the DOCKER-BLOCK chain
	/sbin/iptables -t nat -N DOCKER-BLOCK &&
	## Deploy the new rules. After this, everything goes to DOCKER-BLOCK then to RETURN
	/sbin/iptables -t nat -I PREROUTING -m addrtype --dst-type LOCAL -g DOCKER-BLOCK ||
	true
}

## install the PREROUTING rules for the DOCKER chain in case docker starts after
/sbin/iptables -t nat -N DOCKER || true

## Block new connections while we restore the first PREROUTING RULES
/sbin/iptables -t nat -I PREROUTING -m addrtype --dst-type LOCAL -m state --state NEW -j RETURN

install_docker_block

## Delete installed rules, we need to ensure they always are at the top
## If rules were already installed, it would mean that the second and third rule
## are going to be deleted. We still have the RETURN on top.
while true; do
  /sbin/iptables -t nat -D PREROUTING -m addrtype --dst-type LOCAL -j RETURN || break
done
while true; do
  /sbin/iptables -t nat -D PREROUTING -m addrtype --dst-type LOCAL -j DOCKER-BLOCK || break
done

## Re-deploy the right rules on the top. After this, the flow is restored to DOCKER-BLOCK
/sbin/iptables -t nat -I PREROUTING -m addrtype --dst-type LOCAL -g DOCKER-BLOCK

## Remove the blocking rule, which should be unreachable after deploy_docker_block anyway
while true; do
  /sbin/iptables -t nat -D PREROUTING -m addrtype --dst-type LOCAL -m state --state NEW -j RETURN || break
done

## Only let established connections go through while we flush the rules
/sbin/iptables -t nat -I PREROUTING -m addrtype --dst-type LOCAL -m state --state ESTABLISHED -j DOCKER

## Flush the rules of DOCKER-BLOCK, at this point new connections will be blocked
/sbin/iptables -t nat -F DOCKER-BLOCK

## Add your new rules below, allowing new connections
## Don't forget the NEW and ESTABLISHED states
#/sbin/iptables -t nat -A DOCKER-BLOCK -p tcp -m tcp --dport 8080 -m state --state NEW,ESTABLISHED -j DOCKER


## Restore the flow
## Loop trying to delete the rule in case the script failed above, we don't want to add more than one rule
while true; do
  /sbin/iptables -t nat -D PREROUTING -m addrtype --dst-type LOCAL -m state --state ESTABLISHED -j DOCKER || break
done

## The INPUT chain is set to drop, then we flush it and reinstall the rules.
## Finally we restore the policy on the chain
## Remember that those rules don't apply to docker
/sbin/iptables -t filter -P INPUT DROP
/sbin/iptables -t filter -F INPUT
/sbin/iptables -t filter -A INPUT -i lo -j ACCEPT
# Add your non docker rules here
/sbin/iptables -t filter -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
/sbin/iptables -A INPUT -p udp -m multiport --dports 60000:61000 -j ACCEPT

/sbin/iptables -t filter -A INPUT -m state --state ESTABLISHED -j ACCEPT
/sbin/iptables -t filter -A INPUT -j DROP
/sbin/iptables -t filter -P INPUT ACCEPT

