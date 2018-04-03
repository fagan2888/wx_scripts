#!/bin/bash
export PATH=/usr/local/bin:$PATH
export HOME=/home/greg
export UTCDATE=`/usr/bin/date -u +%Y%m%d`
export UTCDATE1=` /usr/bin/date -u -d "-1 hour" +"%Y%m%d"`
export UTCHR=`/usr/bin/date -u +%H`
export CHECKURL="http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod"
#find /home/greg/gfs_staging/  -not -name "gfs_staging" -mmin +75 -exec rm -rf {} \;

#Setup GFS STAGING FOLDERS
export GFSSTAGING=/home/greg/gfs_staging/$UTCDATE
/usr/bin/echo $GFSSTAGING
/usr/bin/mkdir -p $GFSSTAGING
/usr/bin/echo $UTCDATE

#CHECK NOAA Server using CHECKURL definition for current model run
echo $CHECKURL
echo $UTCDATE
CURRENTGFS=`/usr/bin/curl --fail  $CHECKURL/ | grep gfs.$UTCDATE | tail -1 | awk 'BEGIN {FS=">"} {print $2}'| awk 'BEGIN {FS="/"} {print $1}';`
echo "GFSCURRENT: $CURRENTGFS"
/usr/bin/curl --fail -L $CHECKURL/$CURRENTGFS > $GFSSTAGING/gfs.current
FAIL=$?
/usr/bin/echo $FAIL

#CHECK if FAILURE occurs in checking current GFS model
if [[ "$FAIL" != "0" ]] ; then
	UTCDATE=$UTCDATE1
	GFSSTAGING=/home/greg/gfs_staging/$UTCDATE
	/usr/bin/echo $GFSSTAGING
	/usr/bin/mkdir -p $GFSSTAGING
	/usr/bin/echo $UTCDATE
	/usr/bin/curl --fail %CHECKURL.$UTCDATE/ > $GFSSTAGING/gfs.current
	FAIL2=$?
	if [[ "$FAIL2" != "0" ]] ; then
		/usr/bin/echo "Run Failed - Exiting"
		exit 1
	fi
fi

