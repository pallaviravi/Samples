# Define options
set val(chan)           			Channel/WirelessChannel	    	;# channel type
set val(prop)           			Propagation/TwoRayGround    	;# radio-propagation model
set val(netif)          			Phy/WirelessPhy        	    	;# network interface type
set val(mac)            			Mac/802_11             	    	;# MAC type
set val(ifq)            			Queue/DropTail/PriQueue		;# interface queue type
set val(ll)             			LL	   		 	;# link layer type
set val(ant)            			Antenna/OmniAntenna   	    	;# antenna model
set val(ifqlen)         			50		              	;# max packet in ifq
set val(nn)             			16      		        ;# number of mobilenodes
set val(rp)             			AODV			    	;# routing protocol
set val(x) 					500    			    	;# X dimension of the topography in meters
set val(y) 					500			        ;# Y dimension of the topography in meters
set val(time)           			100.0   			        ;# Simulation time in seconds
set data_interval       			0.5    		        	;# CBR Traffic Interval
set start_time          			0.2				;# traffic start time

set cluster(time)         			5.0				;#Start Time for cluster 
set nodesclustered 				0				;#Number of nodes used in cluster formation
set nweight(node,weight) 			0				;#Nnode and its weight(How many one hop neighbor it has ? ) 
set nneighbor(node,neigh) 			0				;#Node and its neighbors's id (One hop neighbor id)
set noofclusters 				0				;#Number of clusters formed in this topology
set nodeincluster(clusterno,noofnodes)		0				;#Nunber of nodes in each cluster formed
set usednode(nodelist)				0				;#Node id of nodes used in clusering with this topology
set noofusednode				0				;#Number of node used in this topology	
set nodedetails(nodid,details)			0				;#Nodes details with nodeID, ClusterID, Cluster head
set eachclustersize(clusterid,weight) 		0				;#Each Cluster Weight
set selfcertificate(node,certificatevalue)	0				;#Each node assgined a certificate value and other details
set clusterselfcert(cluster,node,certificate) 	0				;#Each cluster head holds the sefl-certificate of each cluster members


proc finish {} {
	global ns_ tracefile namfile

  	$ns_ flush-trace

  	close $tracefile

  	close $namfile

	exec awk -f thruput_clust.awk MKDSCFout.tr > thruput_clust.dat &
  	exec nam MKDSCFout.nam &
	
	exit 0
	
}

proc routetable {} {

	global val nweight nneighbor

	puts "\nWeight of each node"
	puts "****** ** **** ****"
	for {set i 0} {$i < $val(nn)} {incr i} {
		puts "\tNode(w) $i = $nweight($i,1)"
	}
	
	puts "\nNeighbor node's id of each node"
	puts "******** ****** ** ** **** ****"
	
	for {set i 0 } {$i < $val(nn)} {incr i} {
		puts -nonewline "\tNode($i) neighbors {" 
		for {set j 0} {$j < $nweight($i,1) } {incr j} {
			puts  -nonewline $nneighbor($i,$j)
			if {$j < $nweight($i,1) - 1} {
				puts -nonewline ", "		
			}		
		}
		puts -nonewline "}"
		puts ""
	}
}

#Procedure to find the trust of node h , evaluated by node e
proc nodetrusteval {e h} {
	global ns_ nweight nneighbor
	
	set weighth $nweight($h,1);				#Weight of node h
	set weighte $nweight($e,1);				#Weight of node e
	for {set i 0} {$i < $weighth} {incr i} {
		set neigh($i) $nneighbor($h,$i);			#Neighbor list of node h
	}
	for {set i 0} {$i < $weighte} {incr i} {
		set neige($i) $nneighbor($e,$i);		#Neighbor list of node e
	}
	set t 0;						#Threshold value
	set counttlimit 0;					#Number of node neighbore to node "h" not to node "e"
	set countt 0;
	for {set i 0} {$i < $weighth} {incr i} {
		for {set j 0} {$j < $weighte} {incr j} {
			if {$neigh($i) != $neige($j)} {
				incr countt;
			}
		}
		if {$countt == $weighte} {
			set d($counttlimit) $neigh($i)
			incr counttlimit;
		}
		set countt 0;
	}
	set t [expr $counttlimit / 2];						#Threshold value for node e,h
	set positiveresponse 0;
	for {set i 0} {$i < $counttlimit} {incr i} {
		set positiveresponse [expr $positiveresponse + [presenceofhind $h $d($i)]];
		packettran $h $d($i);
	}
	if {$positiveresponse < $t} {
		return 0;
	}
	if {$positiveresponse > $t} {
		return 1;
	}
}

