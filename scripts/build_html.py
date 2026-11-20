"""scripts/build_html.py: nhúng src/data/processed/data.json vào src/dashboard.src.html để tạo index.html tự chứa ở gốc repo (không cần máy chủ, không cần mạng, trừ Google Fonts)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
tpl = open(ROOT / 'src' / 'dashboard.src.html', encoding='utf-8', newline='').read()
data = (ROOT / 'src' / 'data' / 'processed' / 'data.json').read_text(encoding='utf-8').strip()
assert '/*__DATA__*/' in tpl
(ROOT / 'index.html').write_text(tpl.replace('/*__DATA__*/', data), encoding='utf-8', newline='')
print('index.html', len(tpl) + len(data), 'bytes')