#LOOP to Determine what grib files have been downloaded already
current=`/usr/bin/grep ".0p25.f" $GFSSTAGING/gfs.current| /usr/bin/grep -vi .idx  | /usr/bin/awk 'BEGIN {FS="\""} {print $2}' | tail -1 | /usr/bin/awk 'BEGIN {FS=".idx"} {print $1}';`
/usr/bin/echo "CURRENT FILE: $current"
currentctl=`/usr/bin/echo $current | /usr/bin/awk 'BEGIN {FS=".grib2"} {print $1}';`
current_time=`/usr/bin/echo $currentctl | /usr/bin/awk 'BEGIN {FS=".0p25"} {print $2}';`
current_file=`/usr/bin/echo $currentctl | /usr/bin/awk 'BEGIN {FS=".0p25"} {print $1".0p25"}';`
GFSSTAGING=$GFSSTAGING/$current_file
/usr/bin/echo "GFSSTAGING: $GFSSTAGING"
/usr/bin/mkdir -p $GFSSTAGING
REPTIME=`/usr/bin/echo $current_time| sed 's/^.f*//';`
echo "REPTIME: $REPTIME"
totalit=$(($REPTIME-0))
TOTALTDEF=$totalit
#LOOP to determine what has been downloaded already vs what is still needed
until [  "$totalit" == "-1" ]; do
	totalit2=$(printf "%03d" $totalit)
	/usr/bin/echo "TotalIT2: $totalit2"
	checkfile=`/usr/bin/echo "$current_file".f"$totalit2"| sed 's;pgrb2b;pgrb2;g';`
	/usr/bin/echo "CHECKFILE: $checkfile"
	checkctl=`/usr/bin/echo $checkfile | /usr/bin/awk 'BEGIN {FS=".idx"} {print $1}';`
	check_time=`/usr/bin/echo $checkctl | /usr/bin/awk 'BEGIN {FS=".0p25."} {print $2}';`
	/usr/bin/echo "CHECKTIME $check_time"
	SETDOWNLOAD="false"
	if [[ ! -f $GFSSTAGING/$checkfile ]] ; then
		/usr/bin/echo "CURRENT: $current"

		#DOWNLOAD GRIB 
        	/usr/bin/curl --fail "http://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25_1hr.pl?file=$checkfile&lev_0C_isotherm=on&lev_200_mb=on&lev_250_mb=on&lev_500_mb=on&lev_2_m_above_ground=on&lev_850_mb=on&lev_mean_sea_level=on&lev_surface=on&var_ACPCP=on&var_APCP=on&var_CAPE=on&var_CFRZR=on&var_CICEP=on&var_CRAIN=on&var_CSNOW=on&var_DPT=on&var_GUST=on&var_PRATE=on&var_PRMSL=on&var_SNOD=on&var_TMP=on&var_UGRD=on&var_VGRD=on&subregion=&leftlon=-135&rightlon=-55&toplat=57&bottomlat=8&dir=%2F$CURRENTGFS" > $GFSSTAGING/$current > $GFSSTAGING/$checkfile
		STATUS=$?
		/usr/bin/echo "DOWNLOAD COMPLETE"
		#CHECK if CURL RETURNED A good status
        	if [[ "$STATUS" == "0" ]] ; then
			SETDOWNLOAD="true"	

			#CHECK IF GRIB IS VALID AND CLEAN

                	GRIBCHECK=`/usr/local/grads/grib2scan -v $GFSSTAGING/$checkfile 2>&1| /usr/bin/grep "Record " | /usr/bin/wc -l`
			#IF GRIBCHECK FAILS DELETE GRIB FILE!
                	/usr/bin/echo $GRIBCHECK
                	if [[ "$GRIBCHECK" == "0" ]] ; then
                        	SETDOWNLOAD="false"
                		rm $GFSSTAGING/$checkfile
                	fi
        	else

                	rm $GFSSTAGING/$checkfile
        	fi
	fi
        GRIBCHECK=`/usr/local/grads/grib2scan -v $GFSSTAGING/$checkfile 2>&1| /usr/bin/grep "Record " | /usr/bin/wc -l`
        /usr/bin/echo $GRIBCHECK
        if [[ "$GRIBCHECK" == "0" ]] ; then
        	SETDOWNLOAD="false"
                rm $GFSSTAGING/$checkfile
        fi
	if [ $totalit -gt 220 ] ; then
		totalit=$(($totalit-12))
	elif [ $totalit -gt 120 ] ; then
		totalit=$(($totalit-3))
	else 
		totalit=$(($totalit-1))	
	fi
done

#LOOP TO MAKE CTL FILE for GFS ingestion into grads
 export GFSGRIB2=`find $GFSSTAGING -name *.0p25.f001`
 echo "GFS GRIB2: $GFSGRIB2"
 tmplname=`echo $GFSGRIB2|awk 'BEGIN {FS="/"} {print $NF}'| awk 'BEGIN {FS=".f001"} {print $1}';`
 echo "GFS TEMPLATENAME: $tmplname"
 tmplnameout=`echo "$tmplname"".f%f3";`
 echo "Template: $tmplnameout"
 /usr/local/bin/g2ctl $GFSSTAGING/$tmplnameout > $GFSSTAGING/gfs.ctl.temp
sed -i 's;tdef 2;tdef '$TOTALTDEF';g' -i $GFSSTAGING/gfs.ctl.temp
GFSFILES=`find $GFSSTAGING -name \*.f\* ! -name \*.f\*.idx`
for gfs in $GFSFILES
	do
           if [[ ! -f $GFSSTAGING/$gfs.idx ]] ; then
           	/usr/local/grads/gribmap -v -i $GFSSTAGING/gfs.ctl.temp
           fi
		


	done
mv $GFSSTAGING/gfs.ctl.temp $GFSSTAGING/gfs.ctl 
