#!/bin/bash

RESULTS_DIR="results-gpu"

mkdir -p "gnuplot"
####################################################################################################################################################

declare -a blue_pallet=("69a2ff" "7dafff" "94bdff" "9cc2ff" "adcdff" "b5d2ff" "bdd7ff")
declare -a grey_pallet=("696969" "808080" "A9A9A9" "C0C0C0" "D3D3D3" "DCDCDC" "696969")
declare -a all_pallet=("33ccff" "ccccff" "009933" "ff9900" "ff6666" "0033cc" "cc0000" "999966")

FILE="gnuplot/simple-array-validation.gnuplot"

echo "set terminal wxt size 3200,1080" > $FILE
#echo "set size 1,1" >> $FILE
#echo "set origin 0,0" >> $FILE
echo "unset bmargin" >> $FILE
echo "unset tmargin" >> $FILE
echo "unset rmargin" >> $FILE
echo "unset lmargin" >> $FILE

echo "set multiplot layout 1,3 title \"Validating random/sequential array traversal, Intel 6700k CPU vs. Intel HD530 iGPU, (TinySTM-WBETL)\" font \",16\"" >> $FILE
echo "set datafile missing '0'" >> $FILE
#echo "unset ytics" >> $FILE
echo "set tics scale 0"  >> $FILE
#echo "set xtics nomirror rotate by 45 right scale 0 font \",8\"" >> $FILE
#echo "unset ytics" >> $FILE
echo "set ytics" >> $FILE
echo "set grid ytics lc rgb \"#606060\"" >> $FILE
#echo "set format y2 \"%0.4f\"" >> $FILE
echo "set logscale y" >> $FILE

echo "set format x \"%d\"" >> $FILE
echo "set xtics nomirror rotate by 45 right font \"Verdana,10\" " >> $FILE
echo "set datafile separator whitespace" >> $FILE

echo "set border lc rgb \"black\"" >> $FILE
#echo "unset border" >> $FILE

echo "set style data linespoints" >> $FILE

#echo "set xlabel \"Read-set size\""  >> $FILE

echo >> $FILE
echo "new = \"-\"" >> $FILE
echo "new1 = \"..\"" >> $FILE
echo "new2 = \"_-_\"" >> $FILE

echo "col_24=\"#c724d6\"" >> $FILE
echo "col_48=\"#44cd1\"" >> $FILE
echo "col_gold=\"#8f8800\"" >> $FILE

echo "set key font \",10\"" >> $FILE
#echo "set key left Left left Left inside top" >> $FILE
echo "set key left" >> $FILE
echo "set yrange [0.0000001:10]" >> $FILE
echo "set ylabel \"Time (s)\""  >> $FILE

#l1
echo  "set arrow from 8.8, graph 0 to 8.8, graph 1 nohead lc rgb \"#efefef\"" >> $FILE
echo  "set label \"\$L1: 128KB\" at 8.9,0.00000014 " >> $FILE
#intelhd l3
echo  "set arrow from 10.8, graph 0 to 10.8, graph 1 nohead lc rgb \"#dadada\"" >> $FILE
echo  "set label \"\L3 GPU: 512KB\" at 10.9,0.00000014*2.5 " >> $FILE
#l2
echo  "set arrow from 11.8, graph 0 to 11.8, graph 1 nohead lc rgb \"#bebebe\"" >> $FILE
echo  "set label \"\$L2: 1.024MB\" at 11.9,0.00000014*1.5 " >> $FILE
#l3
echo  "set arrow from 14.8, graph 0 to 14.8, graph 1 nohead lc rgb \"#afafaf\"" >> $FILE
echo  "set label \"\$L3: 8MB\" at 14.9,0.00000014*2.5 " >> $FILE
echo  "set title \"Only CPU, threaded validation, sequential walk\" font \",12\"" >> $FILE

#echo  "plot \\"  >> $FILE
#normal execution

