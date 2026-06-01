
import os

file_path = r'D:\Projects\AGS\MT5\99_TestFramework\Mocks\MockOrderManager.mqh'
with open(file_path, 'rb') as f:
    content = f.read()

# Try common encodings for Korean
encodings = ['cp949', 'euc-kr', 'utf-8', 'utf-16']
for enc in encodings:
    try:
        print(f"--- Trying {enc} ---")
        print(content.decode(enc))
    except:
        print(f"Failed to decode with {enc}")
