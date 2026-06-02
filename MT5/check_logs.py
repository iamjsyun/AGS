import sqlite3

db_path = r'C:\Users\msi201\AppData\Roaming\MetaQuotes\Terminal\Common\Files\db\AGS.db'

try:
    db = sqlite3.connect(db_path)
    cursor = db.cursor()
    
    cursor.execute("SELECT * FROM ags_log ORDER BY created DESC LIMIT 5")
    results = cursor.fetchall()
    
    print("Recent Logs:")
    for row in results:
        print(row)
        
    db.close()
except Exception as e:
    print(f"Error: {e}")
