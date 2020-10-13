#!/bin/bash
# requires CAP_NET_ADMIN - run as sudo
# running on kernel version 4.15.0 from kernel.org

# Topology from -
# https://www.netdevconf.org/1.1/proceedings/slides/ahern-vrf-tutorial.pdf

# FIXME : setup correct path to supported iproute2

IP=ip

#IP=../../iproute2/ip/ip

function create_bridges
{
	for cust in `seq 1 2`; do
		for edge in `seq 1 2`; do
			${IP} link add br${cust}${edge} type bridge
			${IP} link set br${cust}${edge} up
		done
	done
}

function delete_bridges
{
	for cust in `seq 1 2`; do
		for edge in `seq 1 2`; do
			${IP} link del br${cust}${edge}
		done
	done
}

function _do_create_host
{
	# We are passed following parameters -

	cust=$1
	host=$2
	edge=$3

	echo "creating cust=${cust} host=${host} edge=${edge}"
	custhost=c${cust}h${host}
	custbr=br${cust}${edge}

	${IP} netns add ${custhost}

	

}

function create_hosts
{
	# first create host namespace
	# add host interfaces
	# assign addresses to them
	# connect to the respective bridge

	edge=1
	for cust in `seq 1 2`; do
		for host in `seq 1 2`; do
			_do_create_host ${cust} ${host} ${edge}
		done
	done

	edge=2
	for cust in `seq 1 2`; do
		for host in `seq 3 4`; do
			_do_create_host ${cust} ${host} ${edge}
		done
	done
}

function delete_hosts
{
	# it's suffice to delete their net namespaces
	for cust in `seq 1 2`; do
		for host in `seq 1 2`; do
			custhost=c${cust}h${host}
			${IP} netns del ${custhost}
		done
	done
}

function create_ce_routers
{
	for cust in `seq 1 2`; do
		for edge in `seq 1 2`; do
			custedge=c${cust}e${edge}
			custbr=br${cust}${edge}
			custhost=c${cust}h${edge}

			${IP} netns add ${custedge}
			ip netns add ${custhost}

			ip link add ${custedge}-eth type veth peer name ${custhost}-eth
			
			${IP} link set ${custhost}-eth netns ${custhost}
			${IP} link set ${custedge}-eth netns ${custedge}

			${IP} netns exec ${custhost} ${IP} link set lo up
			${IP} netns exec ${custhost} ${IP} link set ${custhost}-eth up
			${IP} netns exec ${custhost} ${IP} addr add 192.${edge}.1.${cust}/24 dev ${custhost}-eth

			${IP} netns exec ${custedge} ${IP} link set lo up
			${IP} netns exec ${custedge} ${IP} link set ${custedge}-eth up
			${IP} netns exec ${custedge} ${IP} addr add 192.${edge}.1.${cust}00/24 dev ${custedge}-eth


			${IP} netns exec ${custhost} ${IP} route add default via 192.${edge}.1.${cust}00 dev ${custhost}-eth



		done
	done
}

function delete_ce_routers
{
	# it's suffice to delete their net namespaces
	for cust in `seq 1 2`; do
		for edge in `seq 1 2`; do
			custedge=c${cust}e${edge}
			${IP} netns del ${custedge}
		done
	done
}

function _do_create_pe_router {

	cust=$1
	edge=$2

	custedge=c${cust}e${edge}
	pe=pe${edge}

	# add veth link
	${IP} link add ${custedge}-${pe}-eth type veth peer name ${pe}-${custedge}-eth

	# do ce side setting
	${IP} link set ${custedge}-${pe}-eth netns ${custedge}
	${IP} netns exec ${custedge} ${IP} link set ${custedge}-${pe}-eth up
	if [ ${edge} -eq 1 ]; then
		${IP} netns exec ${custedge} ${IP} addr add 10.${cust}.1.${cust}0/24 dev ${custedge}-${pe}-eth
	else
		${IP} netns exec ${custedge} ${IP} addr add 10.${cust}.2.${cust}0/24 dev ${custedge}-${pe}-eth
	fi


	# Now we can add to netns
	${IP} link set ${pe}-${custedge}-eth netns ${pe}
	${IP} netns exec ${pe} ${IP} link set ${pe}-${custedge}-eth up
	if [ ${edge} -eq 1 ]; then
		${IP} netns exec ${pe} ${IP} addr add 10.${cust}.1.${cust}/24 dev ${pe}-${custedge}-eth
	else
		${IP} netns exec ${pe} ${IP} addr add 10.${cust}.2.${cust}/24 dev ${pe}-${custedge}-eth
	fi


}

function create_pe_routers
{
	edge=1
	pe=pe${edge}

	${IP} netns add ${pe}
	${IP} netns exec ${pe} ${IP} link set lo up

	for cust in `seq 1 2`; do
		_do_create_pe_router ${cust} ${edge}
	done

	edge=2
	pe=pe${edge}

	${IP} netns add ${pe}
	${IP} netns exec ${pe} ${IP} link set lo up

	for cust in `seq 1 2`; do
		_do_create_pe_router ${cust} ${edge}
	done

}

function delete_pe_routers
{
	# delete PE namespaces
	for edge in `seq 1 2`; do
		${IP} netns del pe${edge}
	done

}

