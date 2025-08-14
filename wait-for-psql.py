#!/usr/bin/env python3
# ABOUTME: Python script to wait for PostgreSQL availability

import os
import sys
import time
import psycopg2
from psycopg2 import OperationalError

def wait_for_psql():
    """Wait for PostgreSQL to become available."""
    db_host = os.environ.get('DB_HOST', 'db')
    db_port = os.environ.get('DB_PORT', '5432')
    db_user = os.environ.get('DB_USER', 'openspp')
    db_password = os.environ.get('DB_PASSWORD', 'openspp')
    db_name = os.environ.get('DB_NAME', 'postgres')
    
    max_attempts = 60
    attempt = 0
    
    print(f"Waiting for PostgreSQL at {db_host}:{db_port}...")
    
    while attempt < max_attempts:
        try:
            conn = psycopg2.connect(
                host=db_host,
                port=db_port,
                user=db_user,
                password=db_password,
                database=db_name,
                connect_timeout=5
            )
            conn.close()
            print("PostgreSQL is ready!")
            return 0
        except OperationalError as e:
            attempt += 1
            print(f"PostgreSQL is unavailable (attempt {attempt}/{max_attempts}) - sleeping")
            time.sleep(2)
    
    print("PostgreSQL did not become ready in time", file=sys.stderr)
    return 1

if __name__ == "__main__":
    sys.exit(wait_for_psql())
