#!/bin/bash

function usage { echo "Usage: ./showdata.sh  dirname/show/showarrays <triggers/filename> <all/ae>" ; exit ; }
#
# This script will invoke sortvdata.pl to determine
# whether or not to kick the video snippet as not
# applicable depending upon the current algorithm
# used in sortvdata.pl.
#
# Using a directory for an argument it will run
# through all mp4 snippets in that directory and
# output a filename for further processing.
#
# The show argument takes a script generated filename
# and interactively shows data generated by sortvdata.pl 
# along with three trigger shots in the feh image viewer.
#
# showarrays argument will specify a single video instance
# file to have its data and trigger shots shown.  Example
# usage:
#
# ./showdata.sh showarrays xyz.mp4
#
# The filename of course needs to have proper index attributes
# which are needed to search the arrays directory.
#
# triggers argument will step through the directory
# bringing up feh before moving files.
#
# all argument at the end will show the entire change matrix
# for debugging purposes.

# this script can't be run from foreign directory
# and must use relative subdirectory paths

BASE="/home/mea/cams/camera6" ;
#ADIR="/home/mea/arrays" ;
ADIR="$BASE/arrays" ;
#snapdir=./mysnap ;
alarmpre="MDAlarm" ;
mydate=$(date +%m%d%H%M%S)
action="none"
KICKED="$BASE/kicked" ;
SORTVDATA="$BASE/bin/sortvdata.pl" ;
LOG="/home/mea/cams/cron.log" ;
LOGTXT="$mydate showdata.sh" ;


if [ ! -d $KICKED ] ; then echo "making $KICKED" ; mkdir $KICKED ; fi
if [ ! -d $KICKED ] ; then echo "no $KICKED ... exiting" ; exit ; fi
if [ ! -d "$KICKED/snaps" ] ; then mkdir "$KICKED/snaps" ; fi
if [ ! -d $ADIR ] ; then echo "making $ADIR" ; mkdir $ADIR ; fi
if [ ! -d $ADIR ] ; then echo "no $ADIR ... exiting" ; exit ; fi

if [ ! -z $2 ] ; then action=$2 ; fi
if [ ! -z $3 ] ; then action2=$3 ; fi
if [ ! -z $4 ] ; then action2=$4 ; fi

if [ -z $1 ] ; then echo "Usage: ./showdata.sh dirname" ; exit ; fi

myfiles="" ; # this is used to store groups of files for
	     # invoking feh, the image viewer
if [ $1 != "show" ] && [ $1 != "showarrays" ] ; then
#	targetdir=$(echo $(basename $myfile) | awk 'BEGIN{FS="_"}{print $1"/"$2}' ) ;
	# dirname should be correct when it's first arg
	dirname=$1 ;
	snapdir=$dirname/snaps ;
	if [ ! -d $snapdir ] ; then echo "can't find $snapdir" ; exit ; fi
fi

function findjpegs {
	if [ ! -z $2 ] ; then
		xfile=$2 ;
#echo "xfile $xfile" ; exit ;
	        seqnum=$(echo $xfile | sed -e "s/\.mp4//" ) ;
     		myyear=${seqnum:0:4} ;
       		mymonth=${seqnum:4:2} ;
        	myday=${seqnum:6:2} ;
        	mydate=${seqnum:0:8} ;
        	myhour=${seqnum:9:2}  ;
        	mymin=${seqnum:11:2}  ;
        	mysec=${seqnum:13:2}  ;
        	myhms=${seqnum:9:6}  ;
        	myepoch=$( date --date "$mymonth/$myday/$myyear $myhour:$mymin:$mysec"  +%s  ) ;
	fi
	myJPEGREPO=$1  ;
        xmysec=$mysec ;
        loop="yes"  ;
        found=0 ; # keeps track of loop below
# now we have to find the jpegs
        while [ $loop == "yes" ] ;
        do
                # reconstruct sequence
                jseqnum=$( echo $myepoch | awk '{print strftime("%Y%m%d_%H%M%S",$1) }'  ) ;
#echo "jseqnum=$jseqnum" ;
#echo "jseqnum is $jseqnum" ; exit ;

                if [ ! -d $myJPEGREPO ] ; then 
			echo "$LOGTXT no jpeg repo $myJPEGREPO ... fix this!" >> $LOG ; exit ; 
		fi
                jpgfname="$myJPEGREPO/${jseqnum}.jpg" ;
                if [ -e $jpgfname ] ; then # it's a hit
                        # try and get all three snaps
                        # this is hard coded for now
                        found=0 ;
                        myjpegs=$jpgfname ;
                        myjpeg_array[0]=$jpgfname ;
                        arrayindex=1 ;
                        loop="no" ;
                        let endepoch=$myepoch+2 ;
                        let startepoch=$myepoch+1 ;
                        seq_epoch=$startepoch ;
                        jpegloop="yes" ;

                        # the below loop will pick up the rest of the snapshots
                        # in sequence.  myjpegs was already populated with the
                        # trigger above.
                        while [ $jpegloop == "yes" ] ;
                        do
                                jseqnum=$( echo $seq_epoch | awk '{print strftime("%Y%m%d_%H%M%S",$1) }'  ) ;
                                jpgfname="$myJPEGREPO/${jseqnum}.jpg" ;
                                if [  -e $jpgfname ] ; then # it's a hit
                                        myjpegs="$myjpegs $jpgfname" ;
                                        myjpeg_array[$arrayindex]=$jpgfname ;
                                        let arrayindex=$arrayindex+1 ;
                                else jpegloop="no" ; # it's not a hit let's get out of here
                                fi
                                let seq_epoch=$seq_epoch+1 ;
                        done
                fi    
                let myepoch=$myepoch+1 ;
                let found=$found+1 ;
                if [ $found -gt 9 ] ; then myjpegs="" ; loop="no" ; fi
        done # end of loop=
}

