#!/bin/bash

# usage example
#                          bench              stm name | mode
# bash run-stamp-choice.sh tpcc  thread_count TinySTM-igpu-persistent wbetl


STAMP_DS_FOLDERS="array"
RESULTS_DIR="results"
MAKEFILE="Makefile"
retries=0
MAX_RETRY=4


################################### needed for rapl ###################################
#remake rapl
cd rapl-power && make clean 2>&1 > /dev/null;
make 2>&1 > /dev/null;
cd ..;

#needed for rapl
if lsmod | grep msr &> /dev/null ; then
  echo "msr is loaded"
else
  echo "loading msr module"
  modprobe msr
fi
#######################################################################################

global_stm="TinySTM"

if [[ -z "$1" ]]
then
  threads=$1
else
  threads=$1
fi

mode="wbetl"
# THREADS
#######################################################################################
# ST
if [[ -z "$global_stm" ]]
then
    echo "Third argument must be an STM (case sensitive): TinySTM, TinySTM-igpu"
    exit;
fi

#if STM-MODE set add it to results dir and Makefile to lookup when compiling with that specific makefile
if [[ ! -z "$mode" ]]
then
    #add stm mode to end of it's specific makefile name
    MAKEFILE+="-$mode"
    echo "Stm makefile is $MAKEFILE."
else
    echo "MUST specify stm mode for makefile"
    exit;
fi


RESULTS_DIR+='-validation-array'
RESULTS_DIR+="/$global_stm" #every backend has their own results sub-dir


if [[ ! -z "$mode" ]]
then
    echo $mode
    #add stm mode to end of dirname
    RESULTS_DIR+="-$mode"
fi

