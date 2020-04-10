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
if lsmod | grep msr &> /dev/null ; then
  echo "msr is loaded"
else
  echo "loading msr module"
  modprobe msr
fi
#######################################################################################

global_stm=$1
threads=1

# THREADS
#######################################################################################
# ST
if [[ -z "$global_stm" ]]
then
    echo "Third argument must be an STM (case sensitive): TinySTM, TinySTM-igpu"
fi

#if STM-MODE set add it to results dir and Makefile to lookup when compiling with that specific makefile
if [[ ! -z "$2" ]]
then
    #add stm mode to end of it's specific makefile name
    MAKEFILE+="-$2"
    echo "Stm makefile is $MAKEFILE."
fi

#######################################################################################
#change makefile of the selected STM + mode only for OpenCL igpu validation
#check if results dir is cpu or gpu

if [[ "$global_stm" == *"TinySTM-igpu"* ]];
then
    # sets compiler define that is read within stm_init() in TinySTM.
    sed -i "s/INITIAL_RS_SVM_BUFFERS_OCL=.*/INITIAL_RS_SVM_BUFFERS_OCL=$threads/g" "./$global_stm/$MAKEFILE"
    # this can be moved to run-benches to run only once
    rm ./$global_stm/src/validation_tool/instant_kernel.bin #remove it on first run then it gets built again
    rm ./$global_stm/src/validation_tool/regular_kernel.bin #remove it on first run then it gets built again
    RESULTS_DIR+='-validation-proportion'
fi


RESULTS_DIR+="/$global_stm" #every backend has their own results sub-dir

# example: results/ $global_stm:TinySTM - $4:wbetl
#######################################################################################
#if STM-MODE set add it to results dir and Makefile to lookup when compiling with that specific makefile
if [[ ! -z "$2" ]]
then
    echo $2
    #add stm mode to end of dirname
    RESULTS_DIR+="-$2"
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
RESULTS_DIR+="/$threads"
#################### RESULTS FILE #############################
if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "Results dir \"$RESULTS_DIR\" does not exist, creating."
    mkdir -p "$RESULTS_DIR"
fi

# thread number is dir
# example results/TinySTM-wbetl/2/intruder++
TEMP_FILE="$RESULTS_DIR/temp"

for((sequential=0; sequential<=1;sequential++)); do
  #vary cpu validation percentage
  for((j=32; j<=100; j++)); do


    #CPU validation proportion set and recompile
    sed -i "s/CPU_VALIDATION_PROPORTION=.*/CPU_VALIDATION_PROPORTION=$j/g" "./$global_stm/$MAKEFILE"

    build_stm_and_benchmark

    if [[ $sequential -eq 1 ]];then
      FILE="$RESULTS_DIR/1-sequential-cpu-$j-gpu-$((100-$j))"
    else
      FILE="$RESULTS_DIR/1-random-cpu-$j-gpu-$((100-$j))"
    fi

    #create master file with all rset sizes
    echo "\"RSET\" \"Validation time (s)\" \"stddev\" \"Validation time (s) CPU\" \"stddev\" \"Validation time (s) GPU\" \"stddev\" \"Commits\" \"stddev\" \"Aborts\" \"stddev\" \"Val Reads\" \"stddev\" \"Val success\" \"stddev\" \"Val fail\" \"stddev\" \"Energy (J)\" \"stddev\" \"Total time (s)\" \"stddev\"" > $FILE

    for((i=512;i<=134217728;i*=2));do

      #create temp file for stddev and avg
      echo "\"Validation time(S)\" \"Validation time(S) CPU\" \"Validation time(S) GPU\" \"Commits\" \"Aborts\" \"Val Reads\" \"Val success\" \"Val fail\" \"Energy (J)\" \"Time(S)\"" > $TEMP_FILE

      sum=0
      avg=0

      for k in {0..9}; do

        if [[ $sequential -eq 1 ]];then
          echo "RUN:$((k+1)), 1 thread, sequential array walk, $global_stm rset:$i CPU_VAL_PROPORTION:$j"
        else
          echo "RUN:$((k+1)), 1 thread, random array walk, $global_stm rset:$i CPU_VAL_PROPORTION:$j"
        fi

        #./array/array -n$threads -r$i -s$sequential
        progout=$(./array/array -n$threads -r$i -s$sequential) #run the program $( parameters etc )
        echo "$progout"

        threads_out=$(head -n "$threads" <<< "$progout")
        exec_time_power=($(tail -n 2 <<< "$progout"))
        # ADD validation times from individual threads = total validation time
        val_time=$(awk '{ total += $1 } END { printf "%f", total }' <<< "$threads_out")
        cpu_val_time=$(awk '{ total += $2 } END { printf "%f", total }' <<< "$threads_out")
        gpu_val_time=$(awk '{ total += $3 } END { printf "%f", total }' <<< "$threads_out")
        commits=$(awk '{ total += $4 } END { print total }' <<< "$threads_out")
        aborts=$(awk '{ total += $5 } END { print total }' <<< "$threads_out")
        val_reads=$(awk '{ total += $6 } END { print total }' <<< "$threads_out")
        validation_succ=$(awk '{ total += $7 } END { print total }' <<< "$threads_out")
        validation_fail=$(awk '{ total += $8 } END { print total }' <<< "$threads_out")

        echo "${val_time} ${cpu_val_time} ${gpu_val_time} ${commits} ${aborts} ${val_reads} ${validation_succ} ${validation_fail} ${exec_time_power[0]} ${exec_time_power[1]}" >> $TEMP_FILE

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

                    f_avg="%f "
                    f_sqrt="%f "

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
done
