import sqlite3

db_path = r'C:\Users\msi201\AppData\Roaming\MetaQuotes\Terminal\Common\Files\db\AGS.db'
sids = ['1001-26060204-04-00-2-1', '1001-26060210-13-00-2-1']

try:
    db = sqlite3.connect(db_path)
    cursor = db.cursor()
    
    placeholders = ', '.join(['?'] * len(sids))
    query = f"SELECT id, sid, symbol, xe_status, xa_exit FROM signals WHERE sid IN ({placeholders})"
    cursor.execute(query, sids)
    results = cursor.fetchall()
    
    print("Search Results:")
    for row in results:
        print(row)
        
    db.close()
except Exception as e:
    print(f"Error: {e}")
