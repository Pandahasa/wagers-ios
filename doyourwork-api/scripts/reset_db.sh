#!/usr/bin/env bash
# Reset development database tables for DoYourWork.
# WARNING: This permanently deletes data. Use only in development.

set -euo pipefail

# Load local .env if present to pick up DB credentials (optional)
if [ -f ".env" ]; then
  # shellcheck disable=SC1091
  source .env
fi

DB_HOST=${DB_HOST:-localhost}
DB_USER=${DB_USER:-doyourwork_user}
DB_PASS=${DB_PASS:-secure_password}
DB_NAME=${DB_NAME:-doyourwork_db}

echo "Resetting database '$DB_NAME' on $DB_HOST as user $DB_USER"

read -p "This will DELETE ALL DATA from Wagers, Friends, and Users. Continue? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted"
  exit 1
fi

if [[ "$1" == "-r" || "$1" == "--recreate" ]]; then
  echo "Dropping tables and recreating schema from tables.sql"
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" <<SQL
  SET FOREIGN_KEY_CHECKS = 0;
  DROP TABLE IF EXISTS Wagers;
  DROP TABLE IF EXISTS Friends;
  DROP TABLE IF EXISTS Users;
  SET FOREIGN_KEY_CHECKS = 1;
  SQL

  echo "Recreating schema..."
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" $DB_NAME < tables.sql
  echo "Seeding database with example users..."
  node scripts/seed_db.js
else
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" <<SQL
  SET FOREIGN_KEY_CHECKS = 0;
  TRUNCATE TABLE Wagers;
  TRUNCATE TABLE Friends;
  TRUNCATE TABLE Users;
  SET FOREIGN_KEY_CHECKS = 1;
  SQL
fi

echo "Tables truncated. If you want to completely re-create schema, run: 
  mysql -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME < tables.sql"

echo "Done"