# test


if [ $1 == "show" ] ; then # just show data and nothing else
	# second arg is the filename, let's parse it
	# and get out of here
	if [ ! -z $2 ] ; then myfile=$2 ; 
	else echo "missing second arg" ;  exit ;
	fi
#	targetdir=$(echo $(basename $myfile) | awk 'BEGIN{FS="_"}{print $1"/"$2}' ) ;
	xtargetdir=$(grep ^file $myfile | head -1  | awk '{print $2}'  ) ;
	targetdir=$(dirname $xtargetdir ) ;
	snapdir=$targetdir/snaps ;
	if [ ! -d $snapdir ] ; then echo "no snapdir $snapdir ... fix this" ; exit ; fi
	action="show" ;
	if [ ! -e $myfile ] ; then echo "no $myfile ... exiting" ; exit ; fi
	# now that it's there let's read it
	showindex=0 ;
	showdate=0 ;
	myfindex=1 ;
	# first let's make a menu
	if [ -e "filelist.dat" ] ; then rm filelist.dat ; fi
	while read indata1 indata2 indata3
	do
		if [ "$indata1" == "file" ] ; then
			echo "$myfindex $indata2" >> filelist.dat ;
			let myfindex=$myfindex+1 ;
		fi
	done < $myfile
	if [ -e filelist.dat ] ; then cat "filelist.dat" ; 
	else echo "nothing in filelist.dat" ; exit ;
	fi
	echo "enter startnum (default = 1)" ;
	read INPUT
	if [ -z $INPUT ] ; then
		mystart=1 ;
	elif [ $INPUT == "q" ] ; then
		echo "quitting ..." ; exit ;
	elif [[ $INPUT =~ ^[0-9]+$ ]] ; then
		mystart=$INPUT ;
#echo $mystart ; exit ;
	else
		echo "bad input $INPUT" ; exit ;
	fi
	myfindex=1 ;
	skip=1 ; # 1 = skip, 0 = don't skip
	kicked=0 ;
	while read indata1 indata2 indata3
	do
		if [ $myfindex -lt $mystart ] ; then
#echo "got here $myfindex $mystart" ;
#echo "indata2 is $indata2" ;
			if [ $indata1 == "index" ] ; then
				let myfindex=$myfindex+1 ;
			fi
			continue ;
		else
			skip=0 ;
		fi
		# skip the rest of irrelevant file data until
		# we hit the proper index
		if [ $skip -eq 1 ] ; then continue ; fi
		if [ "$indata1" == "index" ] ; then
			showdate=$indata2 ;
			showindex=$indata3 ;
			echo "date $showdate $showindex" ;
		elif [ "$indata1" == "file" ] ; then
			mp4file=$(basename $indata2) ;
			echo "$indata1 $indata2 $indata3" ;
echo "mp4file $mp4file" ;
		elif [ "$indata1" == "kicked" ] ; then
			echo $indata1 ;
			kicked=1 ;
		elif [ "$indata1" == "reason:" ] ; then
			echo "$indata1 $indata2 $indata3" ;
		elif [ "$indata1" == "end" ] ; then
#			if [ $kicked == 1 ] ; then 
#				findjpegs $KICKED/snaps $mp4file;
#			else findjpegs $snapdir $mp4file  ;
#			fi
			findjpegs $snapdir $mp4file  ; # debug
#echo "snapdir $snapdir myjpegs $myjpegs mp4file $mp4file seqnum $seqnum kicked $kicked myepoch $myepoch" ; exit ;
			kicked=0 ;
			if [ ! -z "$myjpegs" ] ; then feh $myjpegs  ; fi
		else 
			echo "$indata1 $indata2 $indata3" ;
		fi
	done < $myfile
	exit ; # we're done with this script at this point
elif [ $1 == "showarrays" ] ; then action=$1
elif [ ! -d $dirname ] ; then
	echo "$dirname does not exist" ; exit ;
fi


