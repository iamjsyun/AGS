import sqlite3

db_path = r'C:\Users\msi201\AppData\Roaming\MetaQuotes\Terminal\Common\Files\db\AGS.db'

try:
    db = sqlite3.connect(db_path)
    cursor = db.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [t[0] for t in cursor.fetchall()]
    
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"{table}: {count} rows")
        
    db.close()
except Exception as e:
    print(f"Error: {e}")
