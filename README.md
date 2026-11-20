# Nghịch lý nâng hạng (VietLeap Hackathon 2026, Nhóm 7)

Dashboard tương tác trả lời câu hỏi: vì sao khối ngoại vẫn bán ròng dù Việt Nam được FTSE Russell nâng hạng, dòng vốn nghẽn ở đâu và nên nới đòn bẩy chính sách nào trước.

Người ra quyết định: Ủy ban Chứng khoán Nhà nước, Bộ Tài chính. Giao diện bám phong cách hai dashboard mẫu trong handout của cuộc thi (Vietnam Land Brief và Viet Nam PFM benchmark): nền trắng, không có chế độ tối, bốn panel chuyển bằng tab, mỗi panel mở đầu bằng đoạn dẫn có số in đậm, mỗi biểu đồ có dòng "Cách đọc", nguồn ở cuối panel.

## Mở sản phẩm
Mở file `index.html` bằng trình duyệt. File tự chứa toàn bộ dữ liệu và mã. Chỉ phông chữ IBM Plex tải từ Google Fonts, nếu không có mạng trang vẫn chạy với phông thay thế.

Để có đường link cho giám khảo, kéo thả thư mục này lên Netlify Drop hoặc đưa lên GitHub Pages. Trang chính là `index.html`.

## Bốn panel
Bố cục theo khung "From data to decision" của giám khảo (một màn hình cho mỗi câu trả lời; mức, so sánh, xu hướng, quyết định; câu khuyến nghị ở đầu trang). Một dải khuyến nghị cố định ở đầu mọi panel.
1. Nghịch lý: câu dẫn có số, bốn ô số (mức, so với gì, xu hướng, kênh), ròng khối ngoại HOSE theo tháng, mã bán và mua nhiều nhất.
2. Điểm nghẽn: tỷ trọng thỏa thuận theo ba nhóm room, hệ số theo ngưỡng, biểu đồ phân tán 1.169 quan sát, xếp hạng headroom ngày 30/6 so với ngưỡng FTSE 20%. Bên dưới: 14 đặc tả kiểm định, ca TCB, Logit, 8 mã bị FTSE loại.
3. Quyết định: sơ đồ ba cửa của dòng vốn thụ động (vào rổ FTSE, còn room, đủ thanh khoản), bốn kịch bản (US$1,5 / 2,2 / 6 tỷ, rổ 27 mã FTSE), ba thanh trượt đòn bẩy, xếp hạng đòn bẩy và danh sách hành động theo mã. Bên dưới: bảng kịch bản, bản đồ nhiệt H và p, nút thắt.
4. Tra cứu: từng mã (R, F, L, dòng vốn theo tháng), bảng đầy đủ tải CSV, bảy giả thuyết H1 đến H7, phương pháp và giới hạn.

Khi thuyết trình: phím 1 đến 4 chuyển panel, phím P bật chế độ trình chiếu (ẩn phần chi tiết, chữ lớn hơn).

## Cấu trúc
```
.
├── index.html                  # sản phẩm hoàn chỉnh, dữ liệu đã nhúng (file build, để ở gốc cho GitHub Pages / Netlify)
├── README.md
├── src/
│   ├── dashboard.src.html      # mã nguồn giao diện và mô hình tính toán (HTML, CSS, JavaScript thuần, SVG tự vẽ)
│   └── data/
│       ├── raw/                # phản hồi JSON nguyên bản từ FiinQuant MCP, ngày dữ liệu 19/11/2026
│       │   ├── screener400.json    # screen_stocks: vốn hóa, room còn lại, sở hữu ngoại, GTGD bình quân, 400 mã vốn hóa lớn nhất
│       │   ├── snap400.json        # get_equity_snapshot: free_float_ratio, outstanding_shares, avg_matched_value
│       │   ├── ff_1.json, ff_2.json, ff_3a.json  # get_market_statistics(foreign_flow, Monthly), 124 mã lớn nhất
│       │   ├── vnindex_ff.json     # get_market_statistics(['VNINDEX'], foreign_flow, Monthly), sàn HOSE
│       │   └── hnx_upcom_ff_net.json  # ròng khối ngoại theo tháng của HNXINDEX và UPCOMINDEX, để cộng ra cả ba sàn
│       └── processed/
│           └── data.json       # dữ liệu đã hợp nhất cho dashboard
├── analysis/
│   ├── nghich_ly_nang_hang.Rmd # báo cáo kinh tế lượng (R Markdown), đọc src/data/csv, render ra docs/nghich_ly_nang_hang.html
│   └── nghich_ly_nang_hang.R   # toàn bộ mã R tách từ file .Rmd (knitr::purl), chạy độc lập bằng Rscript
├── scripts/
│   ├── build_data.py           # src/data/raw → src/data/processed/data.json
│   ├── stage1_numbers.py       # giai đoạn 1 của prompt: tính và in các con số kiểm trước khi vẽ
│   └── build_html.py           # nhúng data.json vào src/dashboard.src.html → index.html
└── docs/
    ├── nghich_ly_nang_hang.html  # báo cáo kinh tế lượng (R), nguồn của panel 03
    ├── prompt_dashboard.md     # prompt dựng dashboard (sáu phần ROLE, CONTEXT, TASK, DATA, OUTPUT, QUALITY CHECKS, năm giai đoạn)
    └── stage1_numbers.txt      # kết quả của scripts/stage1_numbers.py để đối chiếu
```

