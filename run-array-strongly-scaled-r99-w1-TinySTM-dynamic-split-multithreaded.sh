#!/bin/bash


################################### INIT RAPL ###################################
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

PROGRAM=

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
    cd $PROGRAM
      rm *.o || true
      rm array
    cd ..
    echo "Making $PROGRAM: $global_stm"
    cp backends/$global_stm/Defines.common.mk common/Defines.common.mk
    cp backends/$global_stm/Makefile common/Makefile
    cp backends/$global_stm/tm.h lib/tm.h
    cp backends/$global_stm/thread.h lib/thread.h
    cp backends/$global_stm/thread.c lib/thread.c

    cd $PROGRAM
    # remove redirect 2 to whatever 1 is point to for debug
      make -f Makefile
    cd ..
}



for DISJOINT in 0 1; do
    for th in 2 4 8; do
        
        #stm vars
        RESULTS_DIR="results"
        MAKEFILE="Makefile"
        global_stm="TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded-amd"
        mode=wbetl
        #mode=wbetl-lsa

        PROGRAM='array-strongly-scaled'
        #PROGRAM='array-strongly-scaled-one-large-tx' #DONT RUN - BAD TEST
        #PROGRAM='array-strongly-scaled-all-large-tx'
        PROGRAM_NAME="$PROGRAM-shared-gpu-r99-w1-d$DISJOINT"

        #array walk vars
        #disjoint array segments for all threads: 1-disjoint 0-conjoint
        UPDATE_RATE=20 # lower update rate: more time in validation as you get aborted less often


        #PROGRAM_NAME="$PROGRAM-shared-gpu-r99-w1-d$DISJOINT-RR-kick"

        #PROGRAM_NAME="$PROGRAM-sticky-thread-r$((100-$UPDATE_RATE))-w$UPDATE_RATE-d$DISJOINT" # DONT USE
        #PROGRAM_NAME="$PROGRAM-sticky-thread-r99-w1-d$DISJOINT"

        r_set_start=8192 #gpu will work for sure
        r_set_end=16777216
        N_SAMPLES=10
        SEQ_ENABLED=0 #do both seq and rand: 0..1
        SEQ_ONLY=0

        ######### debug prevents writing to results files #########
        DEBUG=0
        #debug params
        if [[ DEBUG -eq 1 ]]; then
          r_set_start=1048576
          r_set_end=1048576
          #r_set_start=16777216 #gpu will work for sure
          #r_set_end=16777216
          N_SAMPLES=1
          SEQ_ENABLED=0
          SEQ_ONLY=0
        fi

        #if STM-MODE set add it to results dir and Makefile to lookup when compiling with that specific makefile

        #add stm mode to end of it's specific makefile name
        MAKEFILE+="-$mode"
        echo
        echo "Stm makefile is $MAKEFILE."
        echo

        #######################################################################################
        # ONLY for OpenCL iGPU validation
        # change makefile of the selected STM + mode
        if [[ "$global_stm" == *"TinySTM-igpu"* ]]; #check if results dir is cpu or gpu
        then
            # sets compiler define that is read within stm_init() in TinySTM.
            sed -i "s/INITIAL_RS_SVM_BUFFERS_OCL=.*/INITIAL_RS_SVM_BUFFERS_OCL=$th/g" "./$global_stm/$MAKEFILE"
            # this can be moved to run-benches to run only once
            #rm ./$global_stm/src/validation_tool/instant_kernel.bin #remove it on first run then it gets built again
            #rm ./$global_stm/src/validation_tool/regular_kernel.bin #remove it on first run then it gets built again
        fi

        RESULTS_DIR+='-validation-array'
        RESULTS_DIR+="/$global_stm" #every backend has their own results sub-dir

        # example: results/ $global_stm:TinySTM - $4:wbetl
        #######################################################################################
        #if STM-MODE set add it to results dir and Makefile to lookup when compiling with that specific makefile
        if [[ ! -z "$mode" ]]
        then
            #add stm mode to end of dirname
            RESULTS_DIR+="-$mode"
        fi

        #create progout
        progout=

        RESULTS_DIR+="/${th}"

        #################### CREATE RESULTS FILES #############################
        for APP_DIR in "$RESULTS_DIR/$PROGRAM_NAME-random-walk" "$RESULTS_DIR/$PROGRAM_NAME-sequential-walk";
        do
          if [[ ! -d "$APP_DIR" ]]; then
              echo "Results dir \"$APP_DIR\" does not exist, creating."
              mkdir -p "$APP_DIR"
          fi
        done

        # thread number is dir
        # example results/TinySTM-wbetl/2/intruder++
        TEMP_FILE="$RESULTS_DIR/temp"

        for((sequential=$SEQ_ONLY; sequential<=$SEQ_ENABLED;sequential++)); do
            #vary cpu validation percentage

            sed -i "s/SEQUENTIAL=.*/SEQUENTIAL=${sequential}/g" "./$global_stm/$MAKEFILE"

            if [[ $sequential -eq 1 ]];then
                FILE="$RESULTS_DIR/$PROGRAM_NAME-sequential-walk/$th-sequential"
            else
                FILE="$RESULTS_DIR/$PROGRAM_NAME-random-walk/$th-random"
            fi

            #dont write to data-file if debug
            if [[ DEBUG -eq 0 ]]; then
                echo "\"RSET\" \"Validation time (s)\" \"stddev\" \"Validation time (s) CPU\" \"stddev\" \"Validation time (s) GPU\" \"stddev\" \"Commits\" \"stddev\" \"Aborts\" \"stddev\" \"Val Reads\" \"stddev\" \"CPU Val Reads\" \"stddev\" \"GPU Val Reads\" \"stddev\" \"Wasted Val Reads\" \"stddev\" \"GPU employment times\" \"stddev\" \"Val success\" \"stddev\" \"Val fail\" \"stddev\" \"Snapshot ext. calls\" \"stddev\" \"Energy (J)\" \"stddev\" \"Total time (s)\" \"stddev\"" > $FILE
            fi

            for((i=$r_set_start;i<=$r_set_end;i*=2));do

                #adapt RW_SET_SIZE
                sed -i "s/RW_SET_SIZE=.*/RW_SET_SIZE=${i}/g" "./$global_stm/$MAKEFILE"

                #rebuild stm and benchmark
                build_stm_and_benchmark

                echo "\"Validation time(S)\" \"Validation time(S) CPU\" \"Validation time(S) GPU\" \"Commits\" \"Aborts\" \"Val Reads\" \"CPU Val Reads\" \"GPU Val Reads\" \"Wasted Val Reads\" \"GPU employment times\" \"Val success\" \"Val fail\" \"Snapshot ext. calls\" \"Energy (J)\" \"Time(S)\"" > $TEMP_FILE

                sum=0
                avg=0

                for ((k=1;k <= N_SAMPLES;k++)) do

                    if [[ $sequential -eq 1 ]];then
                        echo "RUN:$((k)), $th threads, sequential array walk, disjoint: $DISJOINT, using STM: $global_stm rset:$i"
                    else
                        echo "RUN:$((k)), $th threads, random array walk, disjoint: $DISJOINT, using STM: $global_stm rset:$i"
                    fi

                    # sequential only makes sense with disjoint sets (, or singlethreaded)
                    #./array-strongly-scaled/array -n$th -r$i -s$sequential -u$UPDATE_RATE -d$DISJOINT
                    if [[ $DEBUG -eq 1 ]];then
                      echo "val_time    cpu_v_time  gpu_v_time  C A R C G W G S F E"
                      gdb --args ./$PROGRAM/array -n$th -r$i -s$sequential -u$UPDATE_RATE -d$DISJOINT
                      #./$PROGRAM/array -n$th -r$i -s$sequential -u$UPDATE_RATE -d$DISJOINT
                    else
                      progout=$(./$PROGRAM/array -n$th -r$i -s$sequential -u$UPDATE_RATE -d$DISJOINT) #run the program $( parameters etc )
                      echo "$progout"
                    fi

                    threads_out=$(head -n "$th" <<< "$progout")
                    exec_time_power=($(tail -n 2 <<< "$progout"))

                    # ADD validation times from individual threads = total validation time
                    val_time=$(awk '{ total += $1 } END { printf "%f", total }' <<< "$threads_out")
                    cpu_val_time=$(awk '{ total += $2 } END { printf "%f", total }' <<< "$threads_out")  #no good for anything except co-op
                    gpu_val_time=$(awk '{ total += $3 } END { printf "%f", total }' <<< "$threads_out")  #no good for anything except co-op
                    commits=$(awk '{ total += $4 } END { print total }' <<< "$threads_out")
                    aborts=$(awk '{ total += $5 } END { print total }' <<< "$threads_out")
                    val_reads=$(awk '{ total += $6 } END { print total }' <<< "$threads_out")
                    cpu_val_reads=$(awk '{ total += $7 } END { print total }' <<< "$threads_out")
                    gpu_val_reads=$(awk '{ total += $8 } END { print total }' <<< "$threads_out")
                    waste_val_reads=$(awk '{ total += $9 } END { print total }' <<< "$threads_out")
                    gpu_employment_times=$(awk '{ total += $10 } END { print total }' <<< "$threads_out")
                    validation_succ=$(awk '{ total += $11 } END { print total }' <<< "$threads_out")
                    validation_fail=$(awk '{ total += $12 } END { print total }' <<< "$threads_out")
                    snapshot_extension_calls=$(awk '{ total += $13 } END { print total }' <<< "$threads_out")

                    if [[ "$commits" == "0" || -z "${exec_time_power[0]}" || -z "${exec_time_power[1]}" ]]; then
                    #restart
                      echo "PROGRAM DID NOT RETURN CORRECT VALUES"
                    else
                      echo "${val_time} ${cpu_val_time} ${gpu_val_time} ${commits} ${aborts} ${val_reads} ${cpu_val_reads} ${gpu_val_reads} ${waste_val_reads} ${gpu_employment_times} ${validation_succ} ${snapshot_extension_calls} ${validation_fail} ${exec_time_power[0]} ${exec_time_power[1]}" >> $TEMP_FILE
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
                                    sumsq[j]+=((array[i,j]-(sum[j]/NR))^2);
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

                #echo $mean_stddev_col
                if [[ DEBUG -eq 0 ]]; then
                    echo "$i $mean_stddev_col" >> $FILE
                fi
            done
        done
    done
done