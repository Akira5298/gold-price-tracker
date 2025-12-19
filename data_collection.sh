sitelocation="https://www.goldprice.org"
date=$(date +"%Y-%m-%d")
time=$(date +"%Y-%m-%d %H:%M:%S")
logfile="logs/collection.log"
errorlog="logs/error.log"
mysql_cmd="/opt/homebrew/opt/mysql@5.7/bin/mysql"
mkdir -p logs
echo "[$time] Starting collection..." >> $logfile
webpage=$(curl -s --max-time 30 $sitelocation)
if [ -z "$webpage" ]; then
    echo "[$time] ERROR: Cannot access website" >> $errorlog
    exit 1
fi
price=$(echo "$webpage" | grep -oP '(?<=Gold Price Today: )\$[0-9,]+\.[0-9]+' | head -1 | tr -d '$,')
if [ -z "$price" ]; then
    price=$(echo "$webpage" | grep -oE '\$[0-9]{1,2},[0-9]{3}\.[0-9]{2}' | head -1 | tr -d '$,')
fi
if [ -z "$price" ]; then
    price=$(echo "$webpage" | grep -oE '[0-9]{4}\.[0-9]{2}' | head -1)
fi
if [ -z "$price" ]; then
    echo "[$time] ERROR: Could not find price" >> $errorlog
    exit 1
fi
if ! [[ "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "[$time] ERROR: Price format invalid: $price" >> $errorlog
    exit 1
fi
if (( $(echo "$price < 1000" | bc -l) )) || (( $(echo "$price > 5000" | bc -l) )); then
    echo "[$time] ERROR: Price out of range: $price" >> $errorlog
    exit 1
fi
echo "[$time] Price found: $price" >> $logfile
existing=$($mysql_cmd -u root -N -s -e "USE gold_tracker; SELECT COUNT(*) FROM gold_price WHERE collected_date = '$date';" 2>&1)
if [ "$existing" -gt 0 ]; then
    $mysql_cmd -u root -e "USE gold_tracker; UPDATE gold_price SET price = $price, collected_time = NOW() WHERE collected_date = '$date';" 2>&1
    echo "[$time] Updated price for $date" >> $logfile
else
    $mysql_cmd -u root -e "USE gold_tracker; INSERT INTO gold_price (price, collected_date, collected_time) VALUES ($price, '$date', NOW());" 2>&1
    echo "[$time] Inserted new price for $date" >> $logfile
fi
if [ $? -eq 0 ]; then
    echo "[$time] Success!" >> $logfile
    echo "Gold price $price saved for $date"
else
    echo "[$time] Database error" >> $errorlog
    exit 1
fi
