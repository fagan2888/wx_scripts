#!/bin/bash
export PATH=/usr/local/bin:$PATH
export HOME=/home/greg
export UTCDATE=`/usr/bin/date -u +%Y%m%d`
export UTCDATE1=` /usr/bin/date -u -d "-1 hour" +"%Y%m%d"`
export UTCHR=`/usr/bin/date -u +%H`
export CHECKURL="http://www.ftp.ncep.noaa.gov/data/nccf/com/rtma/prod/rtma2p5_ru"
#find /home/greg/rtmaru_staging/  -not -name "rtmaru_staging" -mmin +75 -exec rm -rf {} \;

#Setup RTMA STAGING FOLDERS
export RTMASTAGING=/home/greg/rtmaru_staging/$UTCDATE
/usr/bin/echo $RTMASTAGING
/usr/bin/mkdir -p $RTMASTAGING
/usr/bin/echo $UTCDATE

#CHECK NOAA Server using CHECKURL definition for current model run
/usr/bin/curl --fail  $CHECKURL.$UTCDATE/ > $RTMASTAGING/rtmaru.current
FAIL=$?
/usr/bin/echo $FAIL
#cat $RTMASTAGING/rtmaru.current

#CHECK if FAILURE occurs in checking current RTMA model
if [[ "$FAIL" != "0" ]] ; then
	UTCDATE=$UTCDATE1
	RTMASTAGING=/home/greg/rtmaru_staging/$UTCDATE
	/usr/bin/echo $RTMASTAGING
	/usr/bin/mkdir -p $RTMASTAGING
	/usr/bin/echo $UTCDATE
	/usr/bin/curl --fail $CHECKURL.$UTCDATE/ > $RTMASTAGING/rtmaru.current
	FAIL2=$?
	if [[ "$FAIL2" != "0" ]] ; then
		/usr/bin/echo "Run Failed - Exiting"
		exit 1
	fi
fi

#Determine if grib files have been downloaded already and if valid file
current=`/usr/bin/grep "2dvaranl_ndfd" $RTMASTAGING/rtmaru.current|  /usr/bin/awk 'BEGIN {FS="\""} {print $2}' | tail -1`
/usr/bin/echo $current
current_time=`/usr/bin/echo $current | /usr/bin/awk 'BEGIN {FS="."} {print $2}';`
echo $current_time
RTMASTAGING=$RTMASTAGING/$current_time
/usr/bin/echo "RTMASTAGING: $RTMASTAGING"
/usr/bin/mkdir -p $RTMASTAGING
if [[ ! -f $RTMASTAGING/$current ]] ; then
	/usr/bin/echo "CURRENT: $current"

	#DOWNLOAD GRIB 
	echo "Download $current"
	/usr/bin/curl --fail "$CHECKURL.$UTCDATE/$current" > $RTMASTAGING/$current
	STATUS=$?
	/usr/bin/echo "DOWNLOAD COMPLETE"
	#CHECK if CURL RETURNED A good status
       	if [[ "$STATUS" == "0" ]] ; then
		SETDOWNLOAD="true"	

		#CHECK IF GRIB IS VALID AND CLEAN

               	GRIBCHECK=`/usr/local/grads/grib2scan -v $RTMASTAGING/$current 2>&1| /usr/bin/grep "Record " | /usr/bin/wc -l`
		#IF GRIBCHECK FAILS DELETE GRIB FILE!
               	/usr/bin/echo $GRIBCHECK
               	if [[ "$GRIBCHECK" == "0" ]] ; then
                       	SETDOWNLOAD="false"
               		rm $RTMASTAGING/$current
               	fi
       	else

               	rm $RTMASTAGING/$current
       	fi
fi
GRIBCHECK=`/usr/local/grads/grib2scan -v $RTMASTAGING/$current 2>&1| /usr/bin/grep "Record " | /usr/bin/wc -l`
/usr/bin/echo $GRIBCHECK
if [[ "$GRIBCHECK" == "0" ]] ; then
	SETDOWNLOAD="false"
        rm $RTMASTAGING/$current
fi

#MAKE CTL FILE for RTMA ingestion into grads
export RTMAGRIB2=`find $RTMASTAGING -name *.grb2`
/usr/local/bin/g2ctl $RTMAGRIB2 > $RTMASTAGING/rtmaru.ctl.temp
if [[ ! -f $RTMASTAGING/$rtmaru.idx ]] ; then
	/usr/local/grads/gribmap -v -i $RTMASTAGING/rtmaru.ctl.temp
fi
mv $RTMASTAGING/rtmaru.ctl.temp $RTMASTAGING/rtmaru.ctl 
