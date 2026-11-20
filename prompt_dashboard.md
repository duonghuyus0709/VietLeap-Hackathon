# Prompt dựng dashboard "Nghịch lý nâng hạng"

Prompt này được viết lại từ bộ prompt trong handout dashboard của VietLeap (prompts.html), giữ nguyên sáu phần ROLE, CONTEXT, TASK, DATA, OUTPUT, QUALITY CHECKS, cách dựng theo giai đoạn và nguyên tắc kiểm số trước khi vẽ. Phần đã đổi là người đọc, câu hỏi, dữ liệu và công thức. Phong cách giao diện bám theo hai dashboard mẫu của handout (Vietnam Land Brief và Viet Nam PFM benchmark).

Cách dùng: dán phần Setup một lần, sau đó dán từng giai đoạn. Sau mỗi giai đoạn, dừng lại và kiểm các con số mong đợi trước khi sang giai đoạn kế.

---

## Bước 0: khám phá dữ liệu (2 phút)

ROLE
Bạn là một nhà phân tích dữ liệu cẩn thận.

CONTEXT
Tôi là sinh viên chuẩn bị một dashboard về dòng vốn ngoại trên thị trường chứng khoán Việt Nam cho lãnh đạo Ủy ban Chứng khoán Nhà nước. Tôi chưa xem các tệp dữ liệu này.

TASK
Trước khi dựng bất cứ thứ gì, hãy giúp tôi hiểu các tệp đính kèm.

DATA
data.json (do build_data.py tạo ra từ các bản xuất FiinQuantX).

OUTPUT
Với mỗi khối dữ liệu (stocks, monthly, evidence): một dòng đại diện cho điều gì, các cột và đơn vị, giai đoạn bao phủ, số giá trị thiếu, và điều gì trông bất thường. Sau đó đề xuất ba câu hỏi mà người ra quyết định có thể trả lời bằng dữ liệu này. Chưa vẽ biểu đồ. Dưới 250 chữ.

CHECKS
Cho tôi biết bao nhiêu mã có dòng vốn theo tháng, bao nhiêu mã có giá trị giao dịch bình quân trống hoặc bằng 0, và tổng ròng khối ngoại toàn thị trường.

---

## Setup: dán một lần, đầu tiên

ROLE
Bạn là một nhà kinh tế thị trường tài chính kiêm lập trình viên front-end. Bạn dựng dashboard chính sách thành một tệp HTML duy nhất: không dùng thư viện ngoài (cho phép Google Fonts), dữ liệu nhúng sẵn trong tệp, mọi biểu đồ vẽ bằng SVG nội tuyến, mọi phép tính chạy bằng JavaScript ngay trong trang.

CONTEXT
Ngày 21/9/2026 FTSE Russell nâng hạng Việt Nam lên thị trường mới nổi thứ cấp. Vốn thụ động vào chỉ số theo bốn đợt đến tháng 9/2027 với tỷ trọng 10%, 20%, 35%, 35%, ước tính khoảng US$6 tỷ. Nhưng từ 1/1 đến 19/11/2026, khối ngoại bán ròng 126,0 nghìn tỷ đồng và cả 11 tháng đều âm. Người đọc là lãnh đạo Ủy ban Chứng khoán Nhà nước và chuyên viên Bộ Tài chính. Họ hiểu room ngoại và free float, nhưng chỉ có hai phút. Họ muốn biết ba điều: nghịch lý này có thật không, dòng vốn đang nghẽn ở đâu và ở mã nào, và nên nới đòn bẩy chính sách nào trước để vốn ngoại vào được.

TASK
Dựng "Nghịch lý nâng hạng": bốn panel chuyển bằng tab ở góc trên bên phải, không cuộn dài: 01 Nghịch lý, 02 Điểm nghẽn, 03 Mô phỏng, 04 Từng mã. Ta dựng theo năm giai đoạn. Sau mỗi giai đoạn, dừng lại, cho tôi xem kết quả cùng các phép kiểm, rồi chờ tôi.

