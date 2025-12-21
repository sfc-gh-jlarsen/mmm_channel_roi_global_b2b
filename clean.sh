#!/bin/bash
###############################################################################
# clean.sh - Remove all Global B2B MMM resources
###############################################################################

set -e
set -o pipefail

CONNECTION_NAME="demo"
FORCE=false
ENV_PREFIX=""

PROJECT_PREFIX="GLOBAL_B2B_MMM"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Remove all project resources.

Options:
  -c, --connection NAME    Snowflake CLI connection
  -p, --prefix PREFIX      Environment prefix
  --force, -y              Skip confirmation
  -h, --help               Show help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage ;;
        -c|--connection) CONNECTION_NAME="$2"; shift 2 ;;
        -p|--prefix) ENV_PREFIX="$2"; shift 2 ;;
        --force|-y) FORCE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SNOW_CONN="-c $CONNECTION_NAME"

if [ -n "$ENV_PREFIX" ]; then
    FULL_PREFIX="${ENV_PREFIX}_${PROJECT_PREFIX}"
else
    FULL_PREFIX="${PROJECT_PREFIX}"
fi

DATABASE="${FULL_PREFIX}"
ROLE="${FULL_PREFIX}_ROLE"
WAREHOUSE="${FULL_PREFIX}_WH"
COMPUTE_POOL="${FULL_PREFIX}_COMPUTE_POOL"

echo -e "${YELLOW}WARNING: This will permanently delete all resources for ${FULL_PREFIX}!${NC}"
echo "Resources to be deleted:"
echo "  - Compute Pool: $COMPUTE_POOL"
echo "  - Warehouse: $WAREHOUSE"
echo "  - Database: $DATABASE"
echo "  - Role: $ROLE"
echo ""

if [ "$FORCE" = false ]; then
    read -p "Are you sure? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo "Starting cleanup..."

# 1. Compute Pool
echo "Dropping Compute Pool..."
snow sql $SNOW_CONN -q "
    USE ROLE ACCOUNTADMIN;
    DROP COMPUTE POOL IF EXISTS ${COMPUTE_POOL};
" 2>/dev/null && echo -e "${GREEN}[OK]${NC}" || echo -e "${YELLOW}[WARN]${NC} Not found"

# 2. Warehouse
echo "Dropping Warehouse..."
snow sql $SNOW_CONN -q "
    USE ROLE ACCOUNTADMIN;
    DROP WAREHOUSE IF EXISTS ${WAREHOUSE};
" 2>/dev/null && echo -e "${GREEN}[OK]${NC}" || echo -e "${YELLOW}[WARN]${NC} Not found"

# 3. Database
echo "Dropping Database..."
snow sql $SNOW_CONN -q "
    USE ROLE ACCOUNTADMIN;
    DROP DATABASE IF EXISTS ${DATABASE};
" 2>/dev/null && echo -e "${GREEN}[OK]${NC}" || echo -e "${YELLOW}[WARN]${NC} Not found"

# 4. Role
echo "Dropping Role..."
snow sql $SNOW_CONN -q "
    USE ROLE ACCOUNTADMIN;
    DROP ROLE IF EXISTS ${ROLE};
" 2>/dev/null && echo -e "${GREEN}[OK]${NC}" || echo -e "${YELLOW}[WARN]${NC} Not found"

echo -e "${GREEN}Cleanup Complete!${NC}"

