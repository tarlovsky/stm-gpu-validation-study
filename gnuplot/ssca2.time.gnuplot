
set terminal wxt size 2560,480
set multiplot layout 1,3 rowsfirst title "ssca2 - Validation time/total execution time (s)" font ",16"
xlabeloffsety=-2.75
set tics scale 0
set xtics nomirror rotate by 45 right scale 0 font ",8"
set style fill solid 1.00
set grid ytics lc rgb "#606060"
unset border
set yrange [0:*]
set bmargin -10
set datafile separator whitespace
set boxwidth 0.88
set style data histogram
set style histogram rowstacked gap 1
unset key
leftcolumn_offset_1= 0
leftcolumn_offset_1a=3
leftcolumn_offset_2= 6
leftcolumn_offset_4= 9
leftcolumn_offset_8= 12
leftcolumn_offset_16=15
leftcolumn_offset_32=18
set xtics offset 0, xlabeloffsety
set ylabel "Time (s)"
set format y "%2.2f"
set title "ssca2" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/1-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_1):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_1):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results-gpu/1a-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_1a):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_1a):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/2-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_2):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_2):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/4-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_4):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_4):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/8-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_8):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_8):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/16-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_16):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_16):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/32-ssca2-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_32):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_32):($16):17 w yerr ls 1 lc rgb 'black' t ""

set title "ssca2+" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/1-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_1):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_1):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results-gpu/1a-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_1a):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_1a):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/2-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_2):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_2):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/4-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_4):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_4):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/8-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_8):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_8):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/16-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_16):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_16):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/32-ssca2+-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_32):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_32):($16):17 w yerr ls 1 lc rgb 'black' t ""

set title "ssca2++" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/1-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_1):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_1):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results-gpu/1a-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_1a):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_1a):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/2-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_2):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_2):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/4-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_4):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_4):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/8-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_8):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_8):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/16-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_16):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_16):($16):17 w yerr ls 1 lc rgb 'black' t "", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results-gpu/32-ssca2++-cluster' u 2:xtic(1) t col lc rgbcolor "#80b3ff" lt 1 fs pattern 3, \
      ''               u ($16>=$2 ? $16-$2 : NaN) t col lc rgbcolor "#b3d1ff" fs pattern 6, \
      ''               u ($0-1-0.26):(($2!=0)?$2:NaN):(sprintf('%2.6f', $2)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left textcolor rgb "#8f8800" font ",8", \
      ''               u ($0-1+0.26):(($16!=0)?$16:NaN):(sprintf('%2.2f', $16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8", \
      ''               u ($0-1):($2-$2):(sprintf('%2.1f%', ($16!=0)?($2/$16*100):0)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 right font ",8", \
      ''               u ($0-1+leftcolumn_offset_32):($2):3 w yerr ls 1 lc rgb "#8f8800" t "", \
      ''               u ($0-1+leftcolumn_offset_32):($16):17 w yerr ls 1 lc rgb 'black' t ""

unset multiplot