#Procedure to find the presence of node h in node d's neighbor list
proc presenceofhind {hnode dnode} {

	global ns_ nweight nneighbor
	set flag 0;
	for {set j 0} {$j < $nweight($dnode,1)} {incr j} {
		if {$hnode == $nneighbor($dnode,$j)} {
			set flag 1;		
		}
	}
	return $flag;
}



proc clusterformation {} {
	
	global eachclustersize clusterselfcert clustermempublickey mypublickey blacklisted;
	global ns_ node_ cluster nweight nneighbor kd ks kdch ksch kdchflag colorindex;
	global nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag nodedetails selfcertificate;
	global array set clr {}	
	set blacklisted 0;
	set colorindex 0;
	set clr(0) "red"
	set clr(1) "blue"
	set clr(2) "green"
	set clr(3) "brown"
	
	
	for {set i 0} {$i <15} {incr i} {
		set usednodeflag($i,0) $i;
		set usednodeflag($i,1) 0;
	}
	for {set i 0} {$i < 15} {incr i} {
		set nodedetails($i,0) $i;			#Node ID
		set nodedetails($i,1) 9999;			#Node Cluster ID
		set nodedetails($i,2) 9999;			#Node Cluster head
	}
	for {set i 0} {$i <15} {incr i} {
		set memberhead($i,0) $i;
		set memberhead($i,1) 0;
	}
	for {set nodescluster 0} {$nodesclustered < 15} {incr nodesclustered} {				#Till all nodes involved in cluster formation
		set nodehigh [selectnode];
		set trustcount 0;
		for {set q 0} {$q < $nweight($nodehigh,1)} {incr q} {
			packettran $nneighbor($nodehigh,$q) $nodehigh;
			
			set trustcount [expr $trustcount + [headelectmsg $nneighbor($nodehigh,$q) $nodehigh]];
		}
		if {$trustcount == $nweight($nodehigh,1)} {
			set currentclustersize 0;
			set nodeincluster($noofclusters,$currentclustersize) $nodehigh;
			#$ns_ at $cluster(time) "initial_node_pos $node_($nodeincluster($noofclusters,$currentclustersize)) 50"
			$ns_ at $cluster(time) "$node_($nodeincluster($noofclusters,$currentclustersize)) label  \"CH$noofclusters\""
			$node_($nodeincluster($noofclusters,$currentclustersize)) color $clr($colorindex)
			$ns_ at $cluster(time) "$node_($nodeincluster($noofclusters,$currentclustersize)) color $clr($colorindex)"
			set cluster(time) [expr $cluster(time) + 0.1];
											
			incr currentclustersize;
			set nodedetails($nodehigh,1) $noofclusters;
			set nodedetails($nodehigh,2) $nodehigh;
			for {set t 0} {$t < $nweight($nodehigh,1)} {incr t} {
				if {$nodedetails($nneighbor($nodehigh,$t),1) == 9999 && $nodedetails($nneighbor($nodehigh,$t),2) == 9999} {
					set nodedetails($nneighbor($nodehigh,$t),1) $noofclusters
					set nodedetails($nneighbor($nodehigh,$t),2) $nodehigh;
	#				puts "$nneighbor($nodehigh,$t)---$nodedetails($nneighbor($nodehigh,$t),2)"
					set usednodeflag($nneighbor($nodehigh,$t),1) 1;
					set nodeincluster($noofclusters,$currentclustersize) $nneighbor($nodehigh,$t);
					packettran $nodeincluster($noofclusters,0) $nodeincluster($noofclusters,$currentclustersize)
					
					$ns_ at $cluster(time) "$node_($nodeincluster($noofclusters,$currentclustersize)) label  \"C$noofclusters M$currentclustersize\""
					$node_($nodeincluster($noofclusters,$currentclustersize)) color $clr($colorindex)
			$ns_ at $cluster(time) "$node_($nodeincluster($noofclusters,$currentclustersize)) color $clr($colorindex)"					
					set cluster(time) [expr $cluster(time) + 0.1];
					
					incr currentclustersize;
					incr nodesclustered;
					
				}
			}
		}
		incr colorindex;
		set eachclustersize($noofclusters,0) $noofclusters
		set eachclustersize($noofclusters,1) $currentclustersize
		incr noofclusters;
	}

	puts "\nClusters Created"
	puts "******** *******"
	for {set u 0} {$u < $noofclusters} {incr u} {
		puts -nonewline "\tCluster $u: {"
		for {set v 0} {$v < $eachclustersize($u,1)} {incr v} {
			puts -nonewline $nodeincluster($u,$v)
			if {$v < [expr $eachclustersize($u,1) - 1]} {
				puts -nonewline ",";
				
			}
		}
		puts "}"
	}
	#for {set i 0} {$i < 16} {incr i} {
	#	puts "$nodedetails($i, 2)"
	#}
	#Head trust evaluation
	for {set i 0} {$i < 15} {incr i} {
		set presentinclusters 0;
		for {set j 0} {$j < $noofclusters} {incr j} {
			for {set k 0} {$k < $eachclustersize($j,1)} {incr k} {
				if {$i == $nodeincluster($j,$k)} {
					set foundin($presentinclusters) $j;
					incr presentinclusters;
				}
			}
		}
		if {$presentinclusters > 1} {
			for {set k 0} {$k < $presentsinclusters} {incr k} {
				set trustme [nodetrusteval $i $foundin($k)];
				if {$trustme == 0} {
					set blacklistednode($blacklisted) $foundin($k);
					incr blacklisted;
				}
			}
		}
	}	
	if {$blacklisted == 0} {
                 
                puts "Cluster head data initiated\n" 
 		puts "\n\nNo Blacklisted Node\n"
		puts "All nodes Trustable\n"
                

	}
	if {$blacklisted > 0} {
		for {set i 0} {$i < $blacklisted} {incr i} {
			puts blacklistednode($i);
		}
  	} 
  	
}
#Nodes participating in cluster head election
proc headelectmsg {evaluatingnode evaluatednode} {
	global ns_ nweight nneighbor nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag nodedetails headelectid;
	set nodetrusted 0;
	packettran $evaluatingnode $evaluatednode
	
	for {set r 0} {$r < $nweight($evaluatingnode,1)} {incr r} {
		if {$nneighbor($evaluatingnode,$r) == $evaluatednode} {
			set nodetrusted [headmsg $evaluatingnode $evaluatednode];
		}
	}
	return $nodetrusted;
}
# Informing all nodes that he is the cluster head
proc headmsg {evaluatingnode evaluatednode} {
	global ns_ nweight nneighbor nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag nodedetails headelectid;
	packettran $evaluatingnode $evaluatednode
	set trusted 0;
	set trusted [nodetrusteval $evaluatingnode $evaluatednode];
	return $trusted;
}
proc selectnode {} {

	global ns_ nweight nneighbor nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag;
	set flag 0;
	for {set p 0} {$p < 15} {incr p} {
		if {$flag == 0} {
			if {$usednodeflag($p,1) == 0} {
				set nodehighweight $nweight($p,1);
				set highnode $p;
				set flag 1;
			}
		}
	}
	for {set k 0} {$k < 15} {incr k} {
		if {$usednodeflag($k,1) == 0} {
			set currentweight $nweight($k,1);
			if {$currentweight > $nodehighweight} {
				if {$usednodeflag($k,1) == 0} {
					set nodehighweight $currentweight;
					set highnode $k;
				}
			}
			if {$currentweight == $nodehighweight} {
				if {$usednodeflag($k,1) == 0} {
					if {$usednodeflag($k,0) > $highnode} {
						set nodehighweight $currentweight;
						set highnode $k;
					}
				}
			}
		}		
	}
	set usednodeflag($highnode,1) 1;
	return $highnode;
}