Đơn vị trong `data.json`: giá trị tính bằng tỷ đồng, tỷ lệ là số thập phân. Trong file thô, giá trị tính bằng đồng.

`screener400.json` là 400 mã có vốn hóa lớn nhất, lọc từ toàn bộ 1.541 mã mà `screen_stocks` trả về (bỏ ETF và mã không có vốn hóa). F88 nằm trong top 125 nhưng FiinQuantX không có dữ liệu foreign_flow theo tháng, nên còn 124 mã.

## Dựng lại
Chạy từ gốc repo:

    python3 scripts/build_data.py       # src/data/raw → src/data/processed/data.json
    python3 scripts/stage1_numbers.py   # in các con số kiểm, so với docs/stage1_numbers.txt
    python3 scripts/build_html.py       # tạo index.html

Báo cáo kinh tế lượng (cần R với rmarkdown, fixest, sandwich, lmtest, car, patchwork):

    python3 scripts/json_to_csv.py      # src/data/raw → src/data/csv
    cd analysis && Rscript -e 'rmarkdown::render("nghich_ly_nang_hang.Rmd", output_dir = "../docs")'

Bảng 4.4 của báo cáo đối chiếu 20 chỉ tiêu tính lại trong R với `docs/stage1_numbers.txt`; cả 20 khớp.

## Truy vết các con số chính
| Số trên trang | Nguồn và công thức |
|---|---|
| Ròng khối ngoại HOSE −126,0 nghìn tỷ, 11 trên 11 tháng âm | `monthly[].net`, tổng theo tháng, VN-Index (sàn HOSE), FiinQuantX foreign_flow |
| Cả ba sàn −123,4 nghìn tỷ, 11 trên 11 tháng âm | `monthly[].net` + `monthly[].oth` (HNXINDEX và UPCOMINDEX) |
| Thỏa thuận 24% | tổng `monthly[].nd` ÷ tổng `monthly[].net` = −29,8 ÷ −126,0 |
| 88 mã HOSE chiếm 92,0% | tổng `stocks[].net` của mã HOSE có `flow` ÷ ròng HOSE |
| 36,0%, 21,8%, 14,0% | `evidence`: giá trị thỏa thuận ÷ giá trị mua và bán của khối ngoại, gộp theo nhóm room còn lại |
| 1.169 quan sát, 23% và 3% | các cặp (room còn lại, tỷ trọng thỏa thuận) của 124 mã × 11 tháng; tỷ lệ quan sát có tỷ trọng từ 50% trở lên |
| Độ phủ 96,4% | tổng min(nhu cầu, dư địa) ÷ mục tiêu, rổ 77 mã (100 mã lớn nhất có GTGD khớp lệnh từ 10 tỷ), H = 250, p = 10%, US$1,5 tỷ × 25.650 |
| 100,0% sau đòn bẩy (room +3,6 điểm) | như trên với room +5 điểm, free float +10 điểm, thanh khoản +20%, độ co giãn 0,5 |
| Kịch bản US$6 tỷ: 72,7%, sau đòn bẩy 85,4% | như trên với tổng vốn gồm cả quỹ chủ động |
| Rổ FTSE 27 mã: 97,4% | như trên, rổ là 27 mã FTSE chọn |
| 27 mã FTSE đều có headroom từ 20,2% trở lên | `stocks[].flow[5][2]` (room còn lại ÷ tổng room, tháng 6) của các mã `ftse` |
| 8 mã lớn bị loại, khoảng 237 triệu US$ | headroom tháng 6 dưới 20%, giới hạn sở hữu từ 10%; vốn = 1,5 tỷ × vốn hóa × min(free float, giới hạn) ÷ tổng của 27 mã |

