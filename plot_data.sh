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
#Calculates minimum, maximum, average, and standard deviation from the database

recordcount=$(wc -l < $datafile)
echo "[$timestamp] Exported $recordcount records" >> $logfile
if [ $recordcount -eq 0 ]; then
    echo "[$timestamp] ERROR: No data found" >> $logfile
    exit 1
fi

$mysqlcmd -u root -p -s -N -e "USE goldtracker; SELECT MIN(price), MAX(price), AVG(price), STDDEV(price) FROM goldprice;" > $statsfile

#First chart: shows the total gain/loss from starting price
#Second chart: compare the actual price vs 7-day smoothed trend
#Third chart: displays weekly high/low price range
#Fourth chart: similar to line chart but with data points marked

firstprice=$(head -1 $datafile | awk '{print $2}')
awk -v fp=$firstprice '{print $1, $2-fp}' $datafile > ${datafile}.gainloss
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_gainloss.png"
set title "Cumulative Gain/Loss from Start"
set xlabel "Date"
set ylabel "Gain/Loss (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set yrange [*:*]
set style fill solid 0.3
plot "${datafile}.gainloss" using 1:(\$2>=0?\$2:0) with filledcurves y1=0 lc rgb "green" title "Gain", \
     "${datafile}.gainloss" using 1:(\$2<0?\$2:0) with filledcurves y1=0 lc rgb "red" title "Loss", \
     "${datafile}.gainloss" using 1:2 with lines lw 2 lc rgb "black" title "Net Change"
EOF
rm -f ${datafile}.gainloss

gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_smoothed.png"
set title "Actual Price vs 7-Day Smoothed Trend"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
samples7(x) = \$0 > 5 ? 7 : (\$0+1)
avg7(x) = (shift7(x), (b1+b2+b3+b4+b5+b6+b7)/samples7(\$0))
shift7(x) = (b7=b6, b6=b5, b5=b4, b4=b3, b3=b2, b2=b1, b1=x)
init7(x) = (b1=b2=b3=b4=b5=b6=b7=0)
plot "$datafile" using 1:2 with lines lw 2 lc rgb "red" title "Actual", \
     "$datafile" using 1:(\$0<6?1/0:(init7(\$2), avg7(\$2))) with lines lw 3 lc rgb "blue" title "7-Day Smoothed"
EOF

#Plot 4: Weekly High/Low Range
awk 'BEGIN{week=0; max=0; min=999999; date=""} {if(NR%7==1){if(NR>1)print date, min, max; max=$2; min=$2; date=$1; week++} else {if($2>max)max=$2; if($2<min)min=$2; date=$1}} END{print date, min, max}' $datafile > ${datafile}.weeklyrange
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_weeklyrange.png"
set title "Weekly Price Range (High/Low)"
set xlabel "Week Ending"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%b %d"
set grid
set style fill solid 0.3
plot "${datafile}.weeklyrange" using 1:2:3 with filledcurves lc rgb "skyblue" title "Weekly Range", \
     "${datafile}.weeklyrange" using 1:2 with lines lw 2 lc rgb "red" title "Low", \
     "${datafile}.weeklyrange" using 1:3 with lines lw 2 lc rgb "green" title "High"
EOF
rm -f ${datafile}.weeklyrange

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

#Fifth chart: an area chart to visually emphasise price changes
#Sixth chart: reads statistical values and plots average and standard deviation lines
#Seventh chart: calculates and plots 3-day moving average
#To get a smooth curve that looks less noisy, showing the overall trend
#Eighth chart: calculates day-to-day price changes and shows gains and losses

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
plot "$datafile" using 1:2 with lines lw 3 title "Price", \
     $avgprice with lines lw 3 dt 2 title "Average", \
     $upper with lines lw 2.5 dt 3 title "+1 SD", \
     $lower with lines lw 2.5 dt 3 title "-1 SD"
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
samples(x) = \$0 > 1 ? 3 : (\$0+1)
avg3(x) = (shift3(x), (back1+back2+back3)/samples(\$0))
shift3(x) = (back3 = back2, back2 = back1, back1 = x)
init(x) = (back1 = back2 = back3 = 0)
plot "$datafile" using 1:2 with lines lw 1 title "Actual", \
     "$datafile" using 1:(\$0<2?1/0:(init(\$2), avg3(\$2))) with lines lw 2 title "3-Day Avg"
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

#Ninth chart: shows only the most 7 recent data points, to focus on latest trends
#Tenth chart: a histogram showing the distribution of gold prices over time
#Eleventh chart: display daily gold price volatility based on price changes
#Twelfth chart: shows weekly average prices to highlight longer-term trends

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

awk '{print $1, $2}' $datafile | awk 'NR>1{diff=$2-p; print $1, (diff<0?-diff:diff); p=$2}' > ${datafile}.volatility
gnuplot << EOF
set terminal png size 1200,800
set output "$outputdir/goldprice_volatility.png"
set title "Gold Price Volatility (Absolute Daily Change)"
set xlabel "Date"
set ylabel "Absolute Price Change (USD)"
set yrange [0:10]
set xdata time
set timefmt "%Y-%m-%d"
set format x "%b %d"
set grid
set style fill solid 0.7
set boxwidth 0.8 relative
plot "${datafile}.volatility" using 1:2 with boxes lc rgb "orange" title "Daily Volatility"
EOF
rm -f ${datafile}.volatility

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
  1. goldprice_gainloss.png - Cumulative gain/loss
  2. goldprice_smoothed.png - 7-day smoothed trend
  3. goldprice_weeklyrange.png - Weekly high/low
  4. goldprice_points.png - With data points
  5. goldprice_filled.png - Filled area
  6. goldprice_statistics.png - Statistical analysis
  7. goldprice_movingavg.png - Moving average
  8. goldprice_changes.png - Daily changes
  9. goldprice_recent.png - Recent period
  10. goldprice_histogram.png - Price distribution
  11. goldprice_volatility.png - Price volatility
  12. goldprice_weekly.png - Weekly averages
EOREPORT

rm -f ${datafile}.changes
echo "[$timestamp] All plots generated" >> $logfile
echo "Plots saved in $outputdir/"
echo "Summary: $outputdir/summary.txt"
