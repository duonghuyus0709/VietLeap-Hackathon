"""stage1_numbers.py: Stage 1 của prompt, tính và in các bảng số trước khi dựng HTML.
Đầu vào: data/processed/data.json (từ scripts/build_data.py). Không tạo số nào ngoài dữ liệu và công thức trong prompt."""
import json, statistics as st
from collections import defaultdict
from pathlib import Path
D = json.load(open(Path(__file__).resolve().parent.parent / 'data' / 'processed' / 'data.json', encoding='utf-8')); S = D['stocks']; M = D['monthly']
PAR = dict(N=100, stage=1.0, H=250, p=10, dr=0, df=0, g=0, eps=.5, tgtUsd=1.5, fx=25650, minA=10)

def model(**kw):
    o = dict(PAR, **kw)
    U = [s for s in (S if o['N'] == 'ftse' else S[:o['N']]) if (s['ftse'] or o['N'] != 'ftse') and s['adtv'] >= o['minA']]
    tgt = o['tgtUsd'] * o['stage'] * o['fx']
    sF = sum(s['ff'] * s['mc'] for s in U); rows = []
    for s in U:
        ff = s['ff']; room = min(s['room'] + o['dr'] / 100, max(0, 1 - s['fown'])); fl = min(ff + o['df'] / 100, 1)
        adtv = s['adtv'] * ((fl / ff) ** o['eps'] if ff > 0 else 1) * (1 + o['g'] / 100)
        R, F, L = room * s['mc'], fl * s['mc'], o['p'] / 100 * adtv * o['H']
        cap, b = R, 'room'
        if F < cap: cap, b = F, 'float'
        if L < cap: cap, b = L, 'liq'
        dem = tgt * ff * s['mc'] / sF; ab = min(dem, cap)
        rows.append(dict(s=s, R=R, F=F, L=L, cap=cap, bind=b, dem=dem, ab=ab, gap=dem - ab))
    return rows, tgt

print('=== 1. Dòng vốn ngoại sàn HOSE, VN-Index (nghìn tỷ đồng) ===')
ytd = sum(m['net'] for m in M) / 1000; ym = sum(m['nm'] for m in M) / 1000; yd = sum(m['nd'] for m in M) / 1000
print(f'Ròng cả kỳ {ytd:.1f}; khớp lệnh {ym:.1f}; thỏa thuận {yd:.1f}; tỷ trọng thỏa thuận {yd/ytd*100:.0f}%')
print('Tháng bán ròng:', sum(m['net'] < 0 for m in M), '/ 11; tháng mạnh nhất:', min(M, key=lambda m: m['net'])['m'], round(min(m['net'] for m in M) / 1000, 1))
oth = sum(m['oth'] for m in M) / 1000
print(f'Cả ba sàn (cộng HNX và UPCoM {oth:+.2f}): {ytd + oth:.1f}; tháng âm:', sum(m['net'] + m['oth'] < 0 for m in M), '/ 11')
print('Kiểm tra nm + nd = net (sai lệch lớn nhất, tỷ đồng):', max(abs(m['nm'] + m['nd'] - m['net']) for m in M))

print('\n=== 2. Bằng chứng room và thỏa thuận ===')
for k, lab in [('gankin', 'room còn dưới 10%'), ('hep', '10% đến 30%'), ('rong', 'từ 30% trở lên')]:
    e = D['evidence'][k]; print(f"{lab:20s} quan sát {e['n']:4d} mã {e['stocks']:3d} gộp {e['pooled']*100:5.1f}% trung vị {e['median']*100:5.1f}% ròng/giao dịch {e['netShare']*100:5.1f}%")

print('\n=== 3. Mã có dòng vốn theo tháng ===')
F = [s for s in S if s['flow']]; tot = sum(s['net'] for s in F) / 1000
FH = [s for s in F if s['ex'] == 'HOSE']; th = sum(s['net'] for s in FH) / 1000
print(f'{len(F)} mã có dòng vốn theo tháng; {len(FH)} mã HOSE, ròng {th:.1f} nghìn tỷ ({th/ytd*100:.1f}% ròng HOSE)')
byn = sorted(F, key=lambda s: s['net'])
print('Bán ròng nhiều nhất:', [(s['t'], round(s['net'] / 1000, 1)) for s in byn[:8]])
print('Mua ròng nhiều nhất:', [(s['t'], round(s['net'] / 1000, 1)) for s in byn[-6:]])
sell = sum(s['net'] for s in F if s['net'] < 0); print('Top 10 bán ròng chiếm', round(sum(s['net'] for s in byn[:10]) / sell * 100), '% tổng bán ròng của các mã bán ròng')

