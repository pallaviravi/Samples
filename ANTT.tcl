
# Define options
set val(chan)           			Channel/WirelessChannel	    	;# channel type
set val(prop)           			Propagation/TwoRayGround    	;# radio-propagation model
set val(netif)          			Phy/WirelessPhy        	    	;# network interface type
set val(mac)            			Mac/802_11             	    	;# MAC type
set val(ifq)            			Queue/DropTail/PriQueue		;# interface queue type
set val(ll)             			LL	   		 	;# link layer type
set val(ant)            			Antenna/OmniAntenna   	    	;# antenna model
set val(ifqlen)         			50		              	;# max packet in ifq
set val(nn)             			15      		        ;# number of mobilenodes
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
set clustersolunpath(cluster,node,path)	0				;#Each Cluster members Public path
set mysolnpath(node,path)			0				;#Each nodes Public path
set fs						0				;#path Exchange Source node Id
set fd						0				;#path Exchange Destination node Id
set fsch					0				;#Cluster Head of Source node
set fdch					0				;#Cluster Head of Destination node
set fdchflag					0				;#Flag for finding Destination CH
set stopantalg				0				;#Flag for checking fd and fdch blacklisted or not
	

proc finish {} {
	global ns_ tracefile namfile

  	$ns_ flush-trace

  	close $tracefile

  	close $namfile

	exec awk -f thruput_ant.awk MfdSCFout.tr > thruput_ant.dat &
  	exec nam MfdSCFout.nam &
	
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
	
	global eachclustersize clusterselfcert clustersolunpath mysolnpath blacklisted;
	global ns_ node_ cluster nweight nneighbor fd fs fdch fsch fdchflag;
	global nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag nodedetails selfcertificate;
	set blacklisted 0;
	
	for {set i 0} {$i <15} {incr i} {
		set usednodeflag($i,0) $i;
		set usednodeflag($i,1) 0;
	}
	for {set i 0} {$i < 15} {incr i} {
		set nodedetails($i,0) $i;			#Node ID
		set nodedetails($i,1) 9999;			#Node Cluster ID
		set nodedetails($i,2) 9999;			#Node Cluster head
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
			$ns_ at $cluster(time) "$node_($nodeincluster($noofclusters,$currentclustersize)) label  \"CH$noofclusters\""
			set cluster(time) [expr $cluster(time) + 0.1];
							
			incr currentclustersize;
			set nodedetails($nodehigh,1) $noofclusters;
			set nodedetails($nodehigh,2) $nodehigh;
			for {set t 0} {$t < $nweight($nodehigh,1)} {incr t} {
				if {$nodedetails($nneighbor($nodehigh,$t),1) == 9999 && $nodedetails($nneighbor($nodehigh,$t),2) == 9999} {
					set nodedetails($nneighbor($nodehigh,$t),1) $noofclusters
					set nodedetails($nneighbor($nodehigh,$t),2) $nodehigh;
					set usednodeflag($nneighbor($nodehigh,$t),1) 1;
					set nodeincluster($noofclusters,$currentclustersize) $nneighbor($nodehigh,$t);
					packettran $nodeincluster($noofclusters,0) $nodeincluster($noofclusters,$currentclustersize)

					$ns_ at $cluster(time) "$node_($nodeincluster($noofclusters,$currentclustersize)) label  \"C$noofclusters M$currentclustersize\""
					set cluster(time) [expr $cluster(time) + 0.1];
					
					incr currentclustersize;
					incr nodesclustered;
					
				}
			}
		}
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
		puts "\n\nNo Blacklisted Node\n"
		puts "All nodes Trustable\n"
	}
	if {$blacklisted > 0} {
		for {set i 0} {$i < $blacklisted} {incr i} {
			puts blacklistednode($i);
		}
  	} 
  	pathmgntscheme 4 14;
}
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

