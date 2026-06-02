import sqlite3

db_path = r'C:\Users\msi201\AppData\Roaming\MetaQuotes\Terminal\Common\Files\db\AGS.db'
sids = ['1001-26060204-04-00-2-1', '1001-26060210-13-00-2-1']

try:
    db = sqlite3.connect(db_path)
    cursor = db.cursor()
    placeholders = ', '.join(['?'] * len(sids))
    cursor.execute(f"SELECT sid, price_open, price_close, xe_status, xe_status_msg FROM signals_history WHERE sid IN ({placeholders})", sids)
    for row in cursor.fetchall():
        print(row)
    db.close()
except Exception as e:
    print(e)
