# Experiments

Here a bunch of shell scripts, that run some experiments on Linux kernel.

# VRF with MPLS
	Scripts to setup the demo -
   - This directory consists of setup scripts for vrf-with-mpls from [netdev 1.1 tutorial](https://www.netdevconf.org/1.1/proceedings/slides/ahern-vrf-tutorial.pdf)
   - I have tested it with 4.15.0 kernel - uses L3mdev support, so any kernel with that support (and corresponding iproute2) should work

# OAI OAISIM ENB and EPC on Same Node
	Scripts and configurations to setup OAISIM eNB and EPC on the same node.


# Bandwidth Issues
https://docs.google.com/drawings/d/1K2RyOgtIZNjxbYtAmKeJgK5jXtc4MtxFSidyiJgfQpA/edit?usp=sharing
This is the Link to the diagram of the setup
You have to run the vrf-setup.sh and this pings c1h1 from c1h1.(See diagram)

bash vrf-setup.sh

Now you can run iperf as to check the bandwidth between c1h1 and c1h2.

One one terminal run
1) ip netns e c1h1 bash
2) iperf -s

One the second one, run
1) ip netns e c1h2 bash
2) iperf -c 192.1.1.1

The bandwidth is in Kbps which is very low for a flow between network namespaces.

Tests using Flent (tcp_nup tests) also give the same low bandwidth.