DATA (đính kèm)
Mọi số tiền tính bằng tỷ đồng trừ khi ghi khác. Nguồn là FiinQuantX, chốt ngày 19/11/2026.
- stocks: 400 mã niêm yết lớn nhất theo vốn hóa, xếp giảm dần. Mỗi dòng gồm t (mã), n (tên), ex (sàn), ind (ngành), mc (vốn hóa), ff (tỷ lệ free float), room (room nước ngoài còn lại, tỷ lệ trên vốn điều lệ), fown (tỷ lệ sở hữu nước ngoài), adtv (giá trị giao dịch bình quân mỗi phiên), net (ròng khối ngoại cả kỳ). Trường flow chỉ có cho 124 mã lớn nhất: mỗi tháng là mảng [ròng khớp lệnh, ròng thỏa thuận, room còn lại so với tổng room, tỷ trọng thỏa thuận trong giao dịch ngoại].
- monthly: ròng khối ngoại toàn thị trường (VN-Index) theo tháng, gồm mua, bán, ròng khớp lệnh (nm) và ròng thỏa thuận (nd). Tháng 11 chỉ đến 19/11.
- evidence: tỷ trọng thỏa thuận theo ba nhóm room còn lại: dưới 10%, từ 10% đến 30%, từ 30% trở lên, gộp theo giá trị và theo trung vị quan sát.
Các vấn đề đã biết: 23 mã không có giá trị giao dịch bình quân, một số mã không có dòng vốn theo tháng, free float của nhà cung cấp có thể đã gồm phần khối ngoại đang nắm, cửa sổ tính giá trị giao dịch bình quân do nhà cung cấp quyết định.
Công thức bắt buộc, cho từng mã:
- R = room còn lại × vốn hóa
- F = free float × vốn hóa
- L = p × giá trị giao dịch bình quân × H, với p là tỷ lệ tối đa một quỹ mua trong thanh khoản mỗi ngày và H là số phiên để giải ngân
- dư địa hấp thụ = nhỏ nhất của R, F, L. Giới hạn nhỏ nhất là nút thắt của mã
- nhu cầu của mã = mục tiêu vốn × (F của mã ÷ tổng F của rổ). Mục tiêu = US$ tỷ × tỷ giá × tỷ lệ cộng dồn của đợt FTSE
- hấp thụ = nhỏ nhất của nhu cầu và dư địa. Độ phủ = tổng hấp thụ ÷ mục tiêu
- đòn bẩy: room mới = room + Δ (không vượt phần chưa bị khối ngoại nắm); free float mới = free float + Δ; thanh khoản mới = thanh khoản × (1 + g) × (free float mới ÷ free float cũ)^độ co giãn
- rổ = N mã lớn nhất có giá trị giao dịch bình quân từ ngưỡng tối thiểu trở lên (mặc định 10 tỷ mỗi phiên)

OUTPUT (phong cách cho mọi giai đoạn)
IBM Plex Serif cho tiêu đề, IBM Plex Sans cho chữ, IBM Plex Mono cho số và nhãn chữ hoa nhỏ. Nền trang trắng, các thẻ viền mảnh, góc vuông, các ô cách nhau bằng đường kẻ mảnh. Màu cố định theo vai trò: xanh dương cho thanh khoản, cam cho room, xanh lục cho free float, xám cho khớp lệnh và các phần trung tính. Chỉ dùng giao diện nền trắng, không có chế độ tối. Mỗi panel mở đầu bằng một đoạn dẫn hai câu, số chính in đậm. Mỗi biểu đồ có một dòng "Cách đọc" bên dưới. Nguồn ở cuối mỗi panel. Thanh tab dính ở đầu trang, bên phải.

QUALITY CHECKS
Không bịa số. Mọi con số trên trang phải đến từ dữ liệu hoặc từ công thức tôi đưa. Không tạo điểm số hay kết luận cứng trong mã: mọi kết quả đều do công cụ tính trong trang tính ra, để đổi một thanh trượt thì kết quả đổi theo. Không dùng dấu gạch ngang để giải thích hay thêm mệnh đề trong chữ hiển thị, hãy viết câu đầy đủ.

---

## Giai đoạn 1: các con số, trước khi có biểu đồ

TASK
Tính và in các bảng sau. Chưa viết HTML.

