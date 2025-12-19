mysql_cmd="/opt/homebrew/opt/mysql@5.7/bin/mysql"
output_dir="plots"
data_file="gold_data.dat"
stats_file="gold_stats.dat"
logfile="logs/plot.log"
mkdir -p $output_dir logs
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$timestamp] Starting plot generation..." >> $logfile
$mysql_cmd -u root -s -N -e "USE gold_tracker; SELECT collected_date, price FROM gold_price ORDER BY collected_date ASC;" > $data_file
if [ $? -ne 0 ]; then
    echo "[$timestamp] ERROR: Database export failed" >> $logfile
    exit 1
fi
record_count=$(wc -l < $data_file)
echo "[$timestamp] Exported $record_count records" >> $logfile
if [ $record_count -eq 0 ]; then
    echo "[$timestamp] ERROR: No data found" >> $logfile
    exit 1
fi
$mysql_cmd -u root -s -N -e "USE gold_tracker; SELECT MIN(price), MAX(price), AVG(price), STDDEV(price) FROM gold_price;" > $stats_file
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_line.png"
set title "Gold Price Trend"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
plot "$data_file" using 1:2 with lines lw 2 title "Gold Price"
EOF
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_points.png"
set title "Gold Price with Data Points"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
plot "$data_file" using 1:2 with linespoints lw 2 pt 7 ps 1.5 title "Gold Price"
EOF
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_filled.png"
set title "Gold Price Area Chart"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set style fill solid 0.3
plot "$data_file" using 1:2 with filledcurves x1 title "Price Area", \
     "$data_file" using 1:2 with lines lw 2 title "Price Line"
EOF
read min_price max_price avg_price std_dev < $stats_file
upper=$(echo "$avg_price + $std_dev" | bc)
lower=$(echo "$avg_price - $std_dev" | bc)
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_statistics.png"
set title "Gold Price Statistical Analysis"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set label 1 sprintf("Avg: \$%.2f", $avg_price) at graph 0.02, 0.95
set label 2 sprintf("Std: \$%.2f", $std_dev) at graph 0.02, 0.91
plot "$data_file" using 1:2 with lines lw 2 title "Price", \
     $avg_price with lines lw 2 dt 2 title "Average", \
     $upper with lines lw 1.5 dt 3 title "+1 SD", \
     $lower with lines lw 1.5 dt 3 title "-1 SD"
EOF
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_moving_avg.png"
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
plot "$data_file" using 1:2 with lines lw 1 title "Actual", \
     "$data_file" using 1:(init(\$2), avg3(\$2)) with lines lw 2 title "3-Day Avg"
EOF
awk 'NR>1 {print prev_date, $2-prev_price} {prev_date=$1; prev_price=$2}' $data_file > ${data_file}.changes
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_changes.png"
set title "Daily Price Changes"
set xlabel "Date"
set ylabel "Change (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set style fill solid 0.5
plot "${data_file}.changes" using 1:(\$2>0?\$2:0) with boxes lc rgb "green" title "Increase", \
     "${data_file}.changes" using 1:(\$2<=0?\$2:0) with boxes lc rgb "red" title "Decrease"
EOF
start_date=$(tail -7 $data_file | head -1 | awk '{print $1}')
end_date=$(tail -1 $data_file | awk '{print $1}')
gnuplot << EOF
set terminal png size 1200,800
set output "$output_dir/gold_price_recent.png"
set title "Recent Gold Prices"
set xlabel "Date"
set ylabel "Price (USD)"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid
set xrange ["$start_date":"$end_date"]
plot "$data_file" using 1:2 with linespoints lw 2 pt 7 ps 1.5 title "Price"
EOF
first_date=$(head -1 $data_file | awk '{print $1}')
last_date=$(tail -1 $data_file | awk '{print $1}')
first_price=$(head -1 $data_file | awk '{print $2}')
last_price=$(tail -1 $data_file | awk '{print $2}')
price_change=$(echo "$last_price - $first_price" | bc)
percent=$(echo "scale=2; ($price_change / $first_price) * 100" | bc)
cat > $output_dir/summary_report.txt << EOREPORT
Gold Price Tracker - Summary Report
Generated: $(date)
Records: $record_count
Period: $first_date to $last_date
Price Statistics:
  Minimum: \$$min_price
  Maximum: \$$max_price
  Average: \$$avg_price
  Std Dev: \$$std_dev
Performance:
  Start: \$$first_price ($first_date)
  End:   \$$last_price ($last_date)
  Change: \$$price_change ($percent%)
Generated Plots:
  1. gold_price_line.png - Line chart
  2. gold_price_points.png - With data points
  3. gold_price_filled.png - Filled area
  4. gold_price_statistics.png - Statistical analysis
  5. gold_price_moving_avg.png - Moving average
  6. gold_price_changes.png - Daily changes
  7. gold_price_recent.png - Recent period
EOREPORT
rm -f ${data_file}.changes
echo "[$timestamp] All plots generated" >> $logfile
echo "Plots saved in $output_dir/"
echo "Summary: $output_dir/summary_report.txt"