proc packettran {nodesender nodereceiver} {

	global ns_ node_ udp cbr cluster 
	global nweight nneighbor nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag selfcertificate;

	
	set udp($nodesender) [new Agent/UDP]
	$ns_ attach-agent $node_($nodesender) $udp($nodesender)

	set cbr($nodesender) [new Application/Traffic/CBR]
	$cbr($nodesender) set packetSize_ 1024
	$cbr($nodesender) set interval_ 0.2
	$cbr($nodesender) set random_ 0
	$cbr($nodesender) set maxpkts_ 10000

	$cbr($nodesender) attach-agent $udp($nodesender)

	set null($nodesender) [new Agent/Null]
	$ns_ attach-agent $node_($nodereceiver) $null($nodesender)

	$ns_ connect $udp($nodesender) $null($nodesender)

	$ns_ at $cluster(time) "$cbr($nodesender) start"
	set cluster(time) [expr 0.01+ $cluster(time)]
	#puts "$cluster(time)"
	$ns_ at $cluster(time) "$cbr($nodesender) stop"
	set cluster(time) [expr 0.08 + $cluster(time)]
	#puts "$cluster(time)"

}


# Initialize Global Variables


set ns_ [new Simulator]
                                   

# Trace Files

set tracefile [open MKDSCFout.tr w]

