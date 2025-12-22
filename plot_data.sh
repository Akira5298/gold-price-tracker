mysqlcmd="/opt/homebrew/opt/mysql@5.7/bin/mysql"
outputdir="plots"
datafile="golddata.dat"
statsfile="goldstats.dat"
logfile="logs/plot.log"
mkdir -p $outputdir logs
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$timestamp] Starting plot generation..." >> $logfile
$mysqlcmd -u root -p -s -N -e "USE goldtracker; SELECT collecteddate, price FROM goldprice ORDER BY collecteddate ASC;" > $datafile
if [ $? -ne 0 ]; then
    echo "[$timestamp] ERROR: Database export failed" >> $logfile
    exit 1
fi
recordcount=$(wc -l < $datafile)
echo "[$timestamp] Exported $recordcount records" >> $logfile
if [ $recordcount -eq 0 ]; then
    echo "[$timestamp] ERROR: No data found" >> $logfile
    exit 1
fi
$mysqlcmd -u root -p -s -N -e "USE goldtracker; SELECT MIN(price), MAX(price), AVG(price), STDDEV(price) FROM goldprice;" > $statsfile
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_line.png"
set title "Gold Price Trend"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
plot "$datafile" using 1:2 with lines lw 2 title "Gold Price"
EOF
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_points.png"
set title "Gold Price with Data Points"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
plot "$datafile" using 1:2 with linespoints lw 2 pt 7 ps 1.5 title "Gold Price"
EOF
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_filled.png"
set title "Gold Price Area Chart"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set style fill solid 0.3
plot "$datafile" using 1:2 with filledcurves x1 title "Price Area", \
     "$datafile" using 1:2 with lines lw 2 title "Price Line"
EOF
read minprice maxprice avgprice stddev < $statsfile
upper=$(echo "$avgprice + $stddev" | bc)
lower=$(echo "$avgprice - $stddev" | bc)
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_statistics.png"
set title "Gold Price Statistical Analysis"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set label 1 sprintf("Avg: \$%.2f", $avgprice) at graph 0.02, 0.95
set label 2 sprintf("Std: \$%.2f", $stddev) at graph 0.02, 0.91
plot "$datafile" using 1:2 with lines lw 2 title "Price", \
     $avgprice with lines lw 2 dt 2 title "Average", \
     $upper with lines lw 1.5 dt 3 title "+1 SD", \
     $lower with lines lw 1.5 dt 3 title "-1 SD"
EOF
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_movingavg.png"
set title "Gold Price with Moving Average"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
samples(x) = \$0 > 2 ? 3 : (\$0+1)
avg3(x) = (shift3(x), (back1+back2+back3)/samples(\$0))
shift3(x) = (back3 = back2, back2 = back1, back1 = x)
init(x) = (back1 = back2 = back3 = 0)
plot "$datafile" using 1:2 with lines lw 1 title "Actual", \
     "$datafile" using 1:(init(\$2), avg3(\$2)) with lines lw 2 title "3-Day Avg"
EOF
awk 'NR>1 {print prev_date, $2-prev_price} {prev_date=$1; prev_price=$2}' $datafile > ${datafile}.changes
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_changes.png"
set title "Daily Price Changes"
set xlabel "Date"
set ylabel "Change (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set style fill solid 0.5
plot "${datafile}.changes" using 1:(\$2>0?\$2:0) with boxes lc rgb "green" title "Increase", \
     "${datafile}.changes" using 1:(\$2<=0?\$2:0) with boxes lc rgb "red" title "Decrease"
EOF
startdate=$(tail -7 $datafile | head -1 | awk '{print $1}')
enddate=$(tail -1 $datafile | awk '{print $1}')
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_recent.png"
set title "Recent Gold Prices"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set xrange ["$startdate":"$enddate"]
plot "$datafile" using 1:2 with linespoints lw 2 pt 7 ps 1.5 title "Price"
EOF
firstdate=$(head -1 $datafile | awk '{print $1}')
lastdate=$(tail -1 $datafile | awk '{print $1}')
firstprice=$(head -1 $datafile | awk '{print $2}')
lastprice=$(tail -1 $datafile | awk '{print $2}')
pricechange=$(echo "$lastprice - $firstprice" | bc)
percent=$(echo "scale=2; ($pricechange / $firstprice) * 100" | bc)
cat > $outputdir/summary.txt << EOREPORT
Gold Price Tracker - Summary Report
Generated: $(date)
Records: $recordcount
Period: $firstdate to $lastdate
Price Statistics:
  Minimum: \$$minprice
  Maximum: \$$maxprice
  Average: \$$avgprice
  Std Dev: \$$stddev
Performance:
  Start: \$$firstprice ($firstdate)
  End:   \$$lastprice ($lastdate)
  Change: \$$pricechange ($percent%)
Generated Plots:
  1. goldprice_line.png - Line chart
  2. goldprice_points.png - With data points
  3. goldprice_filled.png - Filled area
  4. goldprice_statistics.png - Statistical analysis
  5. goldprice_movingavg.png - Moving average
  6. goldprice_changes.png - Daily changes
  7. goldprice_recent.png - Recent period
EOREPORT
rm -f ${datafile}.changes
echo "[$timestamp] All plots generated" >> $logfile
echo "Plots saved in $outputdir/"
echo "Summary: $outputdir/summary.txt"
