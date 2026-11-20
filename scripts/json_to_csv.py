"""scripts/json_to_csv.py: chuyển toàn bộ JSON trong src/data (raw + processed) sang CSV UTF-8 (có BOM để Excel đọc đúng tiếng Việt) tại src/data/csv/."""
import csv, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'src' / 'data'
OUT = DATA / 'csv'
OUT.mkdir(exist_ok=True)


def write(name, rows):
    cols = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    with open(OUT / name, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(f'{name}: {len(rows)} dòng, {len(cols)} cột')


def load(p):
    return json.load(open(DATA / p, encoding='utf-8'))


# raw: bảng nằm trong data.records (FiinQuantX) hoặc rows (snap400)
for f in ['ff_1', 'ff_2', 'ff_3a', 'screener400', 'vnindex_ff']:
    write(f + '.csv', load(f'raw/{f}.json')['data']['records'])
write('snap400.csv', load('raw/snap400.json')['rows'])
write('hnx_upcom_ff_net.csv', load('raw/hnx_upcom_ff_net.json')['records'])

# processed
d = load('processed/data.json')
FLOW = ['net_matched', 'net_deal', 'room_remaining', 'deal_share']
stocks = []
for s in d['stocks']:
    r = {k: v for k, v in s.items() if k != 'flow'}
    for m in range(1, 12):
        x = (s['flow'] or [None] * 11)[m - 1]
        for i, k in enumerate(FLOW):
            r[f'm{m:02d}_{k}'] = None if x is None else x[i]
    stocks.append(r)
write('stocks.csv', stocks)
write('monthly.csv', d['monthly'])
write('evidence.csv', [dict(bucket=k, **v) for k, v in d['evidence'].items()])