echo "set title \"CPU with threads + GPU Persistent Kernel threads \" font \",12\"" >> $FILE
echo  "plot \\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-GPU-NAIVE-CALL-KERNEL-EVERYTIME'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 24WKGPS-224WKGPSIZE-SEQ-CST , random array traversal\" lw 2 lc rgb \"#3cde33\" pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-24WKGP-224WKGPSIZE' u 3:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"24WKGPs 224WI/WKGP NO VALIDATION LOGIC, JUST POLL\" dt new lc rgb col_24 pt 8,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-GPU-24WKGPS-224WKGPSIZE-SEQ-CST'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 24WKGPS-224WKGPSIZE-SEQ-CST , random array traversal\" lw 1 lc rgb col_24 pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-GPU-24WKGPS-224WKGPSIZE-ACQ-REL'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 24WKGPS-224WKGPSIZE-ACQ-REL , random array traversal\" dt new lw 1 lc rgb col_24 pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-GPU-24WKGPS-224WKGPSIZE-RELAXED'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 24WKGPS-128WKGPSIZE-RELAXED, random array traversal\" dt new1 lw 1 lc rgb col_24 pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-GPU-48WKGPS-128WKGPSIZE-SEQ-CST'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 48WKGPS-128WKGPSIZE-SEQ-CST , random array traversal\" lw 1 lc rgb col_48 pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-GPU-48WKGPS-128WKGPSIZE-ACQ-REL'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 48WKGPS-128WKGPSIZE-ACQ-REL , random array traversal\" dt new lw 1 lc rgb col_48 pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-16THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"CPU 02 16 THREADS VALIDATING random array traversal\" dt new lc rgb \"black\" pt 7,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-8THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"CPU 02 8 THREADS VALIDATING random array traversal\" lc rgb \"black\" pt 7,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-4THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"CPU 02 4 THREADS VALIDATING random array traversal\" dt new1 lc rgb \"black\" pt 7,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-1THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"CPU 02 1 THREADS VALIDATING random array traversal\" lc rgb col_gold pt 17,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-CPU-O2-1THREADS-VALIDATING'u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"CPU 02 1 THREADS VALIDATING sequential array traversal\" dt new lc rgb col_gold pt 17,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-GPU-48WKGPS-128WKGPSIZE-SEQ-CST'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 48WKGPS-128WKGPSIZE-SEQ-CST, sequential array traversal\" lw 2 lc rgb col_48 pt 16,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-GPU-24WKGPS-224WKGPSIZE-SEQ-CST'    u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"Persistent Kernel 24WKGPS-224WKGPSIZE-SEQ-CST, sequential array traversal\" lw 2 lc rgb col_24 pt 16"  >> $FILE

#CPU l2 1.02400 megabytes
#CPU l1 128 KB
echo "set title \"CPU with threaded validation \" font \",12\"" >> $FILE
echo  "plot \\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-16THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"random walk CPU 02 16 THREADS VALIDATING\" dt new lc rgb \"black\" pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-8THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"random walk CPU 02   8 THREADS VALIDATING\" lc rgb \"black\" pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-4THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"random walk CPU 02   4 THREADS VALIDATING\" dt new1 lc rgb \"black\" pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-random-CPU-O2-1THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"random walk CPU 02   1 THREADS VALIDATING\" lw 2 lc rgb \"black\" pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-CPU-O2-16THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"sequential walk CPU O2 16 THREADS VALIDATING\" dt new lc rgb col_gold pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-CPU-O2-8THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"sequential walk CPU O2   8 THREADS VALIDATING\" lc rgb col_gold pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-CPU-O2-4THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"sequential walk CPU O2   4 THREADS VALIDATING\" dt new1 lc rgb col_gold pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-sequential-CPU-O2-1THREADS-VALIDATING' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t \"sequential walk CPU O2   1 THREADS VALIDATING\" lw 2 dt new lc rgb col_gold pt 1"  >> $FILE

#atomics
echo "set yrange [0.0000001:0.0001]" >> $FILE
echo "set title \"GPU C11 ATOMICS MEMORY ORDER COMPARISON + DIFFERENT GPU OCCUPANCY \" font \",12\"" >> $FILE
echo  "plot \\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-48WKGP-128WKGPSIZE' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t col lw 2 lc rgb col_48 pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-48WKGP-128WKGPSIZE' u 3:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t col dt new lc rgb col_48 pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-48WKGP-128WKGPSIZE' u 4:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t col dt new1 lc rgb col_48 pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-24WKGP-224WKGPSIZE' u 2:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t col lw 2 lc rgb col_24 pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-24WKGP-224WKGPSIZE' u 3:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t col dt new lc rgb col_24 pt 1,\\"  >> $FILE
echo  " '$RESULTS_DIR/1a-array-r99-w1-ATOMICS-POLLING-OVERHEAD-PT-24WKGP-224WKGPSIZE' u 4:xtic(sprintf(\"%d/ %.2fMB\",\$1, (\$1*8)/1000000)) t col dt new1 lc rgb col_24 pt 1"  >> $FILE

echo >> $FILE

echo  "unset multiplot" >> $FILE


gnuplot -p $FILE