$ns_ use-newtrace

$ns_ trace-all $tracefile

set namfile [open MKDSCFout.nam w]
	
$ns_ namtrace-all-wireless $namfile $val(x) $val(y)

#for {set i 0} {$i < 15} {incr i} {
 #   set color [expr $i % 6]
  #  if {$color == 0} {
#	$ns_ color $i blue
 #   }
  #  if {$color == 1} {
#	$ns_ color $i red
 #  }
  #  if {$color == 2} {
#	$ns_ color $i green
 #   }
  # if {$color == 3} {
#	$ns_ color $i yellow
 #   }
  #  if {$color == 4} {
#	$ns_ color $i brown
 #   }
  #  if {$color == 5} {
#	$ns_ color $i black
 #   }
#}


#$ns_ color 0 blue
#$ns_ color 1 red
#$ns_ color 2 chocolate
$ns_ color 3 yellow
#$ns_ color 4 brown


# set up topography object

set topo [new Topography]

$topo load_flatgrid $val(x) $val(y)


# Create God
set god_ [create-god $val(nn)]

set chan [new $val(chan)]
 

# configure node
$ns_ node-config -adhocRouting $val(rp) \
 	-llType $val(ll) \
 	-macType $val(mac) \
 	-ifqType $val(ifq) \
 	-ifqLen $val(ifqlen) \
	-antType $val(ant) \
	-propType $val(prop) \
	-phyType $val(netif) \
 	-topoInstance $topo \
 	-agentTrace ON \
 	-routerTrace ON \
 	-macTrace ON \
 	-movementTrace ON \
	-channel $chan

#$ns_ node-config -energyModel $energymodel\
# -rxPower $p_rx\
# -txPower $p_tx\
# -initialEnergy $initialenergy\



