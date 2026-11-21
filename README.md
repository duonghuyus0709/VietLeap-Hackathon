# Nghịch lý nâng hạng (VietLeap Hackathon 2026, Nhóm 7)

Dashboard tương tác trả lời câu hỏi: vì sao khối ngoại vẫn bán ròng dù Việt Nam được FTSE Russell nâng hạng, dòng vốn nghẽn ở đâu và nên nới đòn bẩy chính sách nào trước.

Người ra quyết định: Ủy ban Chứng khoán Nhà nước, Bộ Tài chính. Giao diện bám phong cách hai dashboard mẫu trong handout của cuộc thi (Vietnam Land Brief và Viet Nam PFM benchmark): nền trắng, không có chế độ tối, năm panel chuyển bằng tab, mỗi panel mở đầu bằng đoạn dẫn có số in đậm, mỗi biểu đồ có dòng "Cách đọc", nguồn ở cuối panel.

## Mở sản phẩm
Mở file `index.html` bằng trình duyệt. File tự chứa toàn bộ dữ liệu và mã. Chỉ phông chữ IBM Plex tải từ Google Fonts, nếu không có mạng trang vẫn chạy với phông thay thế.

Để có đường link cho giám khảo, kéo thả thư mục này lên Netlify Drop hoặc đưa lên GitHub Pages. Trang chính là `index.html`.

## Dashboard: ba ưu tiên chính sách
Một trang, dựng từ Mục 10 (Hàm ý chính sách) của `analysis/nghich_ly_nang_hang (1).Rmd`. Mỗi ưu tiên chỉ gồm biểu đồ và một ô "Cần làm" rút ra từ biểu đồ. Biểu đồ: ApexCharts 8.9.1 (Community License), nhúng sẵn trong `index.html`.
- Bối cảnh: bán ròng so với vốn FTSE; vốn bị chặn theo kênh (loại mã, hấp thụ); thẻ tóm tắt ba ưu tiên.
- Ưu tiên 1, nới room có mục tiêu: bậc thang cộng dồn ba bước (Bước 0 và 1 lấy lại 61% vốn không cần sửa luật); trần cần có so với trần luật định theo mã; hệ số room cạn theo ngưỡng kèm dải tin cậy; tác động của từng đòn bẩy ở US$1,5 và 6 tỷ.
- Ưu tiên 2, lộ trình và thanh khoản: độ phủ theo tổng vốn (ngưỡng khoảng US$1,7 tỷ); độ phủ theo số phiên giải ngân H.
- Ưu tiên 3, cảnh báo sớm: heatmap đèn đỏ, vàng của room theo mã và tháng; tỷ trọng thỏa thuận và xác suất Logit theo nhóm room.
- Lộ trình: biểu đồ Gantt theo bốn đợt giải ngân FTSE, và hai ranh giới (không nới đồng loạt, không kỳ vọng nới room tự đảo chiều dòng bán).

## Cấu trúc
```
.
├── index.html                  # SẢN PHẨM: dashboard tự chứa (dữ liệu + ApexCharts nhúng sẵn), mở trực tiếp hoặc qua GitHub Pages
├── README.md
├── VietLeap.Rproj              # dự án RStudio
├── dashboard/                  # mã nguồn dashboard
│   ├── dashboard.src.html      # giao diện và mô hình tính toán (HTML, CSS, JavaScript)
│   └── vendor/                 # apexcharts.min.js 8.9.1 và giấy phép Community
├── analysis/                   # báo cáo kinh tế lượng
│   ├── nghich_ly_nang_hang.Rmd # R Markdown đầy đủ, gồm Mục 10 Hàm ý chính sách
│   └── nghich_ly_nang_hang.R   # toàn bộ mã R, tách từ .Rmd bằng knitr::purl
├── data/
│   ├── raw/                    # phản hồi JSON nguyên bản từ FiinQuant MCP, chốt 19/11/2026
│   ├── csv/                    # cùng dữ liệu ở dạng CSV, đầu vào của báo cáo R
│   └── processed/data.json     # dữ liệu đã hợp nhất, đầu vào của dashboard
├── scripts/
│   ├── build_data.py           # data/raw → data/processed/data.json
│   ├── json_to_csv.py          # data/raw + data/processed → data/csv
│   ├── stage1_numbers.py       # in các con số kiểm, so với docs/stage1_numbers.txt
│   └── build_html.py           # dashboard/ + data.json + ApexCharts → index.html
└── docs/
    ├── nghich_ly_nang_hang.html  # báo cáo đã render (dashboard liên kết tới đây)
    ├── nghich_ly_nang_hang.docx  # báo cáo bản Word
    ├── prompt_dashboard.md       # prompt dựng dashboard (nhật ký dùng AI)
    └── stage1_numbers.txt        # số kiểm giai đoạn 1 để đối chiếu
```

## Dựng lại
Chạy từ gốc repo:

    python3 scripts/build_data.py       # data/raw → data/processed/data.json
    python3 scripts/json_to_csv.py      # data/raw → data/csv
    python3 scripts/stage1_numbers.py   # in các con số kiểm, so với docs/stage1_numbers.txt
    python3 scripts/build_html.py       # tạo index.html

Báo cáo kinh tế lượng (cần R với rmarkdown, fixest, sandwich, lmtest, car, patchwork):

    cd analysis && Rscript -e 'rmarkdown::render("nghich_ly_nang_hang.Rmd", output_dir = "../docs")'
    Rscript -e 'knitr::purl("nghich_ly_nang_hang.Rmd", output = "nghich_ly_nang_hang.R")'

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
- Đồng bộ báo cáo R với dashboard: báo cáo đọc `data/csv`, dùng GTGD khớp lệnh và US$1,5 tỷ; thêm số cả ba sàn, kịch bản US$2,2 / 6 tỷ, rổ FTSE 27 mã và bảng 8 mã bị loại vì headroom (khoảng 237 triệu US$). Thay "124 mã chiếm 89,7%" (mẫu số không cùng phạm vi) bằng "88 mã HOSE chiếm 92,0% ròng HOSE". Các câu về VIC, điểm nóng và kiểm định RESET nay do mã sinh ra thay vì viết cứng.
