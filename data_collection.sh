SITE_URL="https://www.goldprice.org"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
DATE=$(date +"%Y-%m-%d")
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/collection.log"
ERROR_LOG="$LOG_DIR/error.log"
MYSQL_PATH="/opt/homebrew/opt/mysql@5.7/bin/mysql"
MYSQL_USER="root"
DB_NAME="gold_tracker"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 
mkdir -p "$LOG_DIR"
log_message() {
    local level=$1
    local message=$2
    local color=$NC
    case $level in
        "ERROR")   color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "INFO")    color=$YELLOW ;;
    esac
    echo -e "${color}[$TIMESTAMP] $level: $message${NC}"
    echo "[$TIMESTAMP] $level: $message" >> "$LOG_FILE"
    if [ "$level" == "ERROR" ]; then
        echo "[$TIMESTAMP] $message" >> "$ERROR_LOG"
    fi
}
check_dependencies() {
    local missing_deps=0
    for cmd in curl grep sed mysql; do
        if ! command -v $cmd &> /dev/null; then
            log_message "ERROR" "Required command not found: $cmd"
            missing_deps=1
        fi
    done
    if [ $missing_deps -eq 1 ]; then
        log_message "ERROR" "Please install missing dependencies"
        exit 1
    fi
    if [ ! -f "$MYSQL_PATH" ]; then
        log_message "ERROR" "MySQL not found at $MYSQL_PATH"
        exit 1
    fi
    log_message "INFO" "All dependencies checked successfully"
}
fetch_gold_price() {
    log_message "INFO" "Fetching data from $SITE_URL"
    local webpage=$(curl -s --max-time 30 "$SITE_URL")
    if [ $? -ne 0 ] || [ -z "$webpage" ]; then
        log_message "ERROR" "Failed to fetch data from website (curl error or empty response)"
        return 1
    fi
    local price=""
    price=$(echo "$webpage" | grep -oP '(?<=Gold Price Today: )\$[0-9,]+\.[0-9]+' | head -1 | tr -d '$,')
    if [ -z "$price" ]; then
        price=$(echo "$webpage" | grep -oE '\$[0-9]{1,2},[0-9]{3}\.[0-9]{2}' | head -1 | tr -d '$,')
    fi
    if [ -z "$price" ]; then
        price=$(echo "$webpage" | grep -oE '[0-9]{4}\.[0-9]{2}' | head -1)
    fi
    if [ -z "$price" ]; then
        log_message "ERROR" "Failed to extract gold price from webpage"
        return 1
    fi
    if ! [[ "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_message "ERROR" "Invalid price format: $price"
        return 1
    fi
    if (( $(echo "$price < 1000" | bc -l) )) || (( $(echo "$price > 5000" | bc -l) )); then
        log_message "ERROR" "Price out of expected range: $price"
        return 1
    fi
    log_message "SUCCESS" "Gold price extracted: \$$price"
    echo "$price"
    return 0
}
store_in_database() {
    local price=$1
    log_message "INFO" "Storing price in database"
    local existing=$($MYSQL_PATH -u "$MYSQL_USER" -N -s -e "
        USE $DB_NAME;
        SELECT COUNT(*) FROM gold_price WHERE collected_date = '$DATE';
    " 2>&1)
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Database connection failed: $existing"
        return 1
    fi
    if [ "$existing" -gt 0 ]; then
        log_message "INFO" "Updating existing entry for $DATE"
        $MYSQL_PATH -u "$MYSQL_USER" -e "
            USE $DB_NAME;
            UPDATE gold_price 
            SET price = $price, collected_time = NOW()
            WHERE collected_date = '$DATE';
        " 2>&1
    else
        log_message "INFO" "Inserting new entry for $DATE"
        $MYSQL_PATH -u "$MYSQL_USER" -e "
            USE $DB_NAME;
            INSERT INTO gold_price (price, collected_date, collected_time)
            VALUES ($price, '$DATE', NOW());
        " 2>&1
    fi
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Price \$$price stored successfully in database"
        return 0
    else
        log_message "ERROR" "Failed to store price in database"
        return 1
    fi
}
log_message "INFO" "Starting gold price collection script"
log_message "INFO" "=========================================="
check_dependencies
GOLD_PRICE=$(fetch_gold_price)
if [ $? -eq 0 ] && [ -n "$GOLD_PRICE" ]; then
    if store_in_database "$GOLD_PRICE"; then
        log_message "SUCCESS" "Data collection completed successfully"
        log_message "INFO" "=========================================="
        exit 0
    else
        log_message "ERROR" "Failed to store data in database"
        log_message "INFO" "=========================================="
        exit 1
    fi
else
    log_message "ERROR" "Failed to fetch gold price"
    log_message "INFO" "=========================================="
    exit 1
fi
