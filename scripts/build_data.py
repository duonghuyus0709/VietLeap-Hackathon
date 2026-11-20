"""scripts/build_data.py
Ghép dữ liệu FiinQuantX thô trong src/data/raw thành src/data/processed/data.json cho dashboard.

Đầu vào (phản hồi JSON nguyên bản từ FiinQuant MCP, ngày dữ liệu 19/11/2026, nằm trong src/data/raw):
  screener400.json  : screen_stocks (vốn hóa, room còn lại, sở hữu ngoại, GTGD bình quân) cho 400 mã vốn hóa lớn nhất
  snap400.json      : get_equity_snapshot (free_float_ratio, outstanding_shares, avg_matched_value)
  ff_1.json, ff_2.json, ff_3a.json : get_market_statistics(metric='foreign_flow', Monthly) cho 124 mã lớn nhất
  vnindex_ff.json   : get_market_statistics(['VNINDEX'], 'foreign_flow', Monthly) = tổng toàn thị trường
Đơn vị trong data.json: giá trị tính bằng tỷ đồng, tỷ lệ là số thập phân.
"""
import json, statistics as st
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / 'src' / 'data' / 'raw'
OUT = ROOT / 'src' / 'data' / 'processed' / 'data.json'
TY = 1e9  # VND -> tỷ đồng

def load(name):
    return json.load(open(RAW / name, encoding='utf-8'))

scr = load('screener400.json')['data']['records']  # đã xếp theo market_cap giảm dần
snap = {r['ticker']: r for r in load('snap400.json')['rows']}
flows = defaultdict(dict)
for f in ['ff_1.json', 'ff_2.json', 'ff_3a.json']:
    for r in load(f)['data']['records']:
        flows[r['ticker']][r['month']] = r
vn = {r['month']: r for r in load('vnindex_ff.json')['data']['records']}

def bucket(x):
    return 'gankin' if x < 0.10 else ('hep' if x < 0.30 else 'rong')

stocks, panel = [], defaultdict(list)
for rank, s in enumerate(scr, start=1):
    t = s['ticker']; n = snap.get(t, {})
    mc = s['market_cap']
    ff = n.get('free_float_ratio')
    if ff is None and n.get('outstanding_shares'):
        ff = s['free_float'] / n['outstanding_shares']
    adtv = s.get('avg_trading_value') or n.get('avg_trading_value') or 0
    row = dict(t=t, n=s['name'], ex=s['exchange'], ind=s['industry'], rank=rank,
               mc=round(mc / TY, 1), ff=round(ff or 0, 4), room=round(s['foreign_room_remaining'] or 0, 4),
               fown=round(s['foreign_ownership_ratio'] or 0, 4), adtv=round(adtv / TY, 2), ytd=s.get('price_change_ytd'), flow=None, net=None)
    fl = flows.get(t)
    if fl:
        series = []
        for m in range(1, 12):
            r = fl.get(m)
            if not r:
                series.append(None); continue
            turn = r['foreignBuyValueTotal'] + r['foreignSellValueTotal']
            deal = r['foreignBuyValueDeal'] + r['foreignSellValueDeal']
            tr = r['foreignTotalRoom']
            x = r['foreignCurrentRoom'] / tr if tr else None
            nm = r['foreignBuyValueMatched'] - r['foreignSellValueMatched']
            nd = r['foreignBuyValueDeal'] - r['foreignSellValueDeal']
            series.append([round(nm / TY, 1), round(nd / TY, 1),
                           None if x is None else round(x, 4),
                           None if turn <= 0 else round(deal / turn, 4)])
            if tr and turn > 0:
                panel[bucket(x)].append((t, m, deal, turn, r['foreignNetValueTotal']))
        row['flow'] = series
        row['net'] = round(sum(r['foreignNetValueTotal'] for r in fl.values()) / TY, 1)
    stocks.append(row)

monthly = []
for m in range(1, 12):
    r = vn[m]
    monthly.append(dict(m=m, buy=round(r['foreignBuyValueTotal'] / TY, 1), sell=round(r['foreignSellValueTotal'] / TY, 1),
                        net=round(r['foreignNetValueTotal'] / TY, 1),
                        nm=round((r['foreignBuyValueMatched'] - r['foreignSellValueMatched']) / TY, 1),
                        nd=round((r['foreignBuyValueDeal'] - r['foreignSellValueDeal']) / TY, 1)))

evidence = {}
for k, L in panel.items():
    tot = sum(x[3] for x in L)
    evidence[k] = dict(n=len(L), stocks=len(set(x[0] for x in L)),
                       pooled=round(sum(x[2] for x in L) / tot, 4),
                       median=round(st.median(x[2] / x[3] for x in L), 4),
                       netShare=round(sum(x[4] for x in L) / tot, 4),
                       buyMonths=round(sum(x[4] > 0 for x in L) / len(L), 4))

data = dict(asof='2026-11-19', stocks=stocks, monthly=monthly, evidence=evidence)
json.dump(data, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print('stocks', len(stocks), 'with flow', sum(1 for s in stocks if s['flow']))
print('YTD net (nghìn tỷ)', sum(m['net'] for m in monthly) / 1000, 'matched', sum(m['nm'] for m in monthly) / 1000, 'deal', sum(m['nd'] for m in monthly) / 1000)
print(json.dumps(evidence, indent=1))