1. Toàn thị trường: ròng khối ngoại cả kỳ, ròng khớp lệnh, ròng thỏa thuận, tỷ trọng thỏa thuận, số tháng bán ròng, tháng bán mạnh nhất.
2. Bằng chứng theo ba nhóm room còn lại: số quan sát, số mã, tỷ trọng thỏa thuận gộp, trung vị, ròng ngoại trên giá trị giao dịch.
3. Với 124 mã có dòng vốn theo tháng: tổng ròng và tỷ lệ so với toàn thị trường, các mã bán ròng và mua ròng nhiều nhất, phần của 10 mã bán nhiều nhất.
4. Rổ mô phỏng ở thiết lập cơ sở (N = 100, giai đoạn cộng dồn 100%, H = 250, p = 10%, ngưỡng 10 tỷ, US$6 tỷ, 25.650 VND/USD): số mã, mục tiêu, hấp thụ, độ phủ, phần bỏ lỡ, số mã và phần bỏ lỡ theo từng nút thắt, 12 mã bỏ lỡ nhiều nhất, phần bỏ lỡ theo ngành.
5. Độ phủ khi dùng riêng từng đòn bẩy (room +5 điểm, free float +10 điểm, thanh khoản +20%) và khi dùng cả ba.
6. Dữ liệu thiếu và ngoại lệ.

QUALITY CHECKS
Mong đợi: ròng cả kỳ −126,0 nghìn tỷ (khớp lệnh −96,2, thỏa thuận −29,8), 11 trên 11 tháng âm, tháng 10 mạnh nhất với −24,0. Tỷ trọng thỏa thuận gộp 36,0%, 21,8%, 14,0% theo ba nhóm room. 124 mã chiếm 89,7% dòng ròng. Rổ 81 mã, mục tiêu 153,9 nghìn tỷ, hấp thụ 118,0, độ phủ 76,7%, bỏ lỡ 35,9. Nút thắt: thanh khoản 67 mã, room 14 mã, free float 0 mã. Ba đòn bẩy cùng dùng đưa độ phủ lên 88,1%. Nếu bất kỳ số nào lệch, dừng lại và giải thích. Kiểm thêm: tổng nhu cầu bằng mục tiêu, và dư địa của mỗi mã không vượt nhỏ nhất của R, F, L.

---

## Giai đoạn 2: panel 01, Nghịch lý

TASK
Dựng panel 01 từ các số của giai đoạn 1.

OUTPUT
- Đoạn dẫn hai câu: khối ngoại bán ròng 126,0 nghìn tỷ đồng, cả 11 tháng đều âm, kể cả sau ngày FTSE hiệu lực; trong đó 24% đi qua thỏa thuận.
- Bốn ô số: bán ròng cả kỳ; số tháng bán ròng và tháng mạnh nhất; phần đi qua thỏa thuận; mức độ tập trung ở 124 mã lớn nhất.
- Biểu đồ cột chồng ròng khối ngoại theo tháng, tách khớp lệnh và thỏa thuận, có đường nét đứt đánh dấu 21/9 và chú thích ngày hiệu lực. Có bảng số dạng thu gọn.
- Thanh ngang hai chiều: các mã bán ròng nhiều nhất và mua ròng nhiều nhất.

QUALITY CHECKS
Tổng các cột tháng bằng −126,0. Mỗi cột tháng có khớp lệnh cộng thỏa thuận bằng ròng (sai số dưới 0,2 tỷ đồng do làm tròn nguồn).

---

## Giai đoạn 3: panel 02, Điểm nghẽn

TASK
Dựng panel 02: bằng chứng rằng room nước ngoài là một điểm nghẽn.

OUTPUT
- Đoạn dẫn: khi room còn dưới 10%, 36,0% giá trị giao dịch ngoại đi qua thỏa thuận, so với 14,0% ở nhóm room còn từ 30% trở lên; nói rõ đây là quan hệ thống kê chứ chưa phải nhân quả.
- Thanh ngang so sánh tỷ trọng thỏa thuận của ba nhóm room, kèm số quan sát và số mã.
- Biểu đồ phân tán: mỗi chấm là một mã trong một tháng, trục ngang là room còn lại (% tổng room), trục dọc là tỷ trọng thỏa thuận (%), nét đứt ở 10% và 30%.
- Ca Techcombank (TCB): cột ròng khớp lệnh và thỏa thuận theo tháng, đường tỷ trọng thỏa thuận.