print('\n=== 4. Rổ mô phỏng, thiết lập cơ sở ===')
rows, tgt = model()
cnt = defaultdict(int); gb = defaultdict(float); cb = defaultdict(float)
for r in rows: cnt[r['bind']] += 1; gb[r['bind']] += r['gap']; cb[r['bind']] += r['cap']
ab = sum(r['ab'] for r in rows); gap = sum(r['gap'] for r in rows)
print(f'Rổ {len(rows)} mã, mục tiêu {tgt/1000:.1f} nghìn tỷ, hấp thụ {ab/1000:.1f}, độ phủ {ab/tgt*100:.1f}%, bỏ lỡ {gap/1000:.1f}')
print('Nút thắt:', dict(cnt), '| bỏ lỡ:', {k: round(v / 1000, 1) for k, v in gb.items()}, '| dư địa:', {k: round(v / 1000, 1) for k, v in cb.items()})
print('Kiểm tra tổng nhu cầu = mục tiêu:', abs(sum(r['dem'] for r in rows) - tgt) < 1e-6, '| cap <= min(R,F,L):', all(r['cap'] <= min(r['R'], r['F'], r['L']) + 1e-9 for r in rows))
print('12 mã bỏ lỡ nhiều nhất:', [(r['s']['t'], r['bind'], round(r['gap'] / 1000, 1)) for r in sorted(rows, key=lambda r: -r['gap'])[:12]])
ind = defaultdict(lambda: [0, 0.0, 0.0])
for r in rows: a = ind[r['s']['ind']]; a[0] += 1; a[1] += r['dem']; a[2] += r['gap']
print('Theo ngành (số mã, nhu cầu, bỏ lỡ nghìn tỷ):', [(k, v[0], round(v[1] / 1000, 1), round(v[2] / 1000, 1)) for k, v in sorted(ind.items(), key=lambda x: -x[1][2])[:6]])
med = st.median(r['dem'] for r in rows)
hot = [r for r in rows if r['bind'] == 'room' and r['dem'] >= med]
print('Điểm nóng (room chặn và nhu cầu từ trung vị trở lên):', len(hot), [r['s']['t'] for r in sorted(hot, key=lambda r: -r['gap'])])

print('\n=== 5. Đòn bẩy, độ phủ tăng thêm (điểm %) ===')
b0 = ab / tgt
for name, kw in [('room +5', dict(dr=5)), ('free float +10', dict(df=10)), ('thanh khoản +20%', dict(g=20)), ('cả ba', dict(dr=5, df=10, g=20))]:
    rr, t = model(**kw); print(f'{name:18s} độ phủ {sum(r["ab"] for r in rr)/t*100:5.1f}%  tăng {(sum(r["ab"] for r in rr)/t-b0)*100:+.1f}')
for H in (20, 60, 120, 250, 500):
    print('H', H, [round(sum(r['ab'] for r in model(H=H, p=p)[0]) / model(H=H, p=p)[1] * 100) for p in (5, 10, 15, 20, 25)])

print('\n=== 6. Dữ liệu thiếu ===')
print('GTGD trống hoặc bằng 0:', [s['t'] for s in S if not s['adtv']], '| free float trống:', [s['t'] for s in S if not s['ff']][:10])
print('Mã không có dòng vốn theo tháng:', len(S) - len(F), '| mã dưới ngưỡng GTGD 10 tỷ trong top 100:', sum(1 for s in S[:100] if s['adtv'] < 10))

def cov(**kw):
    r, t = model(**kw); return sum(x['ab'] for x in r) / t, r
print('\n=== 7. Kịch bản tổng vốn (mặc định US$1,5 tỷ thụ động) và rổ FTSE ===')
for lab, kw in [('US$1,5 tỷ', {}), ('US$2,2 tỷ', dict(tgtUsd=2.2)), ('US$6 tỷ gồm chủ động', dict(tgtUsd=6)), ('Rổ FTSE 27 mã, US$1,5 tỷ', dict(N='ftse'))]:
    c, r = cov(**kw); blk = defaultdict(int)
    for x in r:
        if x['gap'] > 1e-6: blk[x['bind']] += 1
    lev = {n: round((cov(**dict(kw, **k))[0] - c) * 100, 1) for n, k in [('room+5', dict(dr=5)), ('ff+10', dict(df=10)), ('tk+20%', dict(g=20)), ('cả ba', dict(dr=5, df=10, g=20))]}
    print(f'{lab:26s} rổ {len(r)} mã, độ phủ {c*100:.1f}%, mã thực sự thiếu dư địa {dict(blk)}, tăng thêm {lev}')

print('\n=== 8. Kiểm chứng FTSE: headroom ngày 30/6/2026 (tháng 6) ===')
FOL = lambda s: s['room'] + s['fown']; HR6 = lambda s: s['flow'][5][2] if s['flow'] and s['flow'][5] and s['flow'][5][2] is not None else None
FT = [s for s in S if s['ftse']]
print('27 mã FTSE: headroom nhỏ nhất', min((HR6(s), s['t']) for s in FT))
out = [s for s in sorted(S, key=lambda s: -s['mc'])[:60] if s['ex'] == 'HOSE' and not s['ftse'] and HR6(s) is not None]
lost = [s for s in out if HR6(s) < .2 and FOL(s) >= .1]
inv = lambda s: s['mc'] * min(s['ff'], FOL(s)); I27 = sum(inv(s) for s in FT)
for s in sorted(lost, key=lambda s: -inv(s)):
    need = max(0, (.2 * FOL(s) - s['room']) / .8)
    print(f"{s['t']:4s} headroom 30/6 {HR6(s)*100:5.1f}%  19/11 {s['room']/FOL(s)*100:5.1f}%  trần {FOL(s)*100:4.1f}%  cần nới {need*100:5.2f} điểm  vốn ~{1500*inv(s)/I27:4.0f} triệu US$")
print('Tổng vốn thụ động ước tính (US$1,5 tỷ):', round(sum(1500 * inv(s) / I27 for s in lost)), 'triệu US$')