## Dữ liệu lấy từ FiinQuantX
- `screen_stocks`: vốn hóa, room nước ngoài còn lại, sở hữu nước ngoài, giá trị giao dịch bình quân, cho 400 mã vốn hóa lớn nhất.
- `get_equity_snapshot`: tỷ lệ free float, số cổ phiếu lưu hành, giá trị giao dịch khớp lệnh bình quân (dùng cho L, vì quỹ thụ động mua trên sổ lệnh).
- `get_market_statistics` với metric `foreign_flow`, theo tháng từ 1/1 đến 19/11/2026: dòng vốn ngoại tách khớp lệnh và thỏa thuận, room theo cuối tháng. Có cho 124 mã lớn nhất, VN-Index (sàn HOSE), HNXINDEX và UPCOMINDEX.
- Danh sách 27 mã FTSE Global All Cap lấy từ FAQ chính thức của FTSE Russell (Reclassification of Vietnam, v1.3, 25/8/2026); FTSE xét headroom với dữ liệu chốt 30/6/2026.

## Mô hình
- R = room còn lại × vốn hóa. F = free float × vốn hóa. L = p × GTGD khớp lệnh bình quân ngày × H.
- Dư địa hấp thụ = nhỏ nhất của R, F, L. Giới hạn nhỏ nhất là nút thắt.
- Nhu cầu mô phỏng của mã = mục tiêu × F của mã ÷ tổng F của rổ.
- Độ phủ = tổng phần hấp thụ ÷ tổng nhu cầu.
- Ba đòn bẩy: nới room, tăng free float, tăng thanh khoản.

## Giới hạn
Free float có thể đã gồm phần khối ngoại nắm, nên F là mức trần. Cửa sổ tính GTGD khớp lệnh bình quân do nhà cung cấp quyết định (đối chiếu dữ liệu ngày cho thấy khoảng 20 đến 30 phiên). p, H và độ co giãn là giả định của nhóm; quỹ thụ động thực tế mua tập trung vào phiên cơ cấu, nên H nên hiểu là số phiên thanh khoản cần để hấp thụ. Rổ 100 mã lớn nhất là mô phỏng; rổ FTSE 27 mã là danh mục thật. Vốn thụ động mất do room là ước lượng bậc một. Một mã có thể chiếm phần lớn phần bỏ lỡ của cả rổ (MWG ở thiết lập mặc định, VIC ở kịch bản US$6 tỷ). Bằng chứng ở panel 02 là quan hệ thống kê, chưa phải quan hệ nhân quả.

## Sử dụng AI và dữ liệu
Dashboard được dựng với sự hỗ trợ của Claude (Anthropic) theo prompt trong `prompt_dashboard.md`. Dữ liệu từ FiinQuantX chỉ dùng cho mục đích cuộc thi theo điều khoản giấy phép của nhà cung cấp. Nhật ký prompt AI đầy đủ cần được nhóm xuất riêng từ cuộc trò chuyện để nộp theo yêu cầu cuộc thi.

## Thay đổi sau kiểm định (20/11/2026)
- Sửa nhãn: số −126,0 nghìn tỷ là của sàn HOSE; thêm số cả ba sàn (−123,4).
- US$6 tỷ là ước tính của FTSE gồm cả quỹ chủ động; mặc định đổi về US$1,5 tỷ vốn thụ động, kèm bộ chọn 1,5 / 2,2 / 6.
- Thanh khoản dùng GTGD khớp lệnh bình quân thay cho GTGD tổng (có thỏa thuận).
- Đếm "mã thiếu dư địa" chỉ tính mã có nhu cầu vượt dư địa; "giới hạn chặt nhất" không còn bị gọi là "bị chặn".
- Thêm rổ FTSE 27 mã thật và thẻ kiểm chứng headroom 20% ở panel 02.
- Đổi tên cột "Sau đòn bẩy" thành "Dư địa sau đòn bẩy"; sửa hiển thị trên điện thoại.
- Đồng bộ báo cáo R với dashboard: báo cáo đọc `src/data/csv`, dùng GTGD khớp lệnh và US$1,5 tỷ; thêm số cả ba sàn, kịch bản US$2,2 / 6 tỷ, rổ FTSE 27 mã và bảng 8 mã bị loại vì headroom (khoảng 237 triệu US$). Thay "124 mã chiếm 89,7%" (mẫu số không cùng phạm vi) bằng "88 mã HOSE chiếm 92,0% ròng HOSE". Các câu về VIC, điểm nóng và kiểm định RESET nay do mã sinh ra thay vì viết cứng.