for {set i 0} {$i < $val(nn) } {incr i} {
	set node_($i) [$ns_ node]
	$node_($i) random-motion 0 ;# disable random motion
	$god_ new_node $node_($i)	
	$ns_ initial_node_pos $node_($i) 30


}
#$ns_ node-config -addressingType hier
# Provide initial (X,Y, for now Z=0) co-ordinates for mobilenodes
# and produce some simple node movements
$node_(0) set X_ 460
$node_(0) set Y_ 170
$node_(0) set Z_ 0.0
	$node_(1) set X_ 250
	$node_(1) set Y_ 120
	$node_(1) set Z_ 0.0
$node_(2) set X_ 450
$node_(2) set Y_ 370
$node_(2) set Z_ 0.0
$node_(3) set X_ 350
$node_(3) set Y_ 100
$node_(3) set Z_ 0.0
$node_(4) set X_ 550
$node_(4) set Y_ 250
$node_(4) set Z_ 0.0
$node_(5) set X_ 480
$node_(5) set Y_ 320
$node_(5) set Z_ 0.0
	$node_(6) set X_ 130
	$node_(6) set Y_ 220
	$node_(6) set Z_ 0.0
$node_(7) set X_ 110
$node_(7) set Y_ 280
$node_(7) set Z_ 0.0
$node_(8) set X_ 300
$node_(8) set Y_ 250
$node_(8) set Z_ 0.0
	$node_(9) set X_ 380
	$node_(9) set Y_ 250
	$node_(9) set Z_ 0.0
$node_(10) set X_ 250
$node_(10) set Y_ 15
$node_(10) set Z_ 0.0
$node_(11) set X_ 30
$node_(11) set Y_ 250
$node_(11) set Z_ 0.0
	$node_(12) set X_ 488
	$node_(12) set Y_ 400
	$node_(12) set Z_ 0.0
	$node_(12) set X_ 220
	$node_(12) set Y_ 400
	$node_(12) set Z_ 0.0
$node_(13) set X_ 250
$node_(13) set Y_ 450
$node_(13) set Z_ 0.0
$node_(14) set X_ 150
$node_(14) set Y_ 22
$node_(14) set Z_ 0.0
$node_(15) set X_ 536.993
$node_(15) set Y_ 48.27
$node_(15) set Z_ 0.0


	
# Initial Movement
for {set i 0} {$i < $val(nn) } {incr i} {
$ns_ at 0.1 "$node_($i) setdest 10.0 10.0 0.0"
}

$ns_ at 0.2 "$node_(1) setdest 25.0 20.0 0.5"

$ns_ at 0.2 "$node_(14) setdest 25.0 20.0 0.25"

$ns_ at 0.2 "$node_(7) setdest 20.0 18.0 1.0"

$ns_ at 0.2 "$node_(9) setdest 469.0 268.0 1.5"

$ns_ at 0.2 "$node_(12) setdest 200.0 430.0 2.0"

$ns_ at 0.2 "$node_(4) setdest 25.0 420.0 0.8"






for {set i 0} {$i < $val(nn)} {incr i} {
	set nweight($i,0) $i
}


#Node 0 routing table
$node_(0) add-neighbor $node_(4)
set nneighbor(0,0) 4;

$node_(0) add-neighbor $node_(3)
set nneighbor(0,1) 3;

#$node_(0) add-neighbor $node_(5)
#set nneighbor(0,2) 5;

#$node_(0) add-neighbor $node_(6)
#set nneighbor(0,3) 6;

$node_(0) add-neighbor $node_(9)
set nneighbor(0,2) 9;


#Node 1 routing table
$node_(1) add-neighbor $node_(3)
set nneighbor(1,0) 3;

#$node_(1) add-neighbor $node_(8)
#set nneighbor(1,1) 8;

$node_(1) add-neighbor $node_(10)
set nneighbor(1,1) 10;

$node_(1) add-neighbor $node_(14)
set nneighbor(1,2) 14;


