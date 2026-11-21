"""scripts/build_html.py: nhúng data/processed/data.json và ApexCharts (dashboard/vendor/apexcharts.min.js) vào dashboard/dashboard.src.html
để tạo index.html tự chứa ở gốc repo (chạy được không cần mạng, trừ Google Fonts)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
tpl = open(ROOT / 'dashboard' / 'dashboard.src.html', encoding='utf-8', newline='').read()
data = (ROOT / 'data' / 'processed' / 'data.json').read_text(encoding='utf-8').strip()
apex = (ROOT / 'dashboard' / 'vendor' / 'apexcharts.min.js').read_text(encoding='utf-8').replace('</script', '<\\/script')
assert '/*__DATA__*/' in tpl and '/*__APEX__*/' in tpl
out = tpl.replace('/*__APEX__*/', apex, 1).replace('/*__DATA__*/', data, 1)
(ROOT / 'index.html').write_text(out, encoding='utf-8', newline='')
print('index.html', len(out), 'bytes')