proc pathmgntscheme {fs fd} {

	global ns_ node_ nweight nneighbor nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag selfcertificate;
	global fdch fsch fdchflag eachclustersize clusterselfcert clustersolunpath val nodedetails cluster val;
	puts "path Exchange started .. "
	puts "\nSource node : $fs \n\nDestination node: $fd"
	global blacklisted blacklistednode;	
	for {set i 0} {$i < 15} {incr i} {
		set selfcertificate($i,0) $i ;
		set selfcertificate($i,1) "pathfile$i pathpass$i org$i orgunit$i loc$i country$i"
		#puts "$selfcertificate($i,0) $selfcertificate($i,1)"
	}
	
	$ns_ at $cluster(time) "$node_($fs) label  \"Source node \""
	set cluster(time) [expr $cluster(time) + 0.5];

	$ns_ at $cluster(time) "$node_($fd) label  \"Destination node \""
	set cluster(time) [expr $cluster(time) + 0.5];
	
	puts "\n\nEach node solution to find path Completely"
	for {set u 0} {$u < $noofclusters} {incr u} {
		for {set v 0} {$v < $eachclustersize($u,1)} {incr v} {
			set clusterselfcert($u,$v,0) $nodeincluster($u,$v);
			set clusterselfcert($u,$v,1) $selfcertificate($nodeincluster($u,$v),1);	
			packettran $nodeincluster($u,$v) $nodeincluster($u,0)		 
			#puts "$clusterselfcert($u,$v,0) $clusterselfcert($u,$v,1)"
		}
	}
	puts "\nSolution segreagated Successfully  by each Cluster Head to respective destination\n"
	
	for {set u 0} {$u < $noofclusters} {incr u} {
		for {set v 0} {$v < $eachclustersize($u,1)} {incr v} {
			set clustersolunpath($u,$v,0) $nodeincluster($u,$v);
			set clustersolunpath($u,$v,1) [expr [expr $u + 10]  * [expr $v + 3] * [expr $nodeincluster($u,$v) + 15]];			 
			set mysolnpath($nodeincluster($u,$v),0) $nodeincluster($u,$v)
			set mysolnpath($nodeincluster($u,$v),1) $clustersolunpath($u,$v,1)
			packettran $nodeincluster($u,0) $nodeincluster($u,$v)		 
			
			#puts "$clustersolunpath($u,$v,0) $clustersolunpath($u,$v,1) "
		}
	}
	puts " path assigned for each node assigned successfully\n"
	set fsch $nodedetails($fs,2);			#Source Cluster head
	$ns_ at $cluster(time) "$node_($fsch) label  \"CHs \""
	set cluster(time) [expr $cluster(time) + 0.5];
	
	set fdch [findfdch $fd];		
	$ns_ at $cluster(time) "$node_($fdch) label  \"CHd \""
	set cluster(time) [expr $cluster(time) + 0.5];
	
	set stopantalg 0;
	for {set i 0} {$i < $blacklisted} {incr i} {
		if {$fd == $blacklistednode($i) || $fdch == $blacklistednode($i)} {
			set stopantalg 1;
		}
	}
	if {$stopantalg == 1} {
		puts "Destination node/ Destination node head is not found\n"
		puts "path Exchange process is halted\n\n"
	}
	if {$stopantalg == 0} {
		puts "Destination node and its cluster head founded\n"
		
		packettran $fs $fsch
		set fdtrust [nodetrusteval $fsch $fd]		
		packettran $fsch $fs
		
		packettran $fs $fsch
		set fdchtrust [nodetrusteval $fsch $fdch]
		packettran $fsch $fs
		
		if {$fdtrust == 1 && $fdchtrust == 1} {
			puts "Destination node and its Cluster head Trusted\n"
			
			packettran $fs $fd;
			set fsdpky $mysolnpath($fd,1)	;		#Requesting Public path from Destination node
			#puts "$fsdpky Destination Public path"	
			
			packettran $fd $fdch;
			set fschtrust [nodetrusteval $fdch $fsch];	#Destination node Checfs the trust of the CHs
			#puts "$fschtrust"
			
			for {set u 0} {$u < $noofclusters} {incr u} {
				for {set v 0} {$v < $eachclustersize($u,1)} {incr v} {
					if {$clustersolunpath($u,$v,0) == $fd} {
						packettran $fsch $fdch
						set fschdpky $clustersolunpath($u,$v,1);			#Exchange PKr with CHs
						set fschcerts $clusterselfcert($u,$v,1)
						packettran $fdch $fsch
					}
					if {$clustersolunpath($u,$v,0) == $fs} {
						packettran $fdch $fsch
						set fdchspky $clustersolunpath($u,$v,1);			#Exchange Pfs with CHr
						set fdchcertd $clusterselfcert($u,$v,1)
						packettran $fsch $fdch
					}
				}
			}
			#puts "CHrpfs $fdchspky CHspkr $fschdpky"
			packettran $fs $fdch
			set dencryptedcertificate "$fschdpky $fdchcertd";			#Cert(r) Encrypted using Pfs in CHd
			set ddecryptedcertificate [string map {$mysolnpath($fd,1) $encryptedcertificate} $fdchcertd] ;#Decryption Cert(r)With Pfs in Source node
			packettran $fdch $fs
			#puts "Cert(r) : $dencryptedcertificate\n$fschdpky\n$ddecryptedcertificate\n"
			if {[string compare $ddecryptedcertificate $selfcertificate($fd,1)]} {
				set vcertr "valid"
				#puts "Cert(r) validated\n"
			}
			
			packettran $fd $fsch
			set sencryptedcertificate "$fdchspky $fschcerts";			#Cert(s) Encrypted using Pfd in CHs
			set sdecryptedcertificate [string map {$mysolnpath($fs,1) $encryptedcertificate} $fschcerts] ;#Decryption Cert(s)With Pfd in Destination node
			packettran $fsch $fd
			#puts "Cert(s) : $sencryptedcertificate\n$fdchspky\n$sdecryptedcertificate\n"
			if {[string compare $sdecryptedcertificate $selfcertificate($fs,1)]} {
				set vcerts "valid"
				#puts "Cert(s) validated\n"
			}
			
			if {[string compare vcertr vcerts]} {
				puts "Both path($fs) and path($fd) are valid\n";
				puts "Ant algorithm Started\n";
				
				#Source node operation
				set sprimepath [expr round(rand() * 100)];				#Limit for Prime number for Session path generation
				#puts "$sprimepath"
				set primeflag 0
				for {set i 1} {$i <= $sprimepath} {incr i} {
					for {set j 2} {$j < $i} {incr j} {
						if {[expr $i%$j] == 0} { 
							set primeflag 1;
							break;
						}
					}
					if {$primeflag == 0} {
						set sprimeno $i;							#Prime number for this Session path
					}
					if {$primeflag == 1} {
						set primeflag 0;
					}
				}
				#puts "$sprimeno"
				set baseg [expr round(rand() *100)];						#Base 'g' (primitive root mod p)
				#puts "$baseg"
				set sprivatepath [expr round(rand() * 10)];					#Private path of source node
				set sA [expr round(fmod(pow($baseg,$sprivatepath),$sprimeno))];			#A value of source node
				#puts "$sA"
				packettran $fs $fd;
				
				
				#Destination node opeartion
				set dA $sA;
				set dprimeno $sprimeno;
				set dprivatepath [expr round(rand() * 10)];					#Private path of destination node
				set dB [expr round(fmod(pow($baseg,$dprivatepath),$dprimeno))];			#B value of destination node
				#puts "$dB"
				
				#Finding Session path from sA and sB on Both source and destination node 
				set sB $dB
				
				packettran $fd $fs
				set ssession [expr round(fmod((pow($sB,$sprivatepath)),$sprimeno))];
				set dsession [expr round(fmod((pow($dA,$dprivatepath)),$dprimeno))];
				
				#puts "$ssession $dsession\n\n" 
				if {$ssession == $dsession && $ssession != 0 && $dsession != 0} {
					puts "Session path Created Successfully\n"
				}
				if {$ssession != $dsession || $ssession == 0 && $dsession == 0} {
					puts "Session path Created Failed\n"				
				}
			}
		}
		if {$fdtrust != 1 || $fdchtrust != 1} {
			puts "Nodes are not trustable for path Exchange"
		}
		
	}
}

