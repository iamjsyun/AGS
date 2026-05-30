import sqlite3
import os

db_path = r"C:\Users\msi201\AppData\Roaming\MetaQuotes\Terminal\Common\Files\AGS.db"

if not os.path.exists(db_path):
    print(f"DB not found at {db_path}")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("\n--- Signals Table Data ---")
try:
    cursor.execute("SELECT sid, xe_status, ticket, xa_entry, xa_exit, tag FROM signals")
    rows = cursor.fetchall()
    for r in rows:
        print(f"SID: {r[0]} | status: {r[1]} | ticket: {r[2]} | entry: {r[3]} | exit: {r[4]} | tag: {r[5]}")
except Exception as e:
    print("Error:", e)

conn.close()
