MYSQL="/opt/homebrew/opt/mysql@5.7/bin/mysql"
OUTDIR="plots"
mkdir -p $OUTDIR
$MYSQL -u root -p -e "
USE gold_tracker;
SELECT collected_date, price FROM gold_price;
" > gold_data.dat
sed -i '' '1d' gold_data.dat
plot_graph () {
gnuplot << EOF
set terminal png size 800,600
set output "$OUTDIR/$1.png"
set title "$2"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%d-%m"
set xlabel "Date"
set ylabel "Gold Price (USD)"
plot "gold_data.dat" using 1:2 with lines title "Gold Price"
EOF
}
plot_graph plot1 "Gold Price Trend 1"
plot_graph plot2 "Gold Price Trend 2"
plot_graph plot3 "Gold Price Trend 3"
plot_graph plot4 "Gold Price Trend 4"
plot_graph plot5 "Gold Price Trend 5"
plot_graph plot6 "Gold Price Trend 6"
plot_graph plot7 "Gold Price Trend 7"
plot_graph plot8 "Gold Price Trend 8"
plot_graph plot9 "Gold Price Trend 9"
plot_graph plot10 "Gold Price Trend 10"
echo "Plots generated successfully"
