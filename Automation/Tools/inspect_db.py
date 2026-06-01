import sqlite3
import os

db_path = r"C:\Users\hijsyun\AppData\Roaming\MetaQuotes\Terminal\Common\Files\AGS.db"

if not os.path.exists(db_path):
    print(f"DB not found at {db_path}")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("--- Columns in signals ---")
cursor.execute("PRAGMA table_info(signals)")
cols = cursor.fetchall()
for col in cols:
    print(col)

print("\n--- Signals Table Data ---")
try:
    cursor.execute("SELECT * FROM signals")
    rows = cursor.fetchall()
    for r in rows:
        print(r)
except Exception as e:
    print("Error:", e)

conn.close()
