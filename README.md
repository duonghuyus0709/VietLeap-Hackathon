# Nghịch lý nâng hạng (VietLeap Hackathon 2026, Nhóm 7)

Dashboard tương tác trả lời câu hỏi: vì sao khối ngoại vẫn bán ròng dù Việt Nam được FTSE Russell nâng hạng, dòng vốn nghẽn ở đâu và nên nới đòn bẩy chính sách nào trước.

Người ra quyết định: Ủy ban Chứng khoán Nhà nước, Bộ Tài chính. Giao diện bám phong cách hai dashboard mẫu trong handout của cuộc thi (Vietnam Land Brief và Viet Nam PFM benchmark): nền trắng, không có chế độ tối, bốn panel chuyển bằng tab, mỗi panel mở đầu bằng đoạn dẫn có số in đậm, mỗi biểu đồ có dòng "Cách đọc", nguồn ở cuối panel.

## Mở sản phẩm
Mở file `index.html` bằng trình duyệt. File tự chứa toàn bộ dữ liệu và mã. Chỉ phông chữ IBM Plex tải từ Google Fonts, nếu không có mạng trang vẫn chạy với phông thay thế.

Để có đường link cho giám khảo, kéo thả thư mục này lên Netlify Drop hoặc đưa lên GitHub Pages. Trang chính là `index.html`.

## Bốn panel
1. Nghịch lý: ròng khối ngoại theo tháng (khớp lệnh và thỏa thuận), mã bán và mua nhiều nhất.
2. Điểm nghẽn: tỷ trọng thỏa thuận theo room còn lại, biểu đồ phân tán 1.169 quan sát mã theo tháng, ca TCB.
3. Mô phỏng: ba thanh trượt đòn bẩy ở đầu cột trái (cố định khi cuộn), hai nhóm giả định có thể thu gọn. Cột phải có độ phủ cơ sở và sau đòn bẩy, bảng xếp hạng đòn bẩy nên nới trước, nút thắt, 12 mã bị bỏ lỡ nhiều nhất và độ nhạy theo H và p. Tất cả đổi theo thanh trượt.
4. Từng mã: danh sách xếp theo phần bỏ lỡ, chi tiết R, F, L và dòng vốn theo tháng của mã đã chọn, bảng đầy đủ có tải CSV, ghi chú phương pháp và giới hạn.

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
│       │   └── vnindex_ff.json     # get_market_statistics(['VNINDEX'], foreign_flow, Monthly), tổng toàn thị trường
│       └── processed/
│           └── data.json       # dữ liệu đã hợp nhất cho dashboard
├── scripts/
│   ├── build_data.py           # src/data/raw → src/data/processed/data.json
│   ├── stage1_numbers.py       # giai đoạn 1 của prompt: tính và in các con số kiểm trước khi vẽ
│   └── build_html.py           # nhúng data.json vào src/dashboard.src.html → index.html
└── docs/
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

## Truy vết các con số chính
| Số trên trang | Nguồn và công thức |
|---|---|
| Ròng khối ngoại −126,0 nghìn tỷ, 11 trên 11 tháng âm | `monthly[].net`, tổng theo tháng, VN-Index, FiinQuantX foreign_flow |
| Thỏa thuận 24% | tổng `monthly[].nd` ÷ tổng `monthly[].net` = −29,8 ÷ −126,0 |
| 124 mã chiếm 89,7% | tổng `stocks[].net` của mã có `flow` ÷ tổng ròng toàn thị trường |
| 36,0%, 21,8%, 14,0% | `evidence`: giá trị thỏa thuận ÷ giá trị mua và bán của khối ngoại, gộp theo nhóm room còn lại |
| 1.169 quan sát, 23% và 3% | các cặp (room còn lại, tỷ trọng thỏa thuận) của 124 mã × 11 tháng; tỷ lệ quan sát có tỷ trọng từ 50% trở lên |
| Độ phủ 76,7% | tổng min(nhu cầu, dư địa) ÷ mục tiêu, rổ 81 mã, H = 250, p = 10%, ngưỡng GTGD 10 tỷ, US$6 tỷ × 25.650 |
| 88,1% sau đòn bẩy | như trên với room +5 điểm, free float +10 điểm, thanh khoản +20%, độ co giãn 0,5 |
| VIC chiếm 62% phần bỏ lỡ | phần bỏ lỡ của VIC ÷ tổng phần bỏ lỡ của rổ ở thiết lập cơ sở |

## Dữ liệu lấy từ FiinQuantX
- `screen_stocks`: vốn hóa, room nước ngoài còn lại, sở hữu nước ngoài, giá trị giao dịch bình quân, cho 400 mã vốn hóa lớn nhất.
- `get_equity_snapshot`: tỷ lệ free float, số cổ phiếu lưu hành.
- `get_market_statistics` với metric `foreign_flow`, theo tháng từ 1/1 đến 19/11/2026: dòng vốn ngoại tách khớp lệnh và thỏa thuận, room theo cuối tháng. Có cho 124 mã lớn nhất và cho VN-Index.

## Mô hình
- R = room còn lại × vốn hóa. F = free float × vốn hóa. L = p × GTGD bình quân ngày × H.
- Dư địa hấp thụ = nhỏ nhất của R, F, L. Giới hạn nhỏ nhất là nút thắt.
- Nhu cầu mô phỏng của mã = mục tiêu × F của mã ÷ tổng F của rổ.
- Độ phủ = tổng phần hấp thụ ÷ tổng nhu cầu.
- Ba đòn bẩy: nới room, tăng free float, tăng thanh khoản.

## Giới hạn
Free float có thể đã gồm phần khối ngoại nắm, nên F là mức trần. Cửa sổ tính GTGD bình quân do nhà cung cấp quyết định. p, H và độ co giãn là giả định của nhóm. Phân bổ nhu cầu theo free float là mô phỏng, không phải danh mục FTSE thật. Một mã (VIC ở thiết lập mặc định) chiếm phần lớn phần bỏ lỡ của cả rổ. Bằng chứng ở panel 02 là quan hệ thống kê, chưa phải quan hệ nhân quả.

## Sử dụng AI và dữ liệu
Dashboard được dựng với sự hỗ trợ của Claude (Anthropic) theo prompt trong `prompt_dashboard.md`. Dữ liệu từ FiinQuantX chỉ dùng cho mục đích cuộc thi theo điều khoản giấy phép của nhà cung cấp. Nhật ký prompt AI đầy đủ cần được nhóm xuất riêng từ cuộc trò chuyện để nộp theo yêu cầu cuộc thi.