#Node 2 routing table
#$node_(2) add-neighbor $node_(0)
#set nneighbor(2,0) 0;

$node_(2) add-neighbor $node_(5)
set nneighbor(2,0) 5;

#$node_(2) add-neighbor $node_(6)
#set nneighbor(2,2) 6;

$node_(2) add-neighbor $node_(8)
set nneighbor(2,1) 8;

$node_(2) add-neighbor $node_(9)
set nneighbor(2,2) 9;


#Node 3 routing table
$node_(3) add-neighbor $node_(0)
set nneighbor(3,0) 0;

$node_(3) add-neighbor $node_(1)
set nneighbor(3,1) 1;


#Node 4 routing table
$node_(4) add-neighbor $node_(9)
set nneighbor(4,0) 9;

$node_(4) add-neighbor $node_(5)
set nneighbor(4,1) 5;



#Node 5 routing table
$node_(5) add-neighbor $node_(2)
set nneighbor(5,0) 2;

$node_(5) add-neighbor $node_(4)
set nneighbor(5,1) 4;

$node_(5) add-neighbor $node_(9)
set nneighbor(5,2) 9;


#Node 6 routing table
#$node_(6) add-neighbor $node_(0)
#set nneighbor(6,0) 0;

$node_(6) add-neighbor $node_(8)
set nneighbor(6,0) 8;

$node_(6) add-neighbor $node_(7)
set nneighbor(6,1) 7;

$node_(6) add-neighbor $node_(11)
set nneighbor(6,2) 11;


#Node 7 routing table
$node_(7) add-neighbor $node_(6)
set nneighbor(7,0) 6;

#$node_(7) add-neighbor $node_(8)
#set nneighbor(7,1) 8;

$node_(7) add-neighbor $node_(12)
set nneighbor(7,1) 12;


#Node 8 routing table
#$node_(8) add-neighbor $node_(1)
#set nneighbor(8,0) 1;

$node_(8) add-neighbor $node_(2)
set nneighbor(8,0) 2;

$node_(8) add-neighbor $node_(6)
set nneighbor(8,1) 6;

$node_(8) add-neighbor $node_(9)
set nneighbor(8,2) 9;


#Node 9 routing table
$node_(9) add-neighbor $node_(0)
set nneighbor(9,0) 0;

$node_(9) add-neighbor $node_(2)
set nneighbor(9,1) 2;

$node_(9) add-neighbor $node_(4)
set nneighbor(9,2) 4;

$node_(9) add-neighbor $node_(5)
set nneighbor(9,3) 5;

$node_(9) add-neighbor $node_(8)
set nneighbor(9,4) 8;


#Node 10 routing table
$node_(10) add-neighbor $node_(1)
set nneighbor(10,0) 1;

$node_(10) add-neighbor $node_(4)
set nneighbor(10,1) 14;



#Node 11 routing table
$node_(11) add-neighbor $node_(6)
set nneighbor(11,0) 6;

#$node_(11) add-neighbor $node_(12)
#set nneighbor(11,1) 12;


#Node 12 routing table
$node_(12) add-neighbor $node_(7)
set nneighbor(12,0) 7;

#$node_(12) add-neighbor $node_(11)
#set nneighbor(12,1) 11;

$node_(12) add-neighbor $node_(13)
set nneighbor(12,1) 13;


#Node 13 routing table
$node_(13) add-neighbor $node_(12)
set nneighbor(13,0) 12;


#Node 14 routing table
$node_(14) add-neighbor $node_(1)
set nneighbor(14,0) 1;

$node_(14) add-neighbor $node_(10)
set nneighbor(14,1) 10;



# Tell nodes when the simulation ends
for {set i 0} {$i < $val(nn) } {incr i} {
    $ns_ at $val(time) "$node_($i) reset";
}


#Storing node's weight detials in Array nweight(i,j) where i->Node id, j-> weight of node i
for {set i 0} {$i < $val(nn)} {incr i} {
	set nweight($i,1) [llength [$node_($i) neighbors]]
}