if [ $action == "showarrays" ] ; then
	if [ -z $2 ] ; then
		echo "no filename selected in arg 2" ; exit ;
	fi
	floop=$2 ; 
else
	floop=$(ls -tr $dirname/*.mp4) ;
fi

if [ -z "$floop" ] ; then echo "no mp4 files in $dirname" ; exit ;  fi

for file in $floop 
do
	xfile=$(basename $file) ;
	mynum=${xfile:0:15} ;
#	mynum=${mynum/_/-} ;
	global_mynum=$mynum ;
	xmyindex=$(echo $mynum | awk 'BEGIN{FS="_"}{print $2}') ;
	mydatex=$(echo $mynum | awk 'BEGIN{FS="_"}{print $1}') ;

        seqnum=$(echo $xfile | sed -e "s/\.mp4//" ) ;
        myyear=${seqnum:0:4} ;
        mymonth=${seqnum:4:2} ;
        myday=${seqnum:6:2} ;
        mydate=${seqnum:0:8} ;
        myhour=${seqnum:9:2}  ;
        mymin=${seqnum:11:2}  ;
        mysec=${seqnum:13:2}  ;
        myhms=${seqnum:9:6}  ;
        myepoch=$( date --date "$mymonth/$myday/$myyear $myhour:$mymin:$mysec"  +%s  ) ;
	# let's make myjpegs
	findjpegs $snapdir ;
#echo "seqnum $seqnum myjpegs -- $myjpegs"  ;  continue ;
	

	nozeros=$(echo $xmyindex | sed 's/^0*//')
	echo "index $mydatex $nozeros" ;
#echo "nozeros is $nozeros" ; exit ;

	subaction="none" ;
	echo "file $file $mynum" ;

	idir=$ADIR/$global_mynum ;
	if [ ! -d $ADIR/$global_mynum ] ; then
		echo "no $idir ... exiting" ;  continue ;
	fi
	sdir=$idir/$xmyindex ;
#echo "n1 data" ;
#awk 'BEGIN{count=1}{print count" "$0 ; count++}'   $idir/n1_visual.dat
#echo "n2 data" ;
#awk 'BEGIN{count=1}{print count" "$0 ; count++}'   $idir/n2_visual.dat
# exit ;
	if [ ! -e $idir/n1.dat ] || [ ! -e $idir/n2.dat ] ; then
		echo "no n1 or n2.dat files" ; exit ;
	fi
	echo "n1 data" > $BASE/tmp.dat ;
	cat $idir/n1.dat >> $BASE/tmp.dat ;
	echo "n2 data" >> $BASE/tmp.dat ;
	cat $idir/n2.dat >> $BASE/tmp.dat ;

#	if [[ $action2 == "ae" ]] ; then
#		cat tmp.dat | $SORTVDATA  ae > tmp1.dat ;
#	else
#		cat tmp.dat | $SORTVDATA   > tmp1.dat ;
#	fi

	cat $BASE/tmp.dat | $SORTVDATA   > $BASE/tmp1.dat ;
	while read mydata therest
	do
		echo "$mydata $therest" ;
		if [ "$mydata" == "kicked" ] && [ $action != "showarrays" ] ; then
			echo "mv $file $KICKED" ;
			for file3 in $myjpegs 
			do
				echo "mv -n $file3 $KICKED/snaps" ;
			done
		fi
	done < $BASE/tmp1.dat ;
	if [[ $action2 == "ae" ]] && [ -e $idir/n1_ae.dat ] ; then
		echo "n1 data" > $BASE/tmp.dat ;
		cat $idir/n1_ae.dat >> $BASE/tmp.dat ;
		echo "n2 data" >> $BASE/tmp.dat ;
		cat $idir/n2_ae.dat >> $BASE/tmp.dat ;
		cat $BASE/tmp.dat | $SORTVDATA     ae > $BASE/tmp1.dat ;
		echo "------------AE DATA--------------" ;
		while read mydata therest
		do
			echo "$mydata $therest" ;
		done < $BASE/tmp1.dat ;
	fi
	if [[ $action2 == "all" ]] || [ $action == "all" ] ; then
		echo "n1 data------------------------------------------" ;
		cat $idir/n1_visual.dat | awk 'BEGIN{count=1}{print count" "$0;count++}' ;
		echo "n2 data------------------------------------------" ;
		cat $idir/n2_visual.dat  | awk 'BEGIN{count=1}{print count" "$0;count++}'  ;
	fi
	# show the 3 triggers in feh
	if [ $action == "triggers" ] || [ $action == "showarrays" ] || [ $action == "show" ] ; then
	   for (( c=0 ; c<=2 ; c++ ))
	   do

		let lindex=$nozeros+$c ;
		myindex=$(printf "%06d" $lindex) ;
		mynum=${mydatex}-${myindex} ;
		myfile="$snapdir/${alarmpre}_${mynum}.jpg" ;
		myfiles="$myfiles $myfile" ;
	   done
	   feh $myfiles ; # this is blocking until user exits feh
	fi
done