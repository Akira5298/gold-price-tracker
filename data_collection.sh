URL="https://www.goldprice.org"
DATE=$(date +"%Y-%m-%d")
LOGFILE="logs/error.log"
MYSQL="/opt/homebrew/opt/mysql@5.7/bin/mysql"
mkdir -p logs
HTML=$(curl -s $URL)
if [ -z "$HTML" ]; then
    echo "[$DATE] ERROR: Website not reachable" >> $LOGFILE
    exit 1
fi
PRICE=$(echo "$HTML" | grep -oP '(?<=Gold Price Today: )\$[0-9,]+\.[0-9]+' | head -1 | tr -d '$,')
if [ -z "$PRICE" ]; then
    echo "[$DATE] ERROR: Failed to extract price" >> $LOGFILE
    exit 1
fi
$MYSQL -u root -e "
USE gold_tracker;
INSERT INTO gold_price (price, collected_date)
VALUES ($PRICE, '$DATE');
"
echo "Gold price $PRICE inserted for $DATE"
