
set terminal wxt size 2560,1080
set multiplot layout 2,3 rowsfirst title "redblacktree - Energy consumption using Intel RAPL (W)" font ",16"
set bmargin 10
xlabeloffsety=-2.75
set tics scale 0
set xtics nomirror rotate by 45 right scale 0 font ",8"
set xtics offset 0, xlabeloffsety
set style fill solid 1.00
set grid ytics lc rgb "#606060"
unset border
set yrange [0:*]
set format y "%0.3f"
set datafile separator whitespace
set boxwidth 0.88
set style data histogram
set style histogram rowstacked gap 1
unset key
leftcolumn_offset_1=0
leftcolumn_offset_1a=5
leftcolumn_offset_2=10
leftcolumn_offset_4=15
leftcolumn_offset_8=20
leftcolumn_offset_16=25
leftcolumn_offset_32=30
set xtics offset 0, xlabeloffsety
unset grid
set ylabel "Power consumption (W)"
set format y "%2.0f"
set grid ytics lc rgb "#606060"
unset datafile
set title "redblacktree-l-w" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results/1-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results/1a-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results/2-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results/4-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results/8-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results/16-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results/32-redblacktree-l-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"
set title "redblacktree-l-r" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results/1-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results/1a-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results/2-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results/4-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results/8-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results/16-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results/32-redblacktree-l-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"
set title "redblacktree-s-w" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results/1-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results/1a-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results/2-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results/4-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results/8-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results/16-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results/32-redblacktree-s-w-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"
set title "redblacktree-s-r" font ",12" tc rgb "#8f8800"
plot\
    newhistogram "{1 threads}" offset char 0,xlabeloffsety, \
      'results/1-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#69a2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1 rotate by 90 left font ",8", \
    newhistogram "{1a threads}" offset char 0,xlabeloffsety, \
      'results/1a-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#7dafff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_1a rotate by 90 left font ",8", \
    newhistogram "{2 threads}" offset char 0,xlabeloffsety, \
      'results/2-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#94bdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_2 rotate by 90 left font ",8", \
    newhistogram "{4 threads}" offset char 0,xlabeloffsety, \
      'results/4-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#9cc2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_4 rotate by 90 left font ",8", \
    newhistogram "{8 threads}" offset char 0,xlabeloffsety, \
      'results/8-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#adcdff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_8 rotate by 90 left font ",8", \
    newhistogram "{16 threads}" offset char 0,xlabeloffsety, \
      'results/16-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#b5d2ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_16 rotate by 90 left font ",8", \
    newhistogram "{32 threads}" offset char 0,xlabeloffsety, \
      'results/32-redblacktree-s-r-cluster' using ( $14/$16 ):xtic(1) t col lc rgbcolor "#bdd7ff" lt 1 fs pattern 6, \
      ''               u ($0-1):($14/$16):(sprintf('%2.1f', $14/$16)) notitle w labels offset first leftcolumn_offset_32 rotate by 90 left font ",8"
unset multiplot
