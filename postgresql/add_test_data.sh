#!/bin/bash

DB_NAME="test"
DB_USER="testuser"
DB_PASSWORD="testpass"
DB_HOST="localhost"
DB_PORT="5432"

ADMIN_USER="postgres"
ADMIN_DB="postgres"

CSV_FILE="users.csv"
TABLE_NAME="users"

export PGPASSWORD="$DB_PASSWORD"

if [ ! -f "$CSV_FILE" ]; then
    echo "Ошибка: Файл $CSV_FILE не найден!"
    exit 1
fi

echo "Проверка пользователя и базы..."

psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d $ADMIN_DB << EOF
DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_roles WHERE rolname = '$DB_USER'
    ) THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;

DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_database WHERE datname = '$DB_NAME'
    ) THEN
        CREATE DATABASE $DB_NAME OWNER $DB_USER;
    END IF;
END
\$\$;
EOF

if [ $? -ne 0 ]; then
    echo "Ошибка при создании пользователя или базы"
    exit 1
fi

echo "Проверка таблицы $TABLE_NAME..."

psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << EOF
CREATE TABLE IF NOT EXISTS $TABLE_NAME (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    age INT,
    email VARCHAR(100)
);
EOF

if [ $? -ne 0 ]; then
    echo "Ошибка при создании таблицы"
    exit 1
fi

echo "Загрузка данных из $CSV_FILE с ON CONFLICT..."

psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << EOF

CREATE TEMP TABLE temp_users (
    id INT,
    name VARCHAR(50),
    age INT,
    email VARCHAR(100)
);

\copy temp_users (id, name, age, email)
FROM '$CSV_FILE'
WITH CSV HEADER DELIMITER ',';

INSERT INTO $TABLE_NAME (id, name, age, email)
SELECT id, name, age, email
FROM temp_users
ON CONFLICT (id) DO UPDATE
SET
    name  = EXCLUDED.name,
    age   = EXCLUDED.age,
    email = EXCLUDED.email;

SELECT
    COUNT(*) AS total_rows
FROM $TABLE_NAME;

EOF

unset PGPASSWORD

if [ $? -eq 0 ]; then
    echo "Загрузка завершена успешно!"
else
    echo "Ошибка при загрузке данных!"
    exit 1
fi