#######################################################################################
build_stm_and_benchmark(){
  # rebuild STM all the time because we change number of threads and I need that to SED the makefile with initial_rs_svm_buffer_size
  # now build stm $global_stm TinySTM, tl2, etc
  cd $global_stm;
  echo "Scanning for $MAKEFILE makefile in $(pwd)"
  echo "Making STM.."
  if [[ -f $MAKEFILE ]]
  then
      if [[ $global_stm =~ "tl2" || $global_stm =~ "norec" || $global_stm =~ "swissTM"  ]]; then
          make -f $MAKEFILE clean 2>&1 > /dev/null;
          make -f $MAKEFILE       2>&1 > /dev/null;
      elif [[ $global_stm =~ "TinySTM" ]]; then
          make -f $MAKEFILE clean 2>&1 > /dev/null;
          make -f $MAKEFILE all 2>&1 > /dev/null;
      fi

      rc=$?
      if [[ $rc != 0 ]] ; then
          echo ""
          echo "BASH: =================================== ERROR making $global_stm using $MAKEFILE ==================================="
          echo ""
          exit 1
      fi
  else
      echo "BASH: Makefile $MAKEFILE does not exist. Go look into STM folder and use that fname"
      exit;
  fi
  echo "done."
  cd ..

  rm lib/*.o || true
  rm common/Defines.common.mk
  rm common/Makefile
  rm lib/tm.h
  rm lib/thread.h
  rm lib/thread.c
  cd array
    rm *.o || true
    rm array
  cd ..
  echo "Making array: $global_stm"
  cp backends/$global_stm/Defines.common.mk common/Defines.common.mk
  cp backends/$global_stm/Makefile common/Makefile
  cp backends/$global_stm/tm.h lib/tm.h
  cp backends/$global_stm/thread.h lib/thread.h
  cp backends/$global_stm/thread.c lib/thread.c

  cd array
  # remove redirect 2 to whatever 1 is point to for debug
    make -f Makefile
  cd ..
}
#######################################################################################

progout=

#always validate at 1 thread
if [[ $threads -eq 1 ]]; then
  RESULTS_DIR+="/${threads}"
else
  RESULTS_DIR+="/${threads}"
fi

#################### RESULTS FILE #############################
for APP_DIR in "$RESULTS_DIR/array-r99-w1-random-walk" "$RESULTS_DIR/array-r99-w1-sequential-walk";
do
  if [[ ! -d "$APP_DIR" ]]; then
      echo "Results dir \"$APP_DIR\" does not exist, creating."
      mkdir -p "$APP_DIR"
  fi
done

# thread number is dir
# example results/TinySTM-wbetl/2/intruder++
TEMP_FILE="$RESULTS_DIR/temp"

build_stm_and_benchmark

for((sequential=0; sequential<=1;sequential++)); do
    #vary cpu validation percentage

    if [[ $sequential -eq 1 ]];then
      FILE="$RESULTS_DIR/array-r99-w1-sequential-walk/$threads-sequential-cpu-validation"
      #FILE="$RESULTS_DIR/array-r99-w1-sequential-walk/$threads-sequential-cpu-validation-debug"
      echo "$FILE"
    else
      FILE="$RESULTS_DIR/array-r99-w1-random-walk/$threads-random-cpu-validation"
      #FILE="$RESULTS_DIR/array-r99-w1-random-walk/$threads-random-cpu-validation-debug"
      echo "$FILE"
    fi

    echo "\"RSET\" \"Validation time (s)\" \"stddev\" \"Commits\" \"stddev\" \"Aborts\" \"stddev\" \"Val Reads\" \"stddev\" \"Val success\" \"stddev\" \"Val fail\" \"stddev\" \"Energy (J)\" \"stddev\" \"Total time (s)\" \"stddev\"" > $FILE

    for((i=512;i<=134217728;i*=2));do

        echo "\"Validation time(S)\" \"Commits\" \"Aborts\" \"Val Reads\" \"Val success\" \"Val fail\" \"Energy (J)\" \"Time(S)\"" > $TEMP_FILE

        sum=0
        avg=0

        for k in {0..30}; do

            if [[ $sequential -eq 1 ]];then
                echo "RUN:$((k+1)), $threads threads, sequential array walk, $global_stm rset:$i"
            else
                echo "RUN:$((k+1)), $threads threads, random array walk, $global_stm rset:$i"
            fi

            #./array/array -n$threads -r$i -s$sequential
            progout=$(./array/array -n$threads -r$i -s$sequential) #run the program $( parameters etc )
            echo "$progout"

            threads_out=$(head -n "$threads" <<< "$progout")
            exec_time_power=($(tail -n 2 <<< "$progout"))

            # ADD validation times from individual threads = total validation time
            val_time=$(awk '{ total += $1 } END { printf "%f", total }' <<< "$threads_out")
            commits=$(awk '{ total += $2 } END { print total }' <<< "$threads_out")
            aborts=$(awk '{ total += $3 } END { print total }' <<< "$threads_out")
            val_reads=$(awk '{ total += $4 } END { print total }' <<< "$threads_out")
            validation_succ=$(awk '{ total += $5 } END { print total }' <<< "$threads_out")
            validation_fail=$(awk '{ total += $6 } END { print total }' <<< "$threads_out")

            if [[ "$commits" == "0" || -z "${exec_time_power[0]}" || -z "${exec_time_power[1]}" ]]; then
            #restart
              echo "PROGRAM DID NOT RETURN CORRECT VALUES"
            else
              echo "${val_time} ${commits} ${aborts} ${val_reads} ${validation_succ} ${validation_fail} ${exec_time_power[0]} ${exec_time_power[1]}" >> $TEMP_FILE
            fi


        done
        #throw mean and stdev into file
        mean_stddev_col=$(awk '
            NR > 1 {
                n=NR-1
                for(i=1;i<=NF;i++){
                    sum[i]+=$i;
                    array[n,i]=$i
                }
            }
            END {
                if(NR>1){
                    NR=NR-1
                    for(i=1;i<=NF;i++){
                        avg[i]=sum[i]/NR;
                    }

                    for(i=1;i<=NR;i++){
                        for(j=1;j<=NF;j++){
                            sumsq[j]+=((array[i,j]-(sum[j]/NR))**2);
                        }
                    }

                    for(i=1;i<=NF;i++){
                        p_avg=avg[i]
                        p_sqrt=sqrt(sumsq[i]/NR)

                        f_avg="%.9f "
                        f_sqrt="%.9f "

                        if(p_avg==0){
                            f_avg="%d "
                        }
                        if(p_sqrt==0){
                            f_sqrt="%d "
                        }
                        #printf "%f %f ", p_avg, p_sqrt;
                        printf f_avg f_sqrt, p_avg, p_sqrt;
                    }
                }
          }
        ' <<< cat "$TEMP_FILE")

        echo "$i $mean_stddev_col" >> $FILE
    done
done