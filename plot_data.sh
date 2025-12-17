MYSQL_PATH="/opt/homebrew/opt/mysql@5.7/bin/mysql"
MYSQL_USER="root"
DB_NAME="gold_tracker"
OUTPUT_DIR="plots"
DATA_FILE="gold_data.dat"
STATS_FILE="gold_stats.dat"
LOG_FILE="logs/plot.log"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
mkdir -p "$OUTPUT_DIR" logs
log_plot() {
    local message=$1
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}[$timestamp] $message${NC}"
    echo "[$timestamp] $message" >> "$LOG_FILE"
}
export_data() {
    log_plot "Exporting data from database..."
    $MYSQL_PATH -u "$MYSQL_USER" -s -N -e "
        USE $DB_NAME;
        SELECT collected_date, price FROM gold_price
        ORDER BY collected_date ASC;
    " > "$DATA_FILE"
    if [ $? -ne 0 ]; then
        log_plot "ERROR: Failed to export data from database"
        exit 1
    fi
    local record_count=$(wc -l < "$DATA_FILE")
    log_plot "Exported $record_count records"
    if [ "$record_count" -eq 0 ]; then
        log_plot "ERROR: No data available to plot"
        exit 1
    fi
    $MYSQL_PATH -u "$MYSQL_USER" -s -N -e "
        USE $DB_NAME;
        SELECT 
            MIN(price) as min_price,
            MAX(price) as max_price,
            AVG(price) as avg_price,
            STDDEV(price) as std_dev
        FROM gold_price;
    " > "$STATS_FILE"
}
plot_line_graph() {
    log_plot "Generating line graph..."
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_line.png"
set title "Gold Price Trend Over Time" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
set style line 1 lc rgb '
plot "$DATA_FILE" using 1:2 with lines ls 1 title "Gold Price"
EOF
    log_plot "Line graph saved: $OUTPUT_DIR/gold_price_line.png"
}
plot_points_graph() {
    log_plot "Generating points graph..."
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_points.png"
set title "Gold Price Trend with Data Points" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
set style line 1 lc rgb '
plot "$DATA_FILE" using 1:2 with linespoints ls 1 title "Gold Price"
EOF
    log_plot "Points graph saved: $OUTPUT_DIR/gold_price_points.png"
}
plot_filled_graph() {
    log_plot "Generating filled area graph..."
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_filled.png"
set title "Gold Price Trend (Filled Area)" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
set style fill solid 0.3
plot "$DATA_FILE" using 1:2 with filledcurves x1 lc rgb '
     "$DATA_FILE" using 1:2 with lines lc rgb '
EOF
    log_plot "Filled graph saved: $OUTPUT_DIR/gold_price_filled.png"
}
plot_statistical_graph() {
    log_plot "Generating statistical analysis graph..."
    read min_price max_price avg_price std_dev < "$STATS_FILE"
    upper_band=$(echo "$avg_price + $std_dev" | bc)
    lower_band=$(echo "$avg_price - $std_dev" | bc)
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_statistics.png"
set title "Gold Price with Statistical Analysis" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
set label 1 sprintf("Average: \$%.2f", $avg_price) at graph 0.02, 0.95 font 'Arial,10'
set label 2 sprintf("Std Dev: \$%.2f", $std_dev) at graph 0.02, 0.91 font 'Arial,10'
set label 3 sprintf("Min: \$%.2f", $min_price) at graph 0.02, 0.87 font 'Arial,10'
set label 4 sprintf("Max: \$%.2f", $max_price) at graph 0.02, 0.83 font 'Arial,10'
plot "$DATA_FILE" using 1:2 with lines lw 2 lc rgb '
     $avg_price with lines lw 2 lc rgb '
     $upper_band with lines lw 1.5 lc rgb '
     $lower_band with lines lw 1.5 lc rgb '
EOF
    log_plot "Statistical graph saved: $OUTPUT_DIR/gold_price_statistics.png"
}
plot_moving_average() {
    log_plot "Generating moving average graph..."
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_moving_avg.png"
set title "Gold Price with Moving Averages" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
samples(x) = \$0 > 2 ? 3 : (\$0+1)
avg3(x) = (shift3(x), (back1+back2+back3)/samples(\$0))
shift3(x) = (back3 = back2, back2 = back1, back1 = x)
init(x) = (back1 = back2 = back3 = sum = 0)
plot "$DATA_FILE" using 1:2 with lines lw 1 lc rgb '
     "$DATA_FILE" using 1:(init(\$2), avg3(\$2)) with lines lw 2 lc rgb '
EOF
    log_plot "Moving average graph saved: $OUTPUT_DIR/gold_price_moving_avg.png"
}
plot_price_change() {
    log_plot "Generating price change graph..."
    awk 'NR>1 {print prev_date, $2-prev_price} {prev_date=$1; prev_price=$2}' "$DATA_FILE" > "${DATA_FILE}.changes"
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_changes.png"
set title "Daily Gold Price Changes" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price Change (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
set style fill solid 0.5
set boxwidth 0.8 relative
plot "${DATA_FILE}.changes" using 1:(\$2>0?\$2:0) with boxes lc rgb '
     "${DATA_FILE}.changes" using 1:(\$2<=0?\$2:0) with boxes lc rgb '
EOF
    log_plot "Price change graph saved: $OUTPUT_DIR/gold_price_changes.png"
}
plot_recent_zoom() {
    log_plot "Generating recent data zoom graph..."
    start_date=$(tail -7 "$DATA_FILE" | head -1 | awk '{print $1}')
    end_date=$(tail -1 "$DATA_FILE" | awk '{print $1}')
    gnuplot << EOF
set terminal png size 1200,800 enhanced font 'Arial,12'
set output "$OUTPUT_DIR/gold_price_recent.png"
set title "Gold Price Trend (Recent Period)" font 'Arial,16'
set xlabel "Date" font 'Arial,12'
set ylabel "Price (USD)" font 'Arial,12'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d %b"
set grid ytics xtics
set key top left
set xrange ["$start_date":"$end_date"]
plot "$DATA_FILE" using 1:2 with linespoints lw 2 pt 7 ps 1.5 lc rgb '
EOF
    log_plot "Recent zoom graph saved: $OUTPUT_DIR/gold_price_recent.png"
}
generate_summary_report() {
    log_plot "Generating summary report..."
    read min_price max_price avg_price std_dev < "$STATS_FILE"
    local record_count=$(wc -l < "$DATA_FILE")
    local first_date=$(head -1 "$DATA_FILE" | awk '{print $1}')
    local last_date=$(tail -1 "$DATA_FILE" | awk '{print $1}')
    local first_price=$(head -1 "$DATA_FILE" | awk '{print $2}')
    local last_price=$(tail -1 "$DATA_FILE" | awk '{print $2}')
    local price_change=$(echo "$last_price - $first_price" | bc)
    local percent_change=$(echo "scale=2; ($price_change / $first_price) * 100" | bc)
    cat > "$OUTPUT_DIR/summary_report.txt" << EOREPORT
================================================================================
                     GOLD PRICE TRACKER - SUMMARY REPORT
================================================================================
Generated: $(date +"%Y-%m-%d %H:%M:%S")
DATA OVERVIEW
--------------------------------------------------------------------------------
Total Records:          $record_count
First Date:             $first_date
Last Date:              $last_date
Period:                 $(( ($(date -j -f "%Y-%m-%d" "$last_date" +%s) - $(date -j -f "%Y-%m-%d" "$first_date" +%s)) / 86400 )) days
PRICE STATISTICS
--------------------------------------------------------------------------------
Minimum Price:          \$$min_price
Maximum Price:          \$$max_price
Average Price:          \$$avg_price
Standard Deviation:     \$$std_dev
Price Range:            \$$(echo "$max_price - $min_price" | bc)
PERIOD PERFORMANCE
--------------------------------------------------------------------------------
Starting Price:         \$$first_price ($first_date)
Ending Price:           \$$last_price ($last_date)
Total Change:           \$$price_change
Percent Change:         $percent_change%
GENERATED PLOTS
--------------------------------------------------------------------------------
1. gold_price_line.png          - Basic line graph
2. gold_price_points.png        - Graph with data points
3. gold_price_filled.png        - Filled area graph
4. gold_price_statistics.png    - Statistical analysis with bands
5. gold_price_moving_avg.png    - Moving average analysis
6. gold_price_changes.png       - Daily price changes
7. gold_price_recent.png        - Recent period zoom view
================================================================================
EOREPORT
    log_plot "Summary report saved: $OUTPUT_DIR/summary_report.txt"
    echo -e "${GREEN}"
    cat "$OUTPUT_DIR/summary_report.txt"
    echo -e "${NC}"
}
echo -e "${YELLOW}===============================================${NC}"
echo -e "${YELLOW}     Gold Price Plotting Script${NC}"
echo -e "${YELLOW}===============================================${NC}"
echo ""
if ! command -v gnuplot &> /dev/null; then
    log_plot "ERROR: gnuplot is not installed. Please install it first."
    exit 1
fi
export_data
plot_line_graph
plot_points_graph
plot_filled_graph
plot_statistical_graph
plot_moving_average
plot_price_change
plot_recent_zoom
generate_summary_report
echo ""
echo -e "${GREEN}✓ All plots generated successfully!${NC}"
echo -e "${GREEN}✓ Plots saved in: $OUTPUT_DIR/${NC}"
echo -e "${GREEN}✓ Summary report: $OUTPUT_DIR/summary_report.txt${NC}"
echo ""
rm -f "${DATA_FILE}.changes"
log_plot "Plotting completed successfully"
