"""build_html.py: nhúng data.json vào dashboard.src.html để tạo index.html tự chứa (không cần máy chủ, không cần mạng, trừ Google Fonts)."""
tpl = open('dashboard.src.html', encoding='utf-8').read()
data = open('data.json', encoding='utf-8').read().strip()
assert '/*__DATA__*/' in tpl
open('index.html', 'w', encoding='utf-8').write(tpl.replace('/*__DATA__*/', data))
print('index.html', len(tpl) + len(data), 'bytes')
