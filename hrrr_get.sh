#!/bin/bash
export PATH=/usr/local/bin:$PATH
export HOME=/home/greg
export UTCDATE=`/usr/bin/date -u +%Y%m%d`
export UTCDATE1=` /usr/bin/date -u -d "-1 hour" +"%Y%m%d"`
export UTCHR=`/usr/bin/date -u +%H`
export CHECKURL="http://www.ftp.ncep.noaa.gov/data/nccf/com/hrrr/prod/hrrr"
#find /home/greg/hrrr_staging/  -not -name "hrrr_staging" -mmin +75 -exec rm -rf {} \;

#Setup HRRR STAGING FOLDERS
export HRRRSTAGING=/home/greg/hrrr_staging/$UTCDATE
/usr/bin/echo $HRRRSTAGING
/usr/bin/mkdir -p $HRRRSTAGING
/usr/bin/echo $UTCDATE

#CHECK NOAA Server using CHECKURL definition for current model run
/usr/bin/curl --fail  $CHECKURL.$UTCDATE/conus/ > $HRRRSTAGING/hrrr.current
FAIL=$?
/usr/bin/echo $FAIL

#CHECK if FAILURE occurs in checking current HRRR model
if [[ "$FAIL" != "0" ]] ; then
	UTCDATE=$UTCDATE1
	HRRRSTAGING=/home/greg/hrrr_staging/$UTCDATE
	/usr/bin/echo $HRRRSTAGING
	/usr/bin/mkdir -p $HRRRSTAGING
	/usr/bin/echo $UTCDATE
	/usr/bin/curl --fail %CHECKURL.$UTCDATE/conus/ > $HRRRSTAGING/hrrr.current
	FAIL2=$?
	if [[ "$FAIL2" != "0" ]] ; then
		/usr/bin/echo "Run Failed - Exiting"
		exit 1
	fi
fi

#LOOP to Determine what grib files have been downloaded already
current=`/usr/bin/grep "wrfsfcf" $HRRRSTAGING/hrrr.current| /usr/bin/grep -i .idx  | /usr/bin/awk 'BEGIN {FS="\""} {print $2}' | tail -1 | /usr/bin/awk 'BEGIN {FS=".idx"} {print $1}';`
/usr/bin/echo $current
currentctl=`/usr/bin/echo $current | /usr/bin/awk 'BEGIN {FS=".grib2"} {print $1}';`
current_time=`/usr/bin/echo $currentctl | /usr/bin/awk 'BEGIN {FS=".wrfsfcf"} {print $2}';`
current_file=`/usr/bin/echo $currentctl | /usr/bin/awk 'BEGIN {FS=".wrfsfcf"} {print $1".wrfsfcf"}';`
HRRRSTAGING=$HRRRSTAGING/$current_file
/usr/bin/echo "HRRRSTAGING: $HRRRSTAGING"
/usr/bin/mkdir -p $HRRRSTAGING
REPTIME=`/usr/bin/echo $current_time| sed 's/^0*//';`
totalit=$(($REPTIME-0))
TOTALTDEF=$totalit
#LOOP to determine what has been downloaded already vs what is still needed
until [  "$totalit" == "-1" ]; do
	totalit2=$(printf "%02d" $totalit)
	/usr/bin/echo "TotalIT2: $totalit2"
	checkfile=`/usr/bin/echo "$current_file""$totalit2"".grib2"`
	/usr/bin/echo "CHECKFILE: $checkfile"
	checkctl=`/usr/bin/echo $checkfile | /usr/bin/awk 'BEGIN {FS=".grib2"} {print $1}';`
	check_time=`/usr/bin/echo $checkctl | /usr/bin/awk 'BEGIN {FS=".wrfsfcf"} {print $2}';`
	/usr/bin/echo "CHECKTIME $check_time"
	SETDOWNLOAD="false"
	if [[ ! -f $HRRRSTAGING/$checkfile ]] ; then
		/usr/bin/echo "CURRENT: $current"

		#DOWNLOAD GRIB 
        	/usr/bin/curl --fail  "http://nomads.ncep.noaa.gov/cgi-bin/filter_hrrr_2d.pl?file=$checkfile&&all_lev=on&var_CFRZR=on&var_CICEP=on&var_CRAIN=on&var_CSNOW=on&var_PRATE=on&var_PRES=on&var_REFC=on&&var_TMP=onvar_UGRD=on&var_VGRD=on&leftlon=0&rightlon=360&toplat=90&bottomlat=-90&dir=%2Fhrrr.$UTCDATE%2Fconus" > $HRRRSTAGING/$checkfile
		STATUS=$?
		/usr/bin/echo "DOWNLOAD COMPLETE"
		#CHECK if CURL RETURNED A good status
        	if [[ "$STATUS" == "0" ]] ; then
			SETDOWNLOAD="true"	

			#CHECK IF GRIB IS VALID AND CLEAN

                	GRIBCHECK=`/usr/local/grads/grib2scan -v $HRRRSTAGING/$checkfile 2>&1| /usr/bin/grep "Record " | /usr/bin/wc -l`
			#IF GRIBCHECK FAILS DELETE GRIB FILE!
                	/usr/bin/echo $GRIBCHECK
                	if [[ "$GRIBCHECK" == "0" ]] ; then
                        	SETDOWNLOAD="false"
                		rm $HRRRSTAGING/$checkfile
                	fi
        	else

                	rm $HRRRSTAGING/$checkfile
        	fi
	fi
        GRIBCHECK=`/usr/local/grads/grib2scan -v $HRRRSTAGING/$checkfile 2>&1| /usr/bin/grep "Record " | /usr/bin/wc -l`
        /usr/bin/echo $GRIBCHECK
        if [[ "$GRIBCHECK" == "0" ]] ; then
        	SETDOWNLOAD="false"
                rm $HRRRSTAGING/$checkfile
        fi
	totalit=$(($totalit-1))
done

#LOOP TO MAKE CTL FILE for HRRR ingestion into grads
 export HRRRGRIB2=`find $HRRRSTAGING -name *wrfsfcf01.grib2`
 tmplname=`echo $HRRRGRIB2|awk 'BEGIN {FS="/"} {print $NF}'| awk 'BEGIN {FS="f01"} {print $1}';`
 tmplnameout=`echo "$tmplname""f%f2.grib2";`
 echo "Template: $tmplnameout"
 /usr/local/bin/g2ctl $HRRRSTAGING/$tmplnameout > $HRRRSTAGING/hrrr.ctl.temp
sed -i 's;tdef 2;tdef '$TOTALTDEF';g' -i $HRRRSTAGING/hrrr.ctl.temp
HRRRFILES=`ls -1 $HRRRSTAGING/*.grib2`
for hrrr in $HRRRFILES
	do
           if [[ ! -f $HRRRSTAGING/$hrrr.idx ]] ; then
           	/usr/local/grads/gribmap -v -i $HRRRSTAGING/hrrr.ctl.temp
           fi
		


	done
mv $HRRRSTAGING/hrrr.ctl.temp $HRRRSTAGING/hrrr.ctl 
