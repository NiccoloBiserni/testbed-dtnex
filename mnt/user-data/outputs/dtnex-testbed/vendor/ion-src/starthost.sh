#!/bin/bash
#stop ion
killm
#remove logs
rm *.log
rm *.csv
rm testf*
rm -R cgr_log
#arp -s 10.0.1.2 00:aa:28:15:07:57
#start ion
ionstart -I hostiondtn2.rc
bprecvfile ipn:5.2 &
#dtnperf_vION --monitor --rt-print --oneCSVonly
#bptrace ipn:5.0 ipn:4.2 ipn:4.0 10 0.0 'pippo' dlv
#dtnperf -d ipn:5.2000 -D200k -P100k -W1 --monitor ipn:3.1000 --debug=2 
