#Set up of basic settings such as URLs, file paths, and timestamps
#Also, we make sure that the folders for logs exist
#So that the script doesn't fail when trying to write logs

sitelocation="https://www.goldprice.org"
date=$(date +"%Y-%m-%d")
time=$(date +"%Y-%m-%d %H:%M:%S")
logfile="logs/collection.log"
errorlog="logs/error.log"
mysql="/opt/homebrew/opt/mysql@5.7/bin/mysql"
mkdir -p logs
echo "[$time] Starting collection..." >> $logfile

#Use curl to download the website's content
#The -s option helps to have no progress or error messages 
#The --max-time 30 option makes sure the attempt ends after 30 seconds
#The content is saved in the variable named $webpage, if it's empty, it cannot be accessed

webpage=$(curl -s --max-time 30 $sitelocation)
if [ -z "$webpage" ]; then
    echo "[$time] ERROR: Cannot access website" >> $errorlog
    exit 1
fi

#The website contains HTML code, and we only need to get the info about the gold price
#Since the price may appear in different formats, we try several patterns using grep and sed
#Three attempts looking for: gold price texts, $ followed by numbers, and simpler number format
#If no price is found at all, it will log the error and exit

price=$(echo "$webpage" | grep -oE 'Gold Price Today: \$[0-9,]+\.[0-9]+' | head -1 | sed 's/Gold Price Today: //' | tr -d '$,')
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

#Check if the extracted price is a valid number and it is within a realistic range.
#It can have a decimal point, with a range betweeen $1000 and $5000
#Log that if we have successfully found a valid price

if ! [[ "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "[$time] ERROR: Price format invalid: $price" >> $errorlog
    exit 1
fi
if (( $(echo "$price < 1000" | bc -l) )) || (( $(echo "$price > 5000" | bc -l) )); then
    echo "[$time] ERROR: Price out of range: $price" >> $errorlog
    exit 1
fi
echo "[$time] Price found: $price" >> $logfile

#See if there is already a record in MySQL database for today
#If yes, update it with the updated timestamp and price, if no, add a new record

existing=$($mysqlcmd -u root -p -N -s -e "USE goldtracker; SELECT COUNT(*) FROM goldprice WHERE collecteddate = '$date';" 2>&1)
if [ "$existing" -gt 0 ]; then
    $mysqlcmd -u root -p -e "USE goldtracker; UPDATE goldprice SET price = $price, collectedtime = NOW() WHERE collecteddate = '$date';" 2>&1
    echo "[$time] Updated price for $date" >> $logfile
else
    $mysqlcmd -u root -p -e "USE goldtracker; INSERT INTO goldprice (price, collecteddate, collectedtime) VALUES ($price, '$date', NOW());" 2>&1
    echo "[$time] Inserted new price for $date" >> $logfile
fi

#Check if the database operation was successful.
#exit status of the last command is in $?, where 0 = success, and anything else = failure
if [ $? -eq 0 ]; then
    echo "[$time] Success!" >> $logfile
    echo "Gold price $price saved for $date"
else
    echo "[$time] Database error" >> $errorlog
    exit 1
fi
