
set terminal wxt size 2560,480
set multiplot layout 1,3 rowsfirst title "genome - Energy consumption using Intel RAPL (W)" font ",16"
set bmargin 3
set border 1 lc rgb "#606060" 
xlabeloffsety=-2.75
set tics scale 0
set xtics nomirror rotate by 45 right scale 0 font ",8"
set style fill solid 1.00
set grid ytics lc rgb "#606060"
set yrange [0:*]
set format y "%0.3f"
set datafile separator whitespace
set boxwidth 0.88
set style data histogram
set style histogram rowstacked gap 1
unset key
leftcolumn_offset_1= 0
leftcolumn_offset_1a=5
leftcolumn_offset_2= 10
leftcolumn_offset_4= 15
leftcolumn_offset_8= 20
leftcolumn_offset_16=25
leftcolumn_offset_32=30
set xtics offset 0, 0
unset grid
set ylabel "Power consumption (W)"
set format y "%2.0f"
set grid ytics lc rgb "#606060"
unset datafile
set title "genome" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/1-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results-cpu/1a-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/2-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/4-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/8-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/16-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/32-genome-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"

set title "genome+" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/1-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results-cpu/1a-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/2-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/4-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/8-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/16-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/32-genome+-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"

set title "genome++" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/1-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results-cpu/1a-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/2-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/4-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/8-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/16-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results-cpu/32-genome++-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"

unset multiplot
