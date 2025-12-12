import sys, shutil, chardet, io

path = r'C:\Users\Sahil\studybuddy\pubspec.yaml'
bak = path + '.bak_py'
shutil.copy2(path, bak)
data = open(path, 'rb').read()

# try chardet to detect encoding (install chardet via pip if needed)
try:
    enc = chardet.detect(data)['encoding']
    print('chardet detected:', enc)
except Exception as e:
    enc = None
    print('chardet not available or failed:', e)

candidates = [enc, 'utf-8-sig', 'utf-8', 'windows-1252', 'iso-8859-1', 'cp437', 'latin1']
seen = set()
for e in candidates:
    if not e or e in seen: continue
    seen.add(e)
    try:
        s = data.decode(e)
        # quick sanity check: does file contain "name:" or "dependencies:" text?
        if ('dependencies' in s) or ('name:' in s) or ('flutter:' in s):
            open(path, 'w', encoding='utf-8', newline='\\n').write(s)
            print('Re-encoded pubspec.yaml from', e, '-> utf-8')
            sys.exit(0)
    except Exception as ex:
        print('failed decode with', e, ':', ex)

print('All attempts failed — file may be binary or corrupted. Restored backup at', bak)
sys.exit(1)