$god_ compute_route
$ns_ compute-routes
#Set a TCP connection between node_(0) and node_(1)
puts "enter source node"
set src [gets stdin]

puts "enter destination node"
set dest [gets stdin]

if {$src > $val(nn)} {
puts "The given Source Node does not exist in the network"
exit 0
}

if {$dest > $val(nn)} {
puts "The given destination Node does not exist in the network"
exit 0
}

$ns_ at 25.0 "$node_($dest) label Destinaton"
$ns_ at 25.0 "$node_($src) label Source"

set tcp [new Agent/TCP]
$tcp set class_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(5) $tcp
$ns_ attach-agent $node_(9) $sink
$ns_ connect $tcp $sink
$tcp set fid_ 3 
set ftp [new Application/FTP]
$ftp attach-agent $tcp

$ns_ at 25.0 "$ftp start" 
$ns_ at 30.0 "$ftp stop" 


set tcp [new Agent/TCP]
#$tcp set fid_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(9) $tcp
$ns_ attach-agent $node_(6) $sink
$ns_ connect $tcp $sink
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ns_ at 30.0 "$ftp start" 
$ns_ at 35.0 "$ftp stop" 

set tcp [new Agent/TCP]
#$tcp set fid_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(9) $tcp
$ns_ attach-agent $node_(1) $sink
$ns_ connect $tcp $sink
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ns_ at 30.0 "$ftp start" 
$ns_ at 35.0 "$ftp stop"

set tcp [new Agent/TCP]
#$tcp set fid_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(9) $tcp
$ns_ attach-agent $node_(12) $sink
$ns_ connect $tcp $sink
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ns_ at 30.0 "$ftp start" 
$ns_ at 35.0 "$ftp stop"

#broadcast packets to cluster memebers(CH2 to its members)
set tcp [new Agent/TCP]
#$tcp set fid_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(1) $tcp
$ns_ attach-agent $node_(10) $sink
$ns_ connect $tcp $sink
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ns_ at 35.0 "$ftp start" 
$ns_ at 40.0 "$ftp stop" 

set tcp [new Agent/TCP]
#$tcp set fid_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(1) $tcp
$ns_ attach-agent $node_(14) $sink
$ns_ connect $tcp $sink
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ns_ at 35.0 "$ftp start" 
$ns_ at 40.0 "$ftp stop"

set tcp [new Agent/TCP]
#$tcp set fid_ 3
set sink [new Agent/TCPSink]
$ns_ attach-agent $node_(1) $tcp
$ns_ attach-agent $node_(3) $sink
$ns_ connect $tcp $sink
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ns_ at 35.0 "$ftp start" 
$ns_ at 40.0 "$ftp stop"

for {set i 0} {$i < 13} {incr i} {

	set udp($i) [new Agent/UDP]
	$ns_ attach-agent $node_($i) $udp($i)

	set cbr($i) [new Application/Traffic/CBR]
	$cbr($i) set packetSize_ 1024
	$cbr($i) set interval_ 0.2
	$cbr($i) set random_ 0
	$cbr($i) set maxpkts_ 10000

	$cbr($i) attach-agent $udp($i)

	set null($i) [new Agent/Null]
	$ns_ attach-agent $node_([expr $i+2]) $null($i)

	$ns_ connect $udp($i) $null($i)

	$ns_ at [expr 0.1 *$i] "$cbr($i) start"

	$ns_ at [expr 0.15*$i] "$cbr($i) stop" 

}
set cluster(time) [expr 0.15 * $i]


# ======================================================================
# Main Program
# ======================================================================


#Display node and route information
routetable;

clusterformation;

$ns_ at $val(time) "finish"


$ns_ at [expr $val(time) + 0.01] "puts \"Processed Cluster formation ...\"; $ns_ halt"
puts "Starting Simulation..."


$ns_ run

