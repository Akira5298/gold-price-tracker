#Defines paths, filenames, and prepares directories
#Ensures that required directories exist, and adds timestamp for logging

mysqlcmd="/opt/homebrew/opt/mysql@5.7/bin/mysql"
outputdir="plots"
datafile="golddata.dat"
statsfile="goldstats.dat"
logfile="logs/plot.log"
mkdir -p $outputdir logs
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$timestamp] Starting plot generation..." >> $logfile

#Extract historical gold price data from MySQL database
#Saves it into a plain text file that gnuplot can read
#Check if the database export failed or not

$mysqlcmd -u root -p -s -N -e "USE goldtracker; SELECT collecteddate, price FROM goldprice ORDER BY collecteddate ASC;" > $datafile
if [ $? -ne 0 ]; then
    echo "[$timestamp] ERROR: Database export failed" >> $logfile
    exit 1
fi

#Count the number of records that were exported
#If no data exists, plotting literally makes no sense, so we stop

recordcount=$(wc -l < $datafile)
echo "[$timestamp] Exported $recordcount records" >> $logfile
if [ $recordcount -eq 0 ]; then
    echo "[$timestamp] ERROR: No data found" >> $logfile
    exit 1
fi

#Calculates minimum, maximum, average, and standard deviation from the database
#First chart: a simple line chart showing the price of gold over time
#Second chart: similar to line chart but with data points marked
#Third chart: an area chart to visually emphasise price changes

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

#Fourth chart: reads statistical values and plots average and standard deviation lines
#Fifth chart: calculates and plots 3-day moving average
#To get a smooth curve that looks less noisy, showing the overall trend
#Sixth chart: calculates day-to-day price changes and shows gains and losses

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

#Seventh chart: shows only the most 7 recent data points, to focus on latest trends
#Eighth chart: a histogram showing the distribution of gold prices over time
#Ninth chart: display daily gold price volatility based on price changes

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

gnuplot << EOF
set terminal png size 1000,700
set output "$outputdir/goldprice_histogram.png"
set title "Gold Price Distribution"
set xlabel "Price Range (USD)"
set ylabel "Frequency (Count)"
set yrange [0:*]
set style fill solid 0.6 border -1
set boxwidth 10
binwidth=10
bin(x,width)=width*floor(x/width)
plot "$datafile" using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb "steelblue" title "Price Count"
EOF

awk '{print $1, $2}' $datafile | awk 'NR>1{diff=$2-p; print $1, (diff*diff); p=$2}' > ${datafile}.volatility
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_volatility.png"
set title "Gold Price Volatility (Daily Variance)"
set xlabel "Date"
set ylabel "Variance (USD^2)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%b %d"
set grid
set style fill solid 0.7
set boxwidth 0.8 relative
plot "${datafile}.volatility" using 1:2 with boxes lc rgb "red" title "Daily Variance"
EOF
rm -f ${datafile}.volatility

#Tenth chart: shows weekly average prices to highlight longer-term trends
# Creates a text summary describing key statistics and performance metrics
# Logs successful completion and removes temporary files

awk '{print $1, $2}' $datafile | awk 'BEGIN{sum=0; count=0; week=0} {sum+=$2; count++; if(count==7){print $1, sum/count; sum=0; count=0; week++}}' > ${datafile}.weekly
gnuplot << EOF
set terminal png size 800,600
set output "$outputdir/goldprice_weekly.png"
set title "Weekly Average Gold Prices"
set xlabel "Date"
set ylabel "Average Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%b %d"
set grid
plot "${datafile}.weekly" using 1:2 with linespoints lw 2 pt 7 ps 1.5 title "Weekly Average"
EOF
rm -f ${datafile}.weekly

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
  8. goldprice_histogram.png - Price distribution
  9. goldprice_volatility.png - Price volatility
  10. goldprice_weekly.png - Weekly averages
EOREPORT

rm -f ${datafile}.changes
echo "[$timestamp] All plots generated" >> $logfile
echo "Plots saved in $outputdir/"
echo "Summary: $outputdir/summary.txt"