function create_p_routers
{
	# create netns
	${IP} netns add p

	# add links to pe1
	${IP} link add p-pe1-eth type veth peer name pe1-p-eth
	${IP} link set p-pe1-eth netns p
	${IP} netns exec p ${IP} link set p-pe1-eth up
	${IP} netns exec p ${IP} addr add 10.10.1.2/30 dev p-pe1-eth

	${IP} link set pe1-p-eth netns pe1
	${IP} netns exec pe1 ${IP} link set pe1-p-eth up
	${IP} netns exec pe1 ${IP} addr add 10.10.1.1/30 dev pe1-p-eth

	# add links to pe2
	${IP} link add p-pe2-eth type veth peer name pe2-p-eth
	${IP} link set p-pe2-eth netns p
	${IP} netns exec p ${IP} link set p-pe2-eth up
	${IP} netns exec p ${IP} addr add 10.10.1.5/30 dev p-pe2-eth

	${IP} link set pe2-p-eth netns pe2
	${IP} netns exec pe2 ${IP} link set pe2-p-eth up
	${IP} netns exec pe2 ${IP} addr add 10.10.1.6/30 dev pe2-p-eth
}

function delete_p_routers
{
	${IP} netns del p
}

function setup_mpls
{
	modprobe mpls_router

	${IP} netns exec p sysctl -w net.mpls.platform_labels=10000
	${IP} netns exec pe1 sysctl -w net.mpls.platform_labels=10000
	${IP} netns exec pe2 sysctl -w net.mpls.platform_labels=10000

	for edge in `seq 1 2`; do
		for cust in `seq 1 2`;do
			${IP} netns exec pe${edge} sysctl -w net.mpls.conf.pe${edge}-c${cust}e${edge}-eth.input=1
		done
		${IP} netns exec pe${edge} sysctl -w net.mpls.conf.pe${edge}-p-eth.input=1

		# for core
		${IP} netns exec p sysctl -w net.mpls.conf.p-pe${edge}-eth.input=1
	done
}

function setup_routing
{
	

	#Routing at customer edges
	${IP} netns exec c1e1 sysctl -w net.ipv4.ip_forward=1
	${IP} netns exec c1e1 ${IP} route add default via 10.1.1.1 dev c1e1-pe1-eth
	

	${IP} netns exec c2e1 sysctl -w net.ipv4.ip_forward=1
	${IP} netns exec c2e1 ${IP} route add default via 10.2.1.2 dev c2e1-pe1-eth


	${IP} netns exec c1e2 sysctl -w net.ipv4.ip_forward=1
	${IP} netns exec c1e2 ${IP} route add default via 10.1.2.1 dev c1e2-pe2-eth


	${IP} netns exec c2e2 sysctl -w net.ipv4.ip_forward=1
	${IP} netns exec c2e2 ${IP} route add default via 10.2.2.2 dev c2e2-pe2-eth





	#Routing at peer edges	
	${IP} netns exec pe1 sysctl -w net.ipv4.ip_forward=1
	
	${IP} netns exec pe1 ${IP} route add 192.2.1.0/24 encap mpls 101 via inet 10.10.1.2
	${IP} netns exec pe1 ${IP} route add 192.1.1.1 via 10.1.1.10
	${IP} netns exec pe1 ${IP} route add 192.1.1.2 via 10.2.1.20


	${IP} netns exec pe2 sysctl -w net.ipv4.ip_forward=1
	
	${IP} netns exec pe2 ${IP} route add 192.1.1.0/24 encap mpls 102 via inet 10.10.1.5
	${IP} netns exec pe2 ${IP} route add 192.2.1.1 via 10.1.2.10
	${IP} netns exec pe2 ${IP} route add 192.2.1.2 via 10.2.2.20




	# setup at p router
	${IP} netns exec p sysctl -w net.ipv4.ip_forward=1


	#PENULTIMATE HOP POPPING

	# to pe2
	
	${IP} netns exec p ${IP} -f mpls route add 101 via inet 10.10.1.6


	# to pe1
	
	${IP} netns exec p ${IP} -f mpls route add 102 via inet 10.10.1.1


	# pop label at pe routers
	# pe1 pop mpls label

	${IP} netns exec pe1 ip link set lo up
	${IP} netns exec pe2 ip link set lo up
	${IP} netns exec pe1 ip addr add 11.0.3.1/24 dev lo
	${IP} netns exec pe2 ip addr add 11.0.3.1/24 dev lo
	
	#${IP} netns exec pe1 ${IP} -f mpls route add 112 via inet 10.1.1.10 dev pe1-c1e1-eth
	#${IP} netns exec pe1 ${IP} -f mpls route add 112 via inet 11.0.3.1 #dev lo
	#${IP} netns exec pe1 ${IP} -f mpls route add 212 via inet 1.1.1.1 dev vrf-pe1-c2

	# pe2 pop mpls label
	#${IP} netns exec pe2 ${IP} -f mpls route add 111 via inet 3.1.1.10 dev pe2-c1e2-eth
	#${IP} netns exec pe2 ${IP} -f mpls route add 111 via inet 11.0.3.1 #dev lo
	#${IP} netns exec pe2 ${IP} -f mpls route add 211 via inet 3.1.1.1 dev vrf-pe2-c2

}
