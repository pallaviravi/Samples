BEGIN {
       bytes_recvd = 0;
throughput = 0;
interval = 1;
current_time_instance = 0;
 nxt_time_instance = current_time_instance + interval;
  }
   
  {
             event = $1
             time = $3
             node_id = $9
             pkt_size = $37
             level = $19
   
  # Store start time
#  if (level == "AGT" && pkt_size > 512) {
    if (time < nxt_time_instance){ 
 	 if (event == "r"){
    bytes_recvd = bytes_recvd + pkt_size; 
          }
    }
	else {
	current_time_instance = nxt_time_instance;
	nxt_time_instance += interval;
	throughput = bytes_recvd / current_time_instance;
	printf("%d %d\n",current_time_instance, throughput/1024);
  }
  }
#}
END {   }
