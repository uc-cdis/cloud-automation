#!/bin/bash
CLAMSCANLOG=/var/log/clamscan.log
#Sleep a random time, so we don't lock up everything at once
MAXSLEEP=600
sleep $(($RANDOM%$MAXSLEEP))
clamscan --cross-fs=no -r --no-summary --infected / > $CLAMSCANLOG
