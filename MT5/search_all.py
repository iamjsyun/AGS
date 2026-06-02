import sqlite3

db_path = r'C:\Users\msi201\AppData\Roaming\MetaQuotes\Terminal\Common\Files\db\AGS.db'
sids = ['1001-26060204-04-00-2-1', '1001-26060210-13-00-2-1']

def search_in_all_tables():
    db = sqlite3.connect(db_path)
    cursor = db.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [t[0] for t in cursor.fetchall()]
    
    for table in tables:
        try:
            cursor.execute(f"PRAGMA table_info({table})")
            cols = [c[1] for c in cursor.fetchall()]
            if 'sid' in cols:
                placeholders = ', '.join(['?'] * len(sids))
                cursor.execute(f"SELECT * FROM {table} WHERE sid IN ({placeholders})", sids)
                results = cursor.fetchall()
                if results:
                    print(f"Table: {table}")
                    for r in results:
                        print(r)
        except Exception as e:
            pass
    db.close()

search_in_all_tables()