proc findfdch {fd} {
	global ns_ nweight nneighbor nodesclustered noofclusters nodeincluster usednode noofusednode usednodeflag selfcertificate;
	global fs fdch fsch fdchflag eachclustersize clusterselfcert clustersolunpath val nodedetails;
	set fdchflag 0;
	for {set u 0} {$u < $noofclusters && $fdchflag != 1} {incr u} {
		for {set v 0} {$v < $eachclustersize($u,1)} {incr v} {
			if {$nodeincluster($u,$v) == $fd} {
				set fdch $nodeincluster($u,0)
				set fdchflag 1;
			}	
		}
	}
	return $fdch;
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

set tracefile [open MfdSCFout.tr w]

$ns_ use-newtrace

$ns_ trace-all $tracefile

set namfile [open MfdSCFout.nam w]
	
$ns_ namtrace-all-wireless $namfile $val(x) $val(y)

for {set i 0} {$i < 15} {incr i} {
    set color [expr $i % 6]
    if {$color == 0} {
	$ns_ color $i blue
    }
    if {$color == 1} {
	$ns_ color $i red
    }
    if {$color == 2} {
	$ns_ color $i green
    }
    if {$color == 3} {
	$ns_ color $i yellow
    }
    if {$color == 4} {
	$ns_ color $i brown
    }
    if {$color == 5} {
	$ns_ color $i black
    }
}

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
$node_(0) set X_ 190
$node_(0) set Y_ 190
$node_(0) set Z_ 0.0
$node_(1) set X_ 100
$node_(1) set Y_ 100
$node_(1) set Z_ 0.0
$node_(2) set X_ 280
$node_(2) set Y_ 100
$node_(2) set Z_ 0.0
$node_(3) set X_ 50
$node_(3) set Y_ 230
$node_(3) set Z_ 0.0
$node_(4) set X_ 419
$node_(4) set Y_ 419
$node_(4) set Z_ 0.0
$node_(5) set X_ 390
$node_(5) set Y_ 90
$node_(5) set Z_ 0.0
$node_(6) set X_ 90
$node_(6) set Y_ 190
$node_(6) set Z_ 0.0
$node_(7) set X_ 90
$node_(7) set Y_ 390
$node_(7) set Z_ 0.0
$node_(8) set X_ 120
$node_(8) set Y_ 150
$node_(8) set Z_ 0.0
$node_(9) set X_ 390
$node_(9) set Y_ 180
$node_(9) set Z_ 0.0
$node_(10) set X_ 77
$node_(10) set Y_ 22
$node_(10) set Z_ 0.0
$node_(11) set X_ 40
$node_(11) set Y_ 430
$node_(11) set Z_ 0.0
$node_(12) set X_ 488
$node_(12) set Y_ 400
$node_(12) set Z_ 0.0
$node_(12) set X_ 310
$node_(12) set Y_ 460
$node_(12) set Z_ 0.0
$node_(13) set X_ 70
$node_(13) set Y_ 330
$node_(13) set Z_ 0.0
$node_(13) set X_ 430
$node_(14) set Y_ 450
$node_(14) set Z_ 0.0
$node_(14) set X_ 140
$node_(14) set Y_ 40
$node_(14) set Z_ 0.0


	
# Initial Movement
for {set i 0} {$i < $val(nn) } {incr i} {
$ns_ at 0.0 "$node_($i) setdest 10.0 10.0 0.0"
}

$ns_ at 0.2 "$node_(1) setdest 25.0 20.0 0.5"

$ns_ at 0.2 "$node_(14) setdest 25.0 20.0 0.25"

$ns_ at 0.2 "$node_(7) setdest 20.0 18.0 1.0"

$ns_ at 0.2 "$node_(9) setdest 249.0 228.0 1.5"

$ns_ at 0.2 "$node_(12) setdest 55.0 120.0 2.0"

$ns_ at 0.2 "$node_(4) setdest 25.0 420.0 0.8"


for {set i 0} {$i < $val(nn)} {incr i} {
	set nweight($i,0) $i
}


#Node 0 routing table
$node_(0) add-neighbor $node_(2)
set nneighbor(0,0) 2;

$node_(0) add-neighbor $node_(3)
set nneighbor(0,1) 3;

$node_(0) add-neighbor $node_(5)
set nneighbor(0,2) 5;

$node_(0) add-neighbor $node_(6)
set nneighbor(0,3) 6;

$node_(0) add-neighbor $node_(9)
set nneighbor(0,4) 9;


#Node 1 routing table
$node_(1) add-neighbor $node_(3)
set nneighbor(1,0) 3;

$node_(1) add-neighbor $node_(8)
set nneighbor(1,1) 8;

$node_(1) add-neighbor $node_(10)
set nneighbor(1,2) 10;

$node_(1) add-neighbor $node_(14)
set nneighbor(1,3) 14;


#Node 2 routing table
$node_(2) add-neighbor $node_(0)
set nneighbor(2,0) 0;

$node_(2) add-neighbor $node_(5)
set nneighbor(2,1) 5;

$node_(2) add-neighbor $node_(6)
set nneighbor(2,2) 6;

$node_(2) add-neighbor $node_(8)
set nneighbor(2,3) 8;

$node_(2) add-neighbor $node_(9)
set nneighbor(2,4) 9;


#Node 3 routing table
$node_(3) add-neighbor $node_(0)
set nneighbor(3,0) 0;

$node_(3) add-neighbor $node_(1)
set nneighbor(3,1) 1;


#Node 4 routing table
$node_(4) add-neighbor $node_(9)
set nneighbor(4,0) 9;


#Node 5 routing table
$node_(5) add-neighbor $node_(0)
set nneighbor(5,0) 0;

$node_(5) add-neighbor $node_(2)
set nneighbor(5,1) 2;

$node_(5) add-neighbor $node_(9)
set nneighbor(5,2) 9;


#Node 6 routing table
$node_(6) add-neighbor $node_(0)
set nneighbor(6,0) 0;

$node_(6) add-neighbor $node_(2)
set nneighbor(6,1) 2;

$node_(6) add-neighbor $node_(7)
set nneighbor(6,2) 7;

$node_(6) add-neighbor $node_(11)
set nneighbor(6,3) 11;


#Node 7 routing table
$node_(7) add-neighbor $node_(6)
set nneighbor(7,0) 6;

$node_(7) add-neighbor $node_(8)
set nneighbor(7,1) 8;

$node_(7) add-neighbor $node_(12)
set nneighbor(7,2) 12;


#Node 8 routing table
$node_(8) add-neighbor $node_(1)
set nneighbor(8,0) 1;

$node_(8) add-neighbor $node_(2)
set nneighbor(8,1) 2;

$node_(8) add-neighbor $node_(7)
set nneighbor(8,2) 7;

$node_(8) add-neighbor $node_(9)
set nneighbor(8,3) 9;


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


#Node 11 routing table
$node_(11) add-neighbor $node_(6)
set nneighbor(11,0) 6;

$node_(11) add-neighbor $node_(12)
set nneighbor(11,1) 12;


#Node 12 routing table
$node_(12) add-neighbor $node_(7)
set nneighbor(12,0) 7;

$node_(12) add-neighbor $node_(11)
set nneighbor(12,1) 11;

$node_(12) add-neighbor $node_(13)
set nneighbor(12,2) 13;


#Node 13 routing table
$node_(13) add-neighbor $node_(12)
set nneighbor(13,0) 12;


#Node 14 routing table
$node_(14) add-neighbor $node_(1)
set nneighbor(14,0) 1;


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