QUALITY CHECKS
Số quan sát ba nhóm phải là 62, 129, 978. TCB có tỷ trọng thỏa thuận khoảng 90 đến 94% ở tháng 1 đến tháng 3 và khoảng 1% ở tháng 8 và 9. Nếu khác, dừng lại.

---

## Giai đoạn 4: panel 03, Mô phỏng

CONTEXT
Câu hỏi của người ra quyết định là: với một khoản vốn thụ động cho trước, mỗi mã nhận được bao nhiêu, nút thắt là gì, và đòn bẩy nào gỡ được nút thắt đó.

TASK
Dựng panel 03 với công thức đúng như phần DATA.

OUTPUT
- Trái (cố định khi cuộn trên màn hình rộng): nhóm Đòn bẩy chính sách đứng đầu với ba thanh trượt nới room, tăng free float, tăng thanh khoản. Tiếp theo là hai nhóm có thể thu gọn, mỗi nhóm có dòng tóm tắt giá trị đang chọn. Nhu cầu vốn: số mã (N), đợt FTSE cộng dồn, mục tiêu US$ tỷ, tỷ giá. Giới hạn hấp thụ: số phiên H, tỷ lệ p, ngưỡng giá trị giao dịch tối thiểu, độ co giãn. Sau đó là khung công thức thu gọn và nút đặt lại mặc định. Trên điện thoại các nhóm thu gọn sẵn.
- Phải: dòng số chính (độ phủ cơ sở, độ phủ sau đòn bẩy, mục tiêu và phần hấp thụ) kèm một thanh độ phủ có phần tăng thêm, rồi khối "Nên nới đòn bẩy nào trước" xếp hạng ba đòn bẩy theo độ phủ tăng thêm, tự đổi theo thanh trượt và luôn nêu số, ba biểu đồ nhỏ (dư địa theo nút thắt, phần bỏ lỡ theo nút thắt, 12 mã bị bỏ lỡ nhiều nhất), bản đồ nhiệt độ nhạy theo H và p, và bảng "Từng đòn bẩy ở mức đang chọn".
- Kết luận phải nói rõ nếu một mã chiếm phần lớn phần bỏ lỡ.

QUALITY CHECKS
Ở thiết lập mặc định (N = 100, cộng dồn 100%, H = 250, p = 10%, ngưỡng 10 tỷ, US$6 tỷ, 25.650), độ phủ cơ sở 76,7%. Room +5 điểm cho 84,8%, free float +10 điểm cho 78,0%, thanh khoản +20% cho 78,5%, cả ba cho 88,1%. Đổi H thành 20 thì độ phủ cơ sở ở p = 10% là 17%.

---

## Giai đoạn 5: panel 04, Từng mã, rồi rà soát

TASK
Dựng panel 04 và rà soát cả trang như một người đọc đa nghi.

OUTPUT
1. Panel 04: danh sách mã xếp theo phần bỏ lỡ giảm dần (có ô tìm), bấm để ghim; bên phải là chi tiết mã đã ghim gồm R, F, L và nút thắt, ròng ngoại theo tháng, room còn lại theo tháng, tỷ trọng thỏa thuận theo tháng; bên dưới là bảng đầy đủ có sắp xếp, lọc theo nút thắt và nút tải CSV; cuối cùng là ghi chú phương pháp và giới hạn.
2. Dùng được trên điện thoại: thanh tab vẫn thấy, các panel xếp chồng.
3. Thanh tab dùng được bằng bàn phím (mũi tên, Home, End).
4. Liệt kê mọi con số trên trang cùng nguồn và công thức, đánh dấu số nào không truy được.
5. Nói ba điểm yếu nhất của lập luận mà trang đưa ra, mỗi điểm một câu.
6. Ghi rõ việc dùng AI ở chân trang.

QUALITY CHECKS
Không có số nào không truy được nguồn. Không có chữ hiển thị nào dùng dấu gạch ngang để giải thích.

---

## Giai đoạn thử thách trước khi trình bày

ROLE
Bạn là một giám khảo đa nghi của hackathon.

TASK
Mở dashboard và mã tạo ra nó. Nêu ba con số bạn sẽ nghi ngờ đầu tiên và tính lại từng số từ dữ liệu thô. Sau đó nói trong hai câu: dashboard này chưa cho thấy điều gì mà người đọc cần.
