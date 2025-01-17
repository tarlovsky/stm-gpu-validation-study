
set terminal wxt size 1440,1080
set decimal locale "en_US.UTF-8"; show locale
set key inside top right font "Computer Modern, 15"
set datafile separator whitespace
set border lc rgb "black"
set xtics font "Computer Modern,18" offset 1,-1,0
set ytics font "Computer Modern,24" 
set ztics font "Computer Modern,28" 
set xlabel "READ-SET SIZE" font "Computer Modern, 22" offset graph 0,0,-0.04
set ylabel "CPU %" font "Computer Modern, 25" offset graph 0.1,0,0
set zlabel "READS VALIDATED / s" font "Computer Modern, 18" offset graph 0,0,0.66

col_24="#c724d6"
col_48="#44cd1"
col_gold="#8f8800"
set cbrange [0:600000000]
set logscale x
set title "Array walk - SEQUENTIAL elements - CPUGPU cooperative validation - STATIC assignment in %" font "Computer Modern,22"
set cbtics font "Computer Modern, 16" 
splot '../results-validation-array/TinySTM-igpu-cpu-persistent-wbetl/1/array-r99-w1-sequential-walk/heat-file' u 2:1:3:xtic(1) t "TinySTM-wbetl CPUGPU cooperative validation" with pm3d, \
      '../results-validation-array/TinySTM-wbetl/1/array-r99-w1-sequential-walk/heat-file' u 2:1:3:xtic(2) t "TinySTM-wbetl untouched" w surface lc "#000000"

