"""stage1_numbers.py: Stage 1 của prompt, tính và in các bảng số trước khi dựng HTML.
Đầu vào: data.json (từ build_data.py). Không tạo số nào ngoài dữ liệu và công thức trong prompt."""
import json, statistics as st
from collections import defaultdict
D = json.load(open('data.json')); S = D['stocks']; M = D['monthly']
PAR = dict(N=100, stage=1.0, H=250, p=10, dr=0, df=0, g=0, eps=.5, tgtUsd=6, fx=25650, minA=10)

def model(**kw):
    o = dict(PAR, **kw)
    U = [s for s in S[:o['N']] if s['adtv'] >= o['minA']]
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

print('=== 1. Dòng vốn ngoại toàn thị trường (nghìn tỷ đồng) ===')
ytd = sum(m['net'] for m in M) / 1000; ym = sum(m['nm'] for m in M) / 1000; yd = sum(m['nd'] for m in M) / 1000
print(f'Ròng cả kỳ {ytd:.1f}; khớp lệnh {ym:.1f}; thỏa thuận {yd:.1f}; tỷ trọng thỏa thuận {yd/ytd*100:.0f}%')
print('Tháng bán ròng:', sum(m['net'] < 0 for m in M), '/ 11; tháng mạnh nhất:', min(M, key=lambda m: m['net'])['m'], round(min(m['net'] for m in M) / 1000, 1))
print('Kiểm tra nm + nd = net (sai lệch lớn nhất, tỷ đồng):', max(abs(m['nm'] + m['nd'] - m['net']) for m in M))

print('\n=== 2. Bằng chứng room và thỏa thuận ===')
for k, lab in [('gankin', 'room còn dưới 10%'), ('hep', '10% đến 30%'), ('rong', 'từ 30% trở lên')]:
    e = D['evidence'][k]; print(f"{lab:20s} quan sát {e['n']:4d} mã {e['stocks']:3d} gộp {e['pooled']*100:5.1f}% trung vị {e['median']*100:5.1f}% ròng/giao dịch {e['netShare']*100:5.1f}%")

print('\n=== 3. Mã có dòng vốn theo tháng ===')
F = [s for s in S if s['flow']]; tot = sum(s['net'] for s in F) / 1000
print(f'{len(F)} mã, tổng ròng {tot:.1f} nghìn tỷ ({tot/ytd*100:.1f}% toàn thị trường)')
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
