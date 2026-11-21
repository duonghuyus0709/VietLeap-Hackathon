# analysis/nghich_ly_nang_hang.R: toàn bộ mã R của báo cáo, tách từ nghich_ly_nang_hang.Rmd bằng knitr::purl().
# Chạy từ thư mục analysis/: Rscript nghich_ly_nang_hang.R (đọc dữ liệu ở ../data/csv).

## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  echo = TRUE,
  message = FALSE,
  warning = FALSE,
  fig.align = "center",
  dpi = 150,
  fig.width = 9,
  fig.height = 4.6,
  dev = "png"
)


## ----core, include=FALSE------------------------------------------------------
# Khối tính toán lõi được chạy trước để đoạn Tóm tắt dùng số do mã sinh ra (không gõ tay).
# Toàn bộ mã này được trình bày lại từng bước ở Mục 4 đến Mục 7.
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2); library(scales)
  library(patchwork); library(fixest); library(sandwich); library(lmtest); library(car)
})
# Dữ liệu CSV trong repo, do scripts/json_to_csv.py tạo từ data/raw (render từ thư mục analysis/)
rd  <- function(f) read_csv(file.path("..", "data", "csv", f), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
TY  <- 1e9
f1  <- function(x, d = 1) formatC(as.numeric(unlist(x)), format = "f", digits = d, big.mark = ",")
pc  <- function(x, d = 1) paste0(f1(100 * x, d), "%")
stars <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
pv  <- function(p) ifelse(p < 0.001, "< 0.001", formatC(p, format = "f", digits = 3))
pe  <- function(p) ifelse(p < 0.001, "< 0.001", paste("=", formatC(p, format = "f", digits = 3)))

scr  <- rd("screener400.csv"); snap <- rd("snap400.csv"); vn <- rd("vnindex_ff.csv")
ffr  <- bind_rows(rd("ff_1.csv"), rd("ff_2.csv"), rd("ff_3a.csv"))
hu   <- rd("hnx_upcom_ff_net.csv")   # ròng khối ngoại theo tháng của HNXINDEX và UPCOMINDEX
# 27 mã FTSE Global All Cap từ 21/9/2026 (FAQ của FTSE Russell, v1.3, 25/8/2026)
FTSE27 <- c("VCB", "VIC", "VHM", "BID", "HPG", "VPB", "FPT", "GEX", "HDB", "HCM", "MCH", "MSN", "NVL", "STB",
            "SHB", "SSB", "SSI", "TCX", "VCI", "VJC", "VNM", "MSB", "VRE", "VPL", "VIX", "VND", "VCK")

st <- scr %>% mutate(rank = row_number()) %>%
  left_join(snap %>% select(ticker, ff_snap = free_float_ratio, os = outstanding_shares,
                            adtv_m = avg_matched_value, adtv_snap = avg_trading_value), by = "ticker") %>%
  transmute(t = ticker, ten = name, san = exchange, nganh = industry, rank,
            mc = market_cap / TY,
            ff = coalesce(ff_snap, free_float / os, 0),
            room = coalesce(foreign_room_remaining, 0),
            fown = coalesce(foreign_ownership_ratio, 0),
            adtv = coalesce(adtv_m, 0) / TY,                                  # GTGD khớp lệnh bình quân
            adtv_all = coalesce(avg_trading_value, adtv_snap, 0) / TY,        # GTGD tổng, có thỏa thuận
            ftse = ticker %in% FTSE27,
            ytd = price_change_ytd)
net_ma <- ffr %>% group_by(t = ticker) %>% summarise(net = sum(foreignNetValueTotal) / TY, .groups = "drop")
st <- st %>% left_join(net_ma, by = "t")

mo <- vn %>% arrange(month) %>%
  transmute(m = month, buy = foreignBuyValueTotal / TY, sell = foreignSellValueTotal / TY,
            net = foreignNetValueTotal / TY,
            nm = (foreignBuyValueMatched - foreignSellValueMatched) / TY,
            nd = (foreignBuyValueDeal - foreignSellValueDeal) / TY) %>%
  left_join(hu %>% group_by(m = month) %>% summarise(oth = sum(foreignNetValueTotal) / TY, .groups = "drop"), by = "m") %>%
  mutate(oth = coalesce(oth, 0), net3 = net + oth)                        # net3: cả ba sàn

pn_all <- ffr %>%
  transmute(ticker, month,
            turn = (foreignBuyValueTotal + foreignSellValueTotal) / TY,
            deal = (foreignBuyValueDeal + foreignSellValueDeal) / TY,
            netv = foreignNetValueTotal / TY,
            nm = (foreignBuyValueMatched - foreignSellValueMatched) / TY,
            nd = (foreignBuyValueDeal - foreignSellValueDeal) / TY,
            totroom = foreignTotalRoom, curroom = foreignCurrentRoom)
pn <- pn_all %>% filter(totroom > 0, turn > 0) %>%
  mutate(x = curroom / totroom, ds = deal / turn,
         nhom = cut(x, c(-Inf, 0.10, 0.30, Inf), right = FALSE,
                    labels = c("Dưới 10%", "10% đến 30%", "Từ 30% trở lên")),
         tight = as.integer(x < 0.10), narrow = as.integer(x >= 0.10 & x < 0.30),
         dd = as.integer(ds >= 0.5), lturn = log(turn), m_f = factor(month)) %>%
  left_join(st %>% select(ticker = t, mc, nganh), by = "ticker") %>%
  mutate(lmc = log(mc))

# Mô hình mô phỏng hấp thụ (đúng công thức trong prompt của nhóm)
# Mặc định US$1,5 tỷ vốn thụ động; basket = "ftse" dùng rổ 27 mã FTSE thật thay cho N mã lớn nhất.
sim <- function(N = 100, stage = 1, H = 250, p = 10, dr = 0, df = 0, g = 0, eps = 0.5,
                tgtUsd = 1.5, fx = 25650, minA = 10, ff_net = FALSE, drop = character(0), basket = "top") {
  tgt <- tgtUsd * stage * fx
  U <- if (basket == "ftse") filter(st, ftse) else slice_head(st, n = N)
  U %>% filter(adtv >= minA, !t %in% drop) %>%
    mutate(room2 = pmin(room + dr / 100, pmax(0, 1 - fown)),
           ff2   = pmin(ff + df / 100, 1),
           adtv2 = adtv * ifelse(ff > 0, (ff2 / ff)^eps, 1) * (1 + g / 100),
           R = room2 * mc,
           F = if (ff_net) pmax(ff2 - fown, 0) * mc else ff2 * mc,
           L = p / 100 * adtv2 * H,
           cap  = pmin(R, F, L),
           bind = case_when(L < pmin(R, F) ~ "Thanh khoản", F < R ~ "Free float", TRUE ~ "Room"),
           dem  = tgt * ff * mc / sum(ff * mc),
           ab   = pmin(dem, cap), gap = dem - ab, tgt = tgt)
}
cov_of <- function(b) sum(b$ab) / b$tgt[1]
short_n <- function(b) sum(b$gap > 1e-6)          # số mã thực sự thiếu dư địa (nhu cầu > dư địa)
b0 <- sim(); cov0 <- cov_of(b0)
lev <- list("Nới room +5 điểm %" = list(dr = 5), "Tăng free float +10 điểm %" = list(df = 10),
            "Tăng thanh khoản +20%" = list(g = 20), "Cả ba đòn bẩy" = list(dr = 5, df = 10, g = 20))
lev_cov <- sapply(lev, function(k) cov_of(do.call(sim, k)))

# Các mô hình chính dùng trong Tóm tắt
m_p2 <- feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn, cluster = ~ticker)
m_p4 <- feols(ds ~ tight + narrow + lturn | ticker + m_f, data = pn, cluster = ~ticker)
m_lg <- glm(dd ~ tight + narrow + lturn + lmc, family = binomial, data = pn)
vc_lg <- vcovCL(m_lg, cluster = ~ticker)
or_tight <- exp(coef(m_lg)["tight"])
pooled <- pn %>% group_by(nhom) %>% summarise(pool = sum(deal) / sum(turn), n = n(), .groups = "drop")
ytd_net <- sum(mo$net); ytd_nm <- sum(mo$nm); ytd_nd <- sum(mo$nd); ytd_all <- sum(mo$net3)
gapV <- b0 %>% arrange(desc(gap)); top_t <- gapV$t[1]; top_bind <- gapV$bind[1]; top_share <- gapV$gap[1] / sum(b0$gap)
# Kịch bản US$6 tỷ (gồm cả quỹ chủ động) và rổ FTSE 27 mã thật
b6 <- sim(tgtUsd = 6); cov6 <- cov_of(b6); cov6_all <- cov_of(sim(tgtUsd = 6, dr = 5, df = 10, g = 20))
g6 <- b6 %>% arrange(desc(gap)); top6_t <- g6$t[1]; top6_share <- g6$gap[1] / sum(b6$gap)
bF <- sim(basket = "ftse"); covF <- cov_of(bF)
# Kiểm chứng FTSE: headroom = room còn lại / giới hạn sở hữu, xét với dữ liệu chốt 30/6/2026 (tháng 6)
hr6 <- ffr %>% filter(month == 6, foreignTotalRoom > 0) %>% transmute(t = ticker, hr6 = foreignCurrentRoom / foreignTotalRoom)
fsel <- st %>% left_join(hr6, by = "t") %>% mutate(fol = room + fown, inv = mc * pmin(ff, fol))
ftse_in  <- fsel %>% filter(ftse)
ftse_out <- fsel %>% arrange(desc(mc)) %>% slice_head(n = 60) %>% filter(san == "HOSE", !ftse, !is.na(hr6))
ftse_lost <- ftse_out %>% filter(hr6 < 0.2, fol >= 0.1) %>%
  mutate(need = pmax(0, (0.2 * fol - room) / 0.8), usd = 1500 * inv / sum(ftse_in$inv)) %>% arrange(desc(usd))
lost_usd <- sum(ftse_lost$usd)
# Hàm ý chính sách (Mục 10): chia các mã bị FTSE loại theo mức khó khi đưa headroom lên 20%
iv    <- function(expr, alt = "(xem Mục 10)") tryCatch(expr, error = function(e) alt)   # giá trị nội dòng an toàn
usd_m <- function(x) x / 25.65                                                          # tỷ đồng -> triệu US$ (25.650 VND/USD)
NH <- c("ABB", "ACB", "BAB", "BID", "BVB", "CTG", "EIB", "HDB", "KLB", "LPB", "MBB", "MSB", "NAB", "NVB", "OCB",
        "PGB", "SGB", "SHB", "SSB", "STB", "TCB", "TPB", "VAB", "VBB", "VCB", "VIB", "VPB")
# Trần luật định: 30% với ngân hàng (Nghị định 01/2014), 49% với doanh nghiệp khác.
# Bước 0: đã đạt 20% headroom; Bước 1: đạt được trong trần luật định (doanh nghiệp tự nâng); Bước 2: phải vượt trần luật định.
pol1 <- tryCatch(ftse_lost %>%
  mutate(tran_luat = ifelse(nganh %in% "Ngân hàng" | t %in% NH, 0.30, 0.49),
         buoc = case_when(need <= 1e-9 ~ "Bước 0", fol + need <= tran_luat + 1e-9 ~ "Bước 1", TRUE ~ "Bước 2")),
  error = function(e) NULL)
share_nolaw <- iv(sum(pol1$usd[pol1$buoc != "Bước 2"]) / lost_usd, NA)


## ----hyp, echo=FALSE----------------------------------------------------------
knitr::kable(data.frame(
  `Mã` = paste0("H", 1:7),
  `Nội dung giả thuyết` = c(
    "Bán ròng của khối ngoại mang tính hệ thống, không phải dao động ngẫu nhiên quanh 0",
    "Khi room còn lại dưới 10% tổng room, tỷ trọng thỏa thuận cao hơn nhóm room rộng",
    "Quan hệ có dạng bậc thang: nhóm room 10% đến 30% cũng cao hơn nhóm room rộng",
    "Quan hệ ở H2 vẫn đúng khi khử hiệu ứng cố định của từng mã (biến động trong cùng một mã)",
    "Room cạn làm tăng xác suất một tháng giao dịch ngoại do kênh thỏa thuận chi phối (từ 50% trở lên)",
    "Room còn lại không giải thích cường độ bán ròng xuyên mã, vì room chỉ chặn chiều mua",
    "Ở thiết lập cơ sở, độ phủ dưới 100%; thanh khoản là nút thắt của đa số mã, room là nút thắt tập trung ở nhóm vốn hóa lớn"),
  `Dấu kỳ vọng` = c("P(tháng âm) > 0.5", "β_tight > 0", "β_narrow > 0", "β_tight > 0 (FE)",
                    "OR_tight > 1", "β_room ≈ 0", "Độ phủ < 1"),
  `Cơ sở lý thuyết` = c("Động lượng dòng vốn quốc tế (Froot và cộng sự, 2001)",
                        "Thị trường song song (Bailey & Jagtiani, 1994)",
                        "Phần bù room tăng dần khi room cạn (Bailey và cộng sự, 1999)",
                        "Nhận dạng biến động trong mã (Wooldridge, 2010)",
                        "Mô hình lựa chọn nhị phân (McFadden, 1974)",
                        "Room là ràng buộc một chiều với lệnh mua",
                        "Cầu chỉ số và đường cầu dốc xuống (Shleifer, 1986; Kyle, 1985)"),
  check.names = FALSE),
  caption = "Bảng 2.1: Hệ thống giả thuyết nghiên cứu")


## ----load, eval=FALSE---------------------------------------------------------
# library(dplyr); library(tidyr); library(readr); library(ggplot2); library(scales)
# library(patchwork); library(fixest); library(sandwich); library(lmtest); library(car)
# 
# rd <- function(f) read_csv(file.path("..", "data", "csv", f), show_col_types = FALSE,
#                            locale = locale(encoding = "UTF-8"))
# TY   <- 1e9                                    # đồng -> tỷ đồng
# scr  <- rd("screener400.csv")                  # screen_stocks: 400 mã vốn hóa lớn nhất
# snap <- rd("snap400.csv")                      # get_equity_snapshot: free float, số CP lưu hành
# vn   <- rd("vnindex_ff.csv")                   # foreign_flow theo tháng của sàn HOSE (VN-Index)
# hu   <- rd("hnx_upcom_ff_net.csv")             # ròng khối ngoại theo tháng của HNX và UPCoM
# ffr  <- bind_rows(rd("ff_1.csv"), rd("ff_2.csv"), rd("ff_3a.csv"))  # foreign_flow 124 mã


## ----rawtab-------------------------------------------------------------------
raw_info <- tibble(
  `Tệp` = c("screener400.csv", "snap400.csv", "ff_1/ff_2/ff_3a.csv", "vnindex_ff.csv", "hnx_upcom_ff_net.csv"),
  `Hàm FiinQuantX` = c("screen_stocks", "get_equity_snapshot",
                       "get_market_statistics(foreign_flow, Monthly)",
                       "get_market_statistics(VNINDEX, foreign_flow, Monthly)",
                       "get_market_statistics(HNXINDEX, UPCOMINDEX, foreign_flow, Monthly)"),
  `Đơn vị quan sát` = c("Mã", "Mã", "Mã × tháng", "Tháng", "Sàn × tháng"),
  `Số dòng` = c(nrow(scr), nrow(snap), nrow(ffr), nrow(vn), nrow(hu)),
  `Số cột` = c(ncol(scr), ncol(snap), ncol(ffr), ncol(vn), ncol(hu)),
  `Số mã` = c(n_distinct(scr$ticker), n_distinct(snap$ticker), n_distinct(ffr$ticker), 1, 2),
  `Kỳ` = c("19/11/2026", "19/11/2026", paste0("T", min(ffr$month), " đến T", max(ffr$month), "/2026"),
          paste0("T", min(vn$month), " đến T", max(vn$month), "/2026"),
          paste0("T", min(hu$month), " đến T", max(hu$month), "/2026")))
knitr::kable(raw_info, caption = "Bảng 4.1: Tổng quan các tệp dữ liệu thô")


## ----qc-----------------------------------------------------------------------
obs_m  <- ffr %>% count(month)
no_adtv <- snap$ticker[is.na(snap$avg_matched_value) | snap$avg_matched_value == 0]
room0  <- scr %>% filter(coalesce(foreign_room_remaining, 0) == 0)
id_bs  <- max(abs(vn$foreignBuyValueTotal - vn$foreignSellValueTotal - vn$foreignNetValueTotal)) / TY
id_md  <- max(abs(mo$nm + mo$nd - mo$net))
bad_pn <- sum(pn_all$totroom <= 0 | pn_all$turn <= 0)
qc <- tibble(
  `Hạng mục kiểm tra` = c(
    "screener400 xếp theo vốn hóa giảm dần",
    "Trùng lặp mã × tháng trong ff_*",
    "Số mã có dòng vốn theo tháng; số quan sát mỗi tháng",
    "GTGD khớp lệnh bình quân trống hoặc bằng 0 (snapshot)",
    "Free float trống ở snapshot",
    "Room còn lại bằng 0 trong screener",
    "Tăng giá từ đầu năm (YTD) trống",
    "Mua − bán = ròng (VN-Index), sai lệch lớn nhất",
    "Khớp lệnh + thỏa thuận = ròng (VN-Index), sai lệch lớn nhất",
    "Mã × tháng có tổng room = 0 hoặc giao dịch ngoại = 0",
    "Tỷ trọng thỏa thuận sau làm sạch nằm trong [0, 1]"),
  `Kết quả` = c(
    as.character(!is.unsorted(rev(scr$market_cap))),
    as.character(sum(duplicated(ffr[c("ticker", "month")]))),
    paste0(n_distinct(ffr$ticker), " mã; ", min(obs_m$n), " đến ", max(obs_m$n), " quan sát/tháng"),
    paste0(sum(is.na(snap$avg_matched_value)), " trống, ", sum(snap$avg_matched_value == 0, na.rm = TRUE),
           " bằng 0; tổng ", length(no_adtv), " mã"),
    as.character(sum(is.na(snap$free_float_ratio))),
    paste0(nrow(room0), " mã; ", sum(room0$foreign_ownership_ratio < 0.01, na.rm = TRUE), " mã có sở hữu ngoại dưới 1%"),
    as.character(sum(is.na(scr$price_change_ytd))),
    paste0(f1(id_bs, 4), " tỷ đồng"),
    paste0(f1(id_md, 2), " tỷ đồng"),
    paste0(bad_pn, " quan sát"),
    as.character(all(pn$ds >= 0 & pn$ds <= 1))),
  `Xử lý` = c(
    "Dùng thứ tự này làm hạng vốn hóa",
    "Không cần xử lý",
    "Bảng không cân bằng; giữ nguyên, không nội suy",
    "Gán 0; mã dưới ngưỡng GTGD tự rời khỏi rổ mô phỏng",
    "Dự phòng: free_float (cổ phiếu) ÷ số cổ phiếu lưu hành",
    "Giữ theo nguồn; nhiều mã là doanh nghiệp nhà nước có room hạn chế; kiểm tra độ nhạy ở Mục 7.4",
    "Loại khỏi hồi quy chéo khi dùng biến YTD",
    "Đạt (sai lệch do làm tròn nguồn)",
    "Đạt (dưới 0.2 tỷ đồng)",
    "Loại khỏi bảng dữ liệu vì tỷ trọng không xác định",
    "Đạt"))
knitr::kable(qc, caption = "Bảng 4.2: Kết quả kiểm tra chất lượng dữ liệu và quyết định xử lý")


## ----vars, eval=FALSE---------------------------------------------------------
# # (a) Dữ liệu chéo 400 mã: ghép screener với snapshot, đổi đơn vị sang tỷ đồng
# st <- scr %>% mutate(rank = row_number()) %>%
#   left_join(snap %>% select(ticker, ff_snap = free_float_ratio, os = outstanding_shares,
#                             adtv_m = avg_matched_value, adtv_snap = avg_trading_value), by = "ticker") %>%
#   transmute(t = ticker, ten = name, san = exchange, nganh = industry, rank,
#             mc = market_cap / TY,
#             ff = coalesce(ff_snap, free_float / os, 0),          # free float, dự phòng từ số cổ phiếu
#             room = coalesce(foreign_room_remaining, 0),           # room còn lại / vốn điều lệ
#             fown = coalesce(foreign_ownership_ratio, 0),
#             adtv = coalesce(adtv_m, 0) / TY,                      # GTGD khớp lệnh bình quân (dùng cho L)
#             adtv_all = coalesce(avg_trading_value, adtv_snap, 0) / TY,
#             ftse = ticker %in% FTSE27,                            # 27 mã FTSE Global All Cap
#             ytd = price_change_ytd)
# st <- st %>% left_join(ffr %>% group_by(t = ticker) %>%
#                          summarise(net = sum(foreignNetValueTotal) / TY), by = "t")
# 
# # (b) Chuỗi sàn HOSE theo tháng: ròng tách khớp lệnh (nm) và thỏa thuận (nd); net3 cộng HNX và UPCoM
# mo <- vn %>% arrange(month) %>%
#   transmute(m = month, buy = foreignBuyValueTotal / TY, sell = foreignSellValueTotal / TY,
#             net = foreignNetValueTotal / TY,
#             nm = (foreignBuyValueMatched - foreignSellValueMatched) / TY,
#             nd = (foreignBuyValueDeal - foreignSellValueDeal) / TY) %>%
#   left_join(hu %>% group_by(m = month) %>% summarise(oth = sum(foreignNetValueTotal) / TY), by = "m") %>%
#   mutate(oth = coalesce(oth, 0), net3 = net + oth)
# 
# # (c) Bảng dữ liệu mã × tháng
# pn <- ffr %>%
#   transmute(ticker, month,
#             turn = (foreignBuyValueTotal + foreignSellValueTotal) / TY,  # giá trị giao dịch ngoại
#             deal = (foreignBuyValueDeal + foreignSellValueDeal) / TY,    # phần qua thỏa thuận
#             netv = foreignNetValueTotal / TY,
#             totroom = foreignTotalRoom, curroom = foreignCurrentRoom) %>%
#   filter(totroom > 0, turn > 0) %>%
#   mutate(x = curroom / totroom,                     # room còn lại / tổng room
#          ds = deal / turn,                          # tỷ trọng thỏa thuận
#          nhom = cut(x, c(-Inf, 0.10, 0.30, Inf), right = FALSE,
#                     labels = c("Dưới 10%", "10% đến 30%", "Từ 30% trở lên")),
#          tight = as.integer(x < 0.10), narrow = as.integer(x >= 0.10 & x < 0.30),
#          dd = as.integer(ds >= 0.5),                # tháng do thỏa thuận chi phối
#          lturn = log(turn), m_f = factor(month)) %>%
#   left_join(st %>% select(ticker = t, mc, nganh), by = "ticker") %>%
#   mutate(lmc = log(mc))


## ----dict, echo=FALSE---------------------------------------------------------
knitr::kable(data.frame(
  `Biến` = c("mc", "ff", "room", "fown", "adtv", "ytd", "net", "NetInt", "x", "DS (ds)", "Tight, Narrow", "DD (dd)", "ln Turn", "ln MC"),
  `Ý nghĩa` = c("Vốn hóa thị trường", "Tỷ lệ free float", "Room nước ngoài còn lại trên vốn điều lệ",
              "Tỷ lệ sở hữu nước ngoài", "Giá trị giao dịch khớp lệnh bình quân mỗi phiên", "Thay đổi giá từ đầu năm",
              "Ròng khối ngoại cả kỳ của mã", "Ròng khối ngoại chia vốn hóa", "Room còn lại chia tổng room, theo tháng",
              "Giá trị thỏa thuận chia giá trị mua và bán của khối ngoại", "Biến giả x < 10%; 10% ≤ x < 30%",
              "Biến giả DS ≥ 50%", "Log giá trị giao dịch ngoại trong tháng", "Log vốn hóa"),
  `Đơn vị` = c("Tỷ đồng", "Tỷ lệ", "Tỷ lệ", "Tỷ lệ", "Tỷ đồng", "Tỷ lệ", "Tỷ đồng", "% vốn hóa", "Tỷ lệ",
             "Tỷ lệ", "0/1", "0/1", "log(tỷ đồng)", "log(tỷ đồng)"),
  `Nguồn` = c(rep("screener400", 2), "screener400", "screener400", "snap400", "screener400",
              "ff_*", "Tính toán", "ff_*", "ff_*", "Tính toán", "Tính toán", "ff_*", "screener400"),
  check.names = FALSE), caption = "Bảng 4.3: Từ điển biến")


## ----reconcile----------------------------------------------------------------
ev <- pn %>% group_by(nhom) %>% summarise(pool = sum(deal) / sum(turn), n = n(), .groups = "drop")
flow_ma <- st %>% filter(!is.na(net))
b_all <- sim(dr = 5, df = 10, g = 20)
rec <- tibble(
  `Chỉ tiêu` = c("Ròng cả kỳ (nghìn tỷ)", "Ròng khớp lệnh (nghìn tỷ)", "Ròng thỏa thuận (nghìn tỷ)",
               "Số tháng bán ròng", "Tháng 10 (nghìn tỷ)",
               "Tỷ trọng thỏa thuận gộp, room < 10% (%)", "Tỷ trọng thỏa thuận gộp, 10% đến 30% (%)",
               "Tỷ trọng thỏa thuận gộp, room ≥ 30% (%)", "Số quan sát ba nhóm",
               "Mã HOSE có dòng vốn theo tháng chiếm % ròng HOSE", "Số mã trong rổ", "Mục tiêu US\\$1,5 tỷ (nghìn tỷ)",
               "Hấp thụ (nghìn tỷ)", "Độ phủ cơ sở (%)", "Độ phủ cả ba đòn bẩy (%)",
               "Ròng cả ba sàn (nghìn tỷ)", "Độ phủ US\\$6 tỷ (%)", "Độ phủ US\\$6 tỷ, cả ba đòn bẩy (%)",
               "Độ phủ rổ FTSE 27 mã (%)", "Vốn thụ động mất ở mã bị loại (triệu US\\$)"),
  `Mong đợi` = c(-126.0, -96.2, -29.8, 11, -24.0, 36.0, 21.8, 14.0, NA, 92.0, 77, 38.5, 37.1, 96.4, 100.0,
                 -123.4, 72.7, 85.4, 97.4, 237),
  `Tính lại` = c(ytd_net / 1000, ytd_nm / 1000, ytd_nd / 1000, sum(mo$net < 0), mo$net[mo$m == 10] / 1000,
                 100 * ev$pool, NA, 100 * sum(flow_ma$net[flow_ma$san == "HOSE"]) / ytd_net, nrow(b0), b0$tgt[1] / 1000,
                 sum(b0$ab) / 1000, 100 * cov0, 100 * cov_of(b_all),
                 ytd_all / 1000, 100 * cov6, 100 * cov6_all, 100 * covF, lost_usd))
rec_show <- rec %>% mutate(`Mong đợi` = ifelse(is.na(`Mong đợi`), "62 / 129 / 978", mapply(f1, `Mong đợi`, ifelse(row_number() == 20, 0, 1))),
                           `Tính lại` = ifelse(row_number() == 9, paste(ev$n, collapse = " / "), mapply(f1, `Tính lại`, ifelse(row_number() == 20, 0, 1))),
                           `Khớp` = ifelse(row_number() == 9, ifelse(all(ev$n == c(62, 129, 978)), "Có", "Không"),
                                           ifelse(abs(as.numeric(gsub(",", "", `Tính lại`)) -
                                                      as.numeric(gsub(",", "", `Mong đợi`))) < 0.05, "Có", "Không")))
knitr::kable(rec_show, align = "lrrc",
             caption = "Bảng 4.4: Đối chiếu số tính lại trong R với số kiểm giai đoạn 1 của nhóm")


## ----desc---------------------------------------------------------------------
dsum <- function(v, lab) tibble(`Biến` = lab, N = sum(!is.na(v)), `Trung bình` = mean(v, na.rm = TRUE),
  `Độ lệch chuẩn` = sd(v, na.rm = TRUE), `Nhỏ nhất` = min(v, na.rm = TRUE),
  `Trung vị` = median(v, na.rm = TRUE), `Lớn nhất` = max(v, na.rm = TRUE))
fm <- st %>% filter(!is.na(net)) %>% mutate(nint = net / mc * 100)
desc <- bind_rows(
  dsum(st$mc / 1000, "Vốn hóa (nghìn tỷ), 400 mã"), dsum(st$ff, "Free float, 400 mã"),
  dsum(st$room, "Room còn lại / vốn điều lệ, 400 mã"), dsum(st$fown, "Sở hữu ngoại, 400 mã"),
  dsum(st$adtv, "GTGD bình quân (tỷ/phiên), 400 mã"), dsum(st$ytd, "Tăng giá YTD, 400 mã"),
  dsum(fm$net / 1000, "Ròng khối ngoại (nghìn tỷ), 124 mã"), dsum(fm$nint, "Ròng / vốn hóa (%), 124 mã"),
  dsum(pn$x, "Room còn lại / tổng room, mã × tháng"), dsum(pn$ds, "Tỷ trọng thỏa thuận, mã × tháng"),
  dsum(pn$turn, "GT giao dịch ngoại (tỷ), mã × tháng"))
knitr::kable(desc, digits = 3, format.args = list(big.mark = ","),
             caption = "Bảng 5.1: Thống kê mô tả các biến chính")


## ----desc_bucket--------------------------------------------------------------
bk <- pn %>% group_by(`Nhóm room còn lại` = nhom) %>%
  summarise(`Quan sát` = n(), `Số mã` = n_distinct(ticker),
            `Gộp theo giá trị (%)` = 100 * sum(deal) / sum(turn),
            `Trung bình (%)` = 100 * mean(ds), `Trung vị (%)` = 100 * median(ds),
            `Tháng DS ≥ 50% (%)` = 100 * mean(dd),
            `Ròng / giao dịch (%)` = 100 * sum(netv) / sum(turn), .groups = "drop")
kw <- kruskal.test(ds ~ nhom, data = pn)
knitr::kable(bk, digits = 1, caption = "Bảng 5.2: Tỷ trọng thỏa thuận của khối ngoại theo mức room còn lại")


## ----fig_month, fig.height=4.4, fig.cap="Hình 5.1: Ròng khối ngoại trên sàn HOSE theo tháng, tách khớp lệnh và thỏa thuận (tỷ đồng). Tháng 11 tính đến 19/11/2026."----
COL <- c(liq = "#2b6cb0", room = "#dd6b20", ff = "#2f855a", gray = "#8a8f98", ink = "#2c3e50")
theme_set(theme_minimal( base_size = 11) +
            theme(panel.grid.minor = element_blank(), plot.title.position = "plot",
                  legend.position = "top", legend.title = element_blank()))
mlong <- mo %>% select(m, `Khớp lệnh` = nm, `Thỏa thuận` = nd) %>%
  pivot_longer(-m, names_to = "kenh", values_to = "v") %>%
  mutate(kenh = factor(kenh, c("Thỏa thuận", "Khớp lệnh")))
ggplot(mlong, aes(factor(m), v, fill = kenh)) +
  geom_col(width = 0.7) +
  geom_point(data = mo, aes(factor(m), net), inherit.aes = FALSE, shape = 21, fill = "white", size = 2.4) +
  geom_text(data = mo, aes(factor(m), net, label = f1(net / 1000)), inherit.aes = FALSE,
            vjust = 1.9, size = 3.1, colour = COL["ink"]) +
  geom_vline(xintercept = 9 + 20/30 - 0.5, linetype = "dashed", colour = COL["ink"]) +
  annotate("text", x = 9.2, y = 2500, label = "FTSE hiệu lực 21/9", hjust = 0, size = 3.3, colour = COL["ink"]) +
  geom_hline(yintercept = 0, colour = "grey40") +
  scale_fill_manual(values = c("Khớp lệnh" = unname(COL["gray"]), "Thỏa thuận" = unname(COL["room"]))) +
  scale_y_continuous(labels = label_comma(), expand = expansion(mult = c(0.12, 0.05))) +
  scale_x_discrete(labels = paste0("T", 1:11)) +
  labs(x = NULL, y = "Tỷ đồng", subtitle = "Chấm trắng và nhãn: ròng tổng của tháng (nghìn tỷ đồng)")


## ----fig_top, fig.height=4.6, fig.cap="Hình 5.2: Mười mã bán ròng và sáu mã mua ròng nhiều nhất của khối ngoại, 01/01 đến 19/11/2026 (nghìn tỷ đồng)"----
tops <- bind_rows(fm %>% arrange(net) %>% slice_head(n = 10), fm %>% arrange(desc(net)) %>% slice_head(n = 6)) %>%
  mutate(chieu = ifelse(net < 0, "Bán ròng", "Mua ròng"), t = reorder(t, net))
ggplot(tops, aes(net / 1000, t, fill = chieu)) + geom_col(width = 0.7) +
  geom_text(aes(label = f1(net / 1000), hjust = ifelse(net < 0, 1.15, -0.15)), size = 3.1) +
  geom_vline(xintercept = 0, colour = "grey40") +
  scale_fill_manual(values = c("Bán ròng" = unname(COL["gray"]), "Mua ròng" = unname(COL["liq"]))) +
  scale_x_continuous(expand = expansion(mult = 0.15)) + labs(x = "Nghìn tỷ đồng", y = NULL)
top10_share <- sum(head(sort(fm$net), 10)) / sum(fm$net[fm$net < 0])


## ----fig_scatter, fig.height=4.8, fig.cap="Hình 5.3: Mỗi chấm là một mã trong một tháng. Trục ngang: room còn lại so với tổng room; trục dọc: tỷ trọng thỏa thuận trong giao dịch ngoại"----
seg <- bk %>% transmute(nhom = `Nhóm room còn lại`, y = `Gộp theo giá trị (%)`,
                        x0 = c(0, 10, 30), x1 = c(10, 30, 100))
ggplot(pn, aes(100 * x, 100 * ds)) +
  geom_point(aes(size = turn), alpha = 0.28, colour = COL["room"], stroke = 0) +
  geom_segment(data = seg, aes(x = x0, xend = x1, y = y, yend = y), inherit.aes = FALSE,
               linewidth = 1.1, colour = COL["ink"]) +
  geom_text(data = seg, aes(x = (x0 + x1) / 2, y = y + 6, label = paste0("gộp ", f1(y), "%")),
            inherit.aes = FALSE, size = 3.1, colour = COL["ink"]) +
  geom_vline(xintercept = c(10, 30), linetype = "dashed", colour = "grey45") +
  scale_size_area(max_size = 7, guide = "none") +
  labs(x = "Room còn lại (% tổng room)", y = "Tỷ trọng thỏa thuận (%)")


## ----fig_tcb, fig.height=5.4, fig.cap="Hình 5.4: TCB, ròng khối ngoại theo kênh (trên) và room còn lại cùng tỷ trọng thỏa thuận (dưới) theo tháng"----
tcb <- pn_all %>% filter(ticker == "TCB") %>% arrange(month) %>%
  mutate(x = curroom / totroom, ds = ifelse(turn > 0, (deal) / turn, NA))
p1 <- tcb %>% select(month, `Khớp lệnh` = nm, `Thỏa thuận` = nd) %>% pivot_longer(-month) %>%
  ggplot(aes(factor(month), value, fill = name)) + geom_col(width = 0.7) + geom_hline(yintercept = 0) +
  scale_fill_manual(values = c("Khớp lệnh" = unname(COL["gray"]), "Thỏa thuận" = unname(COL["room"]))) +
  scale_x_discrete(labels = paste0("T", 1:11)) + labs(x = NULL, y = "Tỷ đồng")
p2 <- tcb %>% select(month, `Room còn lại (% tổng room)` = x, `Tỷ trọng thỏa thuận` = ds) %>%
  pivot_longer(-month) %>%
  ggplot(aes(month, 100 * value, colour = name)) + geom_line(linewidth = 1) + geom_point(size = 2) +
  scale_colour_manual(values = c(unname(COL["room"]), unname(COL["ink"]))) +
  scale_x_continuous(breaks = 1:11, labels = paste0("T", 1:11)) + labs(x = NULL, y = "%")
p1 / p2


## ----paradox------------------------------------------------------------------
sg <- binom.test(sum(mo$net < 0), nrow(mo), p = 0.5, alternative = "greater")
per <- mo %>% mutate(Giai_doan = case_when(m <= 8 ~ "T1 đến T8 (trước hiệu lực)", m == 9 ~ "T9 (tháng hiệu lực)",
                                          TRUE ~ "T10 đến T11 (sau hiệu lực)")) %>%
  group_by(`Giai đoạn` = factor(Giai_doan, c("T1 đến T8 (trước hiệu lực)", "T9 (tháng hiệu lực)", "T10 đến T11 (sau hiệu lực)"))) %>%
  summarise(`Số tháng` = n(), `Ròng TB/tháng` = mean(net), `Khớp lệnh TB/tháng` = mean(nm),
            `Thỏa thuận TB/tháng` = mean(nd), `Thỏa thuận / ròng (%)` = 100 * sum(nd) / sum(net),
            `Mua / bán (%)` = 100 * sum(buy) / sum(sell), .groups = "drop")
knitr::kable(per, digits = 1, format.args = list(big.mark = ","),
             caption = "Bảng 6.1: Dòng vốn ngoại bình quân theo giai đoạn so với ngày FTSE hiệu lực (tỷ đồng)")


## ----panel_models-------------------------------------------------------------
m_p1 <- feols(ds ~ tight + narrow, data = pn, cluster = ~ticker)
m_p2 <- feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn, cluster = ~ticker)
m_p3 <- feols(ds ~ x + lturn + lmc | m_f, data = pn, cluster = ~ticker)
m_p4 <- feols(ds ~ tight + narrow + lturn | ticker + m_f, data = pn, cluster = ~ticker)
m_p5 <- feglm(ds ~ tight + narrow + lturn + lmc | m_f, data = pn, family = quasibinomial(), cluster = ~ticker)

reg_table <- function(mods, vars, labs) {
  rows <- lapply(seq_along(vars), function(k) {
    est <- sapply(mods, function(m) { ct <- coeftable(m)
      if (vars[k] %in% rownames(ct)) paste0(f1(ct[vars[k], 1], 4), stars(ct[vars[k], 4])) else "" })
    se  <- sapply(mods, function(m) { ct <- coeftable(m)
      if (vars[k] %in% rownames(ct)) paste0("(", f1(ct[vars[k], 2], 4), ")") else "" })
    rbind(c(labs[k], est), c("", se)) })
  do.call(rbind, rows)
}
mods <- list(m_p1, m_p2, m_p3, m_p4, m_p5)
tb <- reg_table(mods, c("tight", "narrow", "x", "lturn", "lmc"),
                c("Tight (room < 10%)", "Narrow (10% ≤ room < 30%)", "x (room còn lại, liên tục)",
                  "ln Turn", "ln MC"))
fitr <- function(m) if (inherits(m, "feglm")) f1(cor(predict(m, newdata = pn), pn$ds)^2, 3) else f1(r2(m, "r2"), 3)
tb <- rbind(tb,
  c("Hiệu ứng cố định tháng", "Không", "Có", "Có", "Có", "Có"),
  c("Hiệu ứng cố định mã", "Không", "Không", "Không", "Có", "Không"),
  c("Phương pháp", "OLS", "OLS", "OLS", "OLS trong mã", "Logit phân số"),
  c("Số quan sát", sapply(mods, nobs)),
  c("Số cụm (mã)", sapply(mods, function(m) length(unique(pn$ticker[obs(m)])))),
  c("R² (M5: bình phương tương quan y và ŷ)", sapply(mods, fitr)),
  c("R² trong mã", "", "", "", f1(r2(m_p4, "wr2"), 3), ""))
colnames(tb) <- c("Biến giải thích", "M1", "M2", "M3", "M4", "M5")
knitr::kable(tb, align = "lccccc",
  caption = "Bảng 6.2: Kết quả ước lượng tỷ trọng thỏa thuận (sai số chuẩn cụm theo mã trong ngoặc; *** p<0.01, ** p<0.05, * p<0.1)")

# Tác động biên trung bình của Tight và Narrow trong M5 (đặt biến bằng 1 và 0 cho toàn mẫu)
ape_f <- function(m, var) {
  d1 <- pn; d0 <- pn; d1$tight <- 0; d1$narrow <- 0; d0$tight <- 0; d0$narrow <- 0; d1[[var]] <- 1
  mean(predict(m, newdata = d1) - predict(m, newdata = d0))
}
ape5 <- c(tight = ape_f(m_p5, "tight"), narrow = ape_f(m_p5, "narrow"))


## ----panel_extract, include=FALSE---------------------------------------------
g <- function(m, v, j) coeftable(m)[v, j]
sw <- pn %>% group_by(ticker) %>% summarise(k = n_distinct(tight)) %>% filter(k > 1) %>% pull(ticker)


## ----logit--------------------------------------------------------------------
m_lg  <- glm(dd ~ tight + narrow + lturn + lmc, family = binomial, data = pn)
m_lg0 <- glm(dd ~ 1, family = binomial, data = pn)
vc_lg <- vcovCL(m_lg, cluster = ~ticker)
ct <- coeftest(m_lg, vcov. = vc_lg)
ape_lg <- sapply(c("tight", "narrow", "lturn", "lmc"), function(v) {
  if (v %in% c("tight", "narrow")) { d1 <- pn; d0 <- pn
    d1$tight <- 0; d1$narrow <- 0; d0$tight <- 0; d0$narrow <- 0; d1[[v]] <- 1
    mean(predict(m_lg, d1, type = "response") - predict(m_lg, d0, type = "response"))
  } else mean(dlogis(predict(m_lg, type = "link"))) * coef(m_lg)[v] })
lg_tab <- tibble(`Biến` = c("Tight (room < 10%)", "Narrow (10% ≤ room < 30%)", "ln Turn", "ln MC"),
  `Hệ số β` = ct[-1, 1], `SE cụm` = ct[-1, 2], `Giá trị p` = paste0(pv(ct[-1, 4]), stars(ct[-1, 4])),
  `Tỷ số chênh (OR)` = exp(ct[-1, 1]),
  `KTC 95% của OR` = sprintf("[%.3f; %.3f]", exp(ct[-1, 1] - 1.96 * ct[-1, 2]), exp(ct[-1, 1] + 1.96 * ct[-1, 2])),
  `APE (điểm %)` = 100 * ape_lg)
knitr::kable(lg_tab, digits = 3,
  caption = "Bảng 6.3: Mô hình Logit cho xác suất một tháng có tỷ trọng thỏa thuận từ 50% trở lên")

# Độ phù hợp: LR, pseudo R2 McFadden, AUC
lr  <- 2 * (logLik(m_lg) - logLik(m_lg0)); lr_p <- pchisq(lr, df = 4, lower.tail = FALSE)
mcf <- 1 - as.numeric(logLik(m_lg) / logLik(m_lg0))
ph  <- fitted(m_lg); rk <- rank(ph)
auc <- (sum(rk[pn$dd == 1]) - sum(pn$dd) * (sum(pn$dd) + 1) / 2) / (sum(pn$dd) * sum(1 - pn$dd))
# Xác suất dự báo chuẩn hóa theo từng nhóm room
pr_b <- sapply(list(c(1, 0), c(0, 1), c(0, 0)), function(z) { d <- pn; d$tight <- z[1]; d$narrow <- z[2]
  mean(predict(m_lg, d, type = "response")) })
knitr::kable(tibble(`Chỉ tiêu` = c("Số sự kiện DD = 1 / số quan sát", "Thống kê LR so với mô hình rỗng (df = 4)",
                                   "Pseudo R² McFadden", "Diện tích dưới đường ROC (AUC)",
                                   "P(DD = 1) dự báo, nhóm room < 10%", "P(DD = 1) dự báo, nhóm 10% đến 30%",
                                   "P(DD = 1) dự báo, nhóm room ≥ 30%"),
                    `Giá trị` = c(paste0(sum(pn$dd), " / ", nrow(pn)), paste0(f1(lr, 2), " (p ", ifelse(lr_p < 0.001, "< 0.001", paste("=", f1(lr_p, 3))), ")"),
                                f1(mcf, 3), f1(auc, 3), pc(pr_b[1]), pc(pr_b[2]), pc(pr_b[3]))),
             caption = "Bảng 6.4: Độ phù hợp và xác suất dự báo của mô hình Logit")


## ----vif----------------------------------------------------------------------
v <- car::vif(lm(ds ~ tight + narrow + lturn + lmc, data = pn))
knitr::kable(tibble(`Biến` = names(v), VIF = v, `1/VIF` = 1 / v), digits = 3,
             caption = "Bảng 6.5: Hệ số phóng đại phương sai (VIF) của các biến trong M2")


## ----robust-------------------------------------------------------------------
pn_alt <- function(cut1) pn %>% mutate(tight = as.integer(x < cut1), narrow = as.integer(x >= cut1 & x < 0.30))
rob <- list(
  "Cơ sở (M2)" = m_p2,
  "Trọng số theo giá trị giao dịch (WLS)" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn, weights = ~turn, cluster = ~ticker),
  "Ngưỡng room cạn 5%" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn_alt(0.05), cluster = ~ticker),
  "Ngưỡng room cạn 15%" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn_alt(0.15), cluster = ~ticker),
  "Ngưỡng room cạn hẳn 1%" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn_alt(0.01), cluster = ~ticker),
  "Bỏ TCB" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = filter(pn, ticker != "TCB"), cluster = ~ticker),
  "Bỏ tháng 10 (nhiều giao dịch khối lớn)" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = filter(pn, month != 10), cluster = ~ticker),
  "Bỏ tháng có giao dịch ngoại dưới 10 tỷ" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = filter(pn, turn >= 10), cluster = ~ticker),
  "Hiệu ứng cố định mã và tháng (M4)" = m_p4,
  "Sai số chuẩn cụm hai chiều mã và tháng" = feols(ds ~ tight + narrow + lturn + lmc | m_f, data = pn, cluster = ~ticker + m_f))
rob_tab <- tibble(`Đặc tả` = names(rob),
  `β Tight` = sapply(rob, function(m) coeftable(m)["tight", 1]),
  `SE` = sapply(rob, function(m) coeftable(m)["tight", 2]),
  `Giá trị p` = sapply(rob, function(m) pv(coeftable(m)["tight", 4])),
  `β Narrow` = sapply(rob, function(m) coeftable(m)["narrow", 1]),
  `p Narrow` = sapply(rob, function(m) pv(coeftable(m)["narrow", 4])),
  N = sapply(rob, nobs))
knitr::kable(rob_tab, digits = 4, caption = "Bảng 6.6: Kiểm tra độ bền vững của tác động room cạn lên tỷ trọng thỏa thuận")


## ----fe_check-----------------------------------------------------------------
fe_list <- c(setNames(lapply(sw, function(d) feols(ds ~ tight + narrow + lturn | ticker + m_f,
                        data = filter(pn, ticker != d), cluster = ~ticker)), paste("M4 bỏ", sw)),
  list("M4 với ngưỡng cạn hẳn 1%" = feols(ds ~ tight + narrow + lturn | ticker + m_f, data = pn_alt(0.01), cluster = ~ticker)))
m_fex <- feols(ds ~ x + lturn | ticker + m_f, data = pn, cluster = ~ticker)
fe_tab <- bind_rows(
  tibble(`Đặc tả` = names(fe_list), `Biến` = "Tight",
         `Hệ số` = sapply(fe_list, function(m) coeftable(m)["tight", 1]),
         SE = sapply(fe_list, function(m) coeftable(m)["tight", 2]),
         `Giá trị p` = sapply(fe_list, function(m) pv(coeftable(m)["tight", 4])), N = sapply(fe_list, nobs)),
  tibble(`Đặc tả` = "M4 với room còn lại liên tục", `Biến` = "x", `Hệ số` = coeftable(m_fex)["x", 1],
         SE = coeftable(m_fex)["x", 2], `Giá trị p` = pv(coeftable(m_fex)["x", 4]), N = nobs(m_fex)))
sw1 <- pn %>% group_by(ticker) %>% summarise(k = n_distinct(x < 0.01)) %>% filter(k > 1) %>% pull(ticker)
knitr::kable(fe_tab, digits = 4, caption = "Bảng 6.7: Độ bền vững của mô hình hiệu ứng cố định mã và tháng")


## ----cross--------------------------------------------------------------------
cs <- st %>% filter(!is.na(net), !is.na(ytd), adtv > 0) %>%
  mutate(nint = net / mc * 100, lmc = log(mc), ladtv = log(adtv),
         ytd_w = pmin(pmax(ytd, quantile(ytd, 0.01)), quantile(ytd, 0.99)),
         bank = as.integer(nganh == "Ngân hàng"), bds = as.integer(nganh == "Bất động sản"))
c1 <- lm(nint ~ room + ff, data = cs)
c2 <- lm(nint ~ room + ff + lmc + ladtv, data = cs)
c3 <- lm(nint ~ room + ff + lmc + ladtv + ytd_w + bank + bds, data = cs)
cd <- cooks.distance(c3); infl <- which(cd > 4 / nrow(cs))
c4 <- lm(nint ~ room + ff + lmc + ladtv + ytd_w + bank + bds, data = cs[-infl, ])
c5 <- lm(rank(nint) ~ room + ff + lmc + ladtv + ytd_w + bank + bds, data = cs)   # hồi quy trên thứ hạng
cmods <- list(c1, c2, c3, c4, c5)
cv <- c("room", "ff", "lmc", "ladtv", "ytd_w", "bank", "bds")
cl <- c("Room còn lại", "Free float", "ln MC", "ln ADTV", "Tăng giá YTD (winsor 1%)", "Ngân hàng", "Bất động sản")
ctab <- do.call(rbind, lapply(seq_along(cv), function(k) {
  e <- sapply(cmods, function(m) { t <- coeftest(m, vcovHC(m, "HC3"))
    if (cv[k] %in% rownames(t)) paste0(f1(t[cv[k], 1], 3), stars(t[cv[k], 4])) else "" })
  s <- sapply(cmods, function(m) { t <- coeftest(m, vcovHC(m, "HC3"))
    if (cv[k] %in% rownames(t)) paste0("(", f1(t[cv[k], 2], 3), ")") else "" })
  rbind(c(cl[k], e), c("", s)) }))
bp <- bptest(c3); rs <- resettest(c3, power = 2:3)
rsp <- sapply(cmods, function(m) pv(resettest(m, power = 2:3)$p.value))
bpp <- sapply(cmods, function(m) pv(bptest(m)$p.value))
ctab <- rbind(ctab, c("Số quan sát", sapply(cmods, nobs)),
              c("p của Ramsey RESET", rsp), c("p của Breusch-Pagan", bpp),
              c("R²", sapply(cmods, function(m) f1(summary(m)$r.squared, 3))),
              c("R² hiệu chỉnh", sapply(cmods, function(m) f1(summary(m)$adj.r.squared, 3))))
colnames(ctab) <- c("Biến giải thích", "C1", "C2", "C3", "C4: C3 bỏ điểm ảnh hưởng", "C5: thứ hạng NetInt")
knitr::kable(ctab, align = "lccccc",
  caption = "Bảng 6.8: Hồi quy OLS cường độ ròng khối ngoại (% vốn hóa) theo đặc điểm mã (SE vững HC3 trong ngoặc)")
t3 <- coeftest(c3, vcovHC(c3, "HC3")); t4 <- coeftest(c4, vcovHC(c4, "HC3")); t5 <- coeftest(c5, vcovHC(c5, "HC3"))


## ----sim_base-----------------------------------------------------------------
by_b <- b0 %>% group_by(`Nút thắt` = bind) %>%
  summarise(`Số mã` = n(), `Nhu cầu` = sum(dem) / 1000, `Dư địa` = sum(cap) / 1000,
            `Hấp thụ` = sum(ab) / 1000, `Bỏ lỡ` = sum(gap) / 1000, .groups = "drop") %>%
  bind_rows(summarise(b0, `Nút thắt` = "Tổng rổ", `Số mã` = n(), `Nhu cầu` = sum(dem) / 1000,
                      `Dư địa` = sum(cap) / 1000, `Hấp thụ` = sum(ab) / 1000, `Bỏ lỡ` = sum(gap) / 1000))
knitr::kable(by_b, digits = 1, format.args = list(big.mark = ","),
             caption = "Bảng 7.1: Kết quả mô phỏng ở thiết lập cơ sở theo nút thắt (nghìn tỷ đồng)")


## ----fig_gap, fig.height=4.3, fig.cap="Hình 7.1: Các mã bị bỏ lỡ ở thiết lập cơ sở (tối đa 12 mã), tô màu theo nút thắt (nghìn tỷ đồng)"----
g12 <- b0 %>% filter(gap > 1e-6) %>% arrange(desc(gap)) %>% slice_head(n = 12) %>% mutate(t = reorder(t, gap))
ggplot(g12, aes(gap / 1000, t, fill = bind)) + geom_col(width = 0.7) +
  geom_text(aes(label = f1(gap / 1000)), hjust = -0.15, size = 3.1) +
  scale_fill_manual(values = c("Thanh khoản" = unname(COL["liq"]), "Room" = unname(COL["room"]), "Free float" = unname(COL["ff"]))) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) + labs(x = "Phần bỏ lỡ (nghìn tỷ đồng)", y = NULL)


## ----sim_ind------------------------------------------------------------------
ind <- b0 %>% group_by(`Ngành` = nganh) %>%
  summarise(`Số mã` = n(), `Nhu cầu` = sum(dem) / 1000, `Bỏ lỡ` = sum(gap) / 1000,
            `Mã bị room chặn` = sum(bind == "Room"), .groups = "drop") %>%
  mutate(`Bỏ lỡ / nhu cầu (%)` = 100 * `Bỏ lỡ` / `Nhu cầu`) %>% arrange(desc(`Bỏ lỡ`)) %>% slice_head(n = 6)
hot <- b0 %>% filter(bind == "Room", dem >= median(b0$dem)) %>% arrange(desc(gap))
knitr::kable(ind, digits = 1, caption = "Bảng 7.2: Sáu ngành có phần bỏ lỡ lớn nhất (nghìn tỷ đồng)")


## ----levers-------------------------------------------------------------------
lev_tab <- tibble(`Kịch bản` = c("Cơ sở", names(lev)),
                  `Độ phủ (%)` = 100 * c(cov0, lev_cov),
                  `Tăng thêm (điểm %)` = 100 * (c(cov0, lev_cov) - cov0),
                  `Hấp thụ (nghìn tỷ)` = c(cov0, lev_cov) * b0$tgt[1] / 1000)
knitr::kable(lev_tab, digits = 1, caption = "Bảng 7.3: Độ phủ khi dùng riêng từng đòn bẩy và khi dùng cả ba")


## ----fig_dose, fig.height=3.8, fig.cap="Hình 7.2: Độ phủ theo cường độ của từng đòn bẩy, các tham số khác giữ ở thiết lập cơ sở"----
dose <- bind_rows(
  tibble(d = seq(0, 10, 1), lever = "Nới room (điểm %)", c = sapply(seq(0, 10, 1), function(z) cov_of(sim(dr = z)))),
  tibble(d = seq(0, 20, 2), lever = "Tăng free float (điểm %)", c = sapply(seq(0, 20, 2), function(z) cov_of(sim(df = z)))),
  tibble(d = seq(0, 50, 5), lever = "Tăng thanh khoản (%)", c = sapply(seq(0, 50, 5), function(z) cov_of(sim(g = z)))))
dcol <- c("Nới room (điểm %)" = unname(COL["room"]), "Tăng free float (điểm %)" = unname(COL["ff"]),
          "Tăng thanh khoản (%)" = unname(COL["liq"]))
ggplot(dose, aes(d, 100 * c, colour = lever)) + geom_line(linewidth = 1) + geom_point(size = 1.8) +
  facet_wrap(~lever, scales = "free_x") + scale_colour_manual(values = dcol, guide = "none") +
  labs(x = "Cường độ đòn bẩy", y = "Độ phủ (%)")


## ----scen---------------------------------------------------------------------
scen <- list("US\\$1,5 tỷ, 100 mã lớn nhất" = list(), "US\\$2,2 tỷ, 100 mã lớn nhất" = list(tgtUsd = 2.2),
             "US\\$6 tỷ, 100 mã lớn nhất" = list(tgtUsd = 6), "US\\$1,5 tỷ, rổ 27 mã FTSE" = list(basket = "ftse"))
scen_tab <- bind_rows(lapply(names(scen), function(k) {
  a <- scen[[k]]; b <- do.call(sim, a); c0 <- cov_of(b)
  cv <- function(x) cov_of(do.call(sim, modifyList(a, x)))
  tibble(`Kịch bản` = k, `Số mã` = nrow(b), `Độ phủ cơ sở (%)` = 100 * c0,
         `Room +5 (điểm)` = 100 * (cv(list(dr = 5)) - c0), `Free float +10 (điểm)` = 100 * (cv(list(df = 10)) - c0),
         `Thanh khoản +20% (điểm)` = 100 * (cv(list(g = 20)) - c0), `Cả ba (%)` = 100 * cv(list(dr = 5, df = 10, g = 20)),
         `Thiếu dư địa: room / TK` = paste(sum(b$gap > 1e-6 & b$bind == "Room"), "/", sum(b$gap > 1e-6 & b$bind == "Thanh khoản")))
}))
knitr::kable(scen_tab, digits = 1, caption = "Bảng 7.4: Độ phủ và tác động của từng đòn bẩy theo tổng vốn và theo rổ")


## ----ftse_check---------------------------------------------------------------
knitr::kable(ftse_lost %>% transmute(`Mã` = t, `Headroom 30/6 (%)` = 100 * hr6, `Headroom 19/11 (%)` = 100 * room / fol,
                                     `Trần sở hữu (%)` = 100 * fol, `Cần nới để đạt 20% (điểm)` = 100 * need,
                                     `Vốn thụ động ước tính (triệu US$)` = usd),
             digits = 1, caption = "Bảng 7.5: Mã HOSE lớn không được FTSE chọn vì headroom ngày 30/6/2026 dưới 20%")


## ----fig_heat, fig.height=3.6, fig.width=7.5, fig.cap="Hình 7.3: Độ phủ cơ sở (%) theo số phiên giải ngân H và tỷ lệ tham gia tối đa p"----
grid <- expand.grid(H = c(20, 60, 120, 250, 500), p = c(5, 10, 15, 20, 25))
grid$c <- mapply(function(H, p) cov_of(sim(H = H, p = p)), grid$H, grid$p)
ggplot(grid, aes(factor(p), factor(H), fill = 100 * c)) + geom_tile(colour = "white") +
  geom_text(aes(label = f1(100 * c, 0), colour = c > 0.6), size = 3.6) +
  scale_colour_manual(values = c("TRUE" = "white", "FALSE" = "#1a202c"), guide = "none") +
  scale_fill_gradient(low = "#ebf4ff", high = unname(COL["liq"]), name = "Độ phủ (%)") +
  labs(x = "p, tỷ lệ tham gia tối đa (% GTGD ngày)", y = "H, số phiên")


## ----sim_sens-----------------------------------------------------------------
soe <- b0$t[b0$room == 0 & b0$fown < 0.01]
sens <- list(
  "Cơ sở" = list(),
  "US\\$6 tỷ" = list(tgtUsd = 6),
  "Bỏ mã bị bỏ lỡ nhiều nhất" = list(drop = top_t),
  "Bỏ các mã room = 0 và sở hữu ngoại < 1%" = list(drop = soe),
  "F = (free float − sở hữu ngoại) × vốn hóa" = list(ff_net = TRUE),
  "Độ co giãn ε = 0 (cả ba đòn bẩy)" = list(dr = 5, df = 10, g = 20, eps = 0),
  "Độ co giãn ε = 1 (cả ba đòn bẩy)" = list(dr = 5, df = 10, g = 20, eps = 1),
  "Rổ N = 50" = list(N = 50), "Rổ N = 150" = list(N = 150),
  "Chỉ đợt 1 (cộng dồn 10%)" = list(stage = 0.10))
names(sens)[3] <- paste("Bỏ", top_t, "khỏi rổ")
sens_tab <- tibble(`Kịch bản` = names(sens),
  `Số mã` = sapply(sens, function(k) nrow(do.call(sim, k))),
  `Độ phủ (%)` = sapply(sens, function(k) 100 * cov_of(do.call(sim, k))),
  `Bỏ lỡ (nghìn tỷ)` = sapply(sens, function(k) sum(do.call(sim, k)$gap) / 1000),
  `Mã bị room chặn` = sapply(sens, function(k) sum(do.call(sim, k)$bind == "Room")))
knitr::kable(sens_tab, digits = 1, caption = "Bảng 7.6: Độ nhạy của kết quả mô phỏng theo các giả định dữ liệu và tham số")


## ----summary_h----------------------------------------------------------------
sumh <- tibble(
  `Giả thuyết` = paste0("H", 1:7),
  `Phép kiểm / mô hình` = c("Kiểm định dấu, 11 tháng", "Bảng dữ liệu M2, SE cụm", "Bảng dữ liệu M2, SE cụm",
                            "Hiệu ứng cố định mã và tháng M4", "Logit, SE cụm", "OLS chéo C3, C4, C5, SE HC3",
                            "Mô phỏng hấp thụ, US\\$1,5 tỷ"),
  `Kết quả chính` = c(
    paste0(sum(mo$net < 0), "/11 tháng âm; p = ", formatC(sg$p.value, format = "f", digits = 5)),
    paste0("β = ", f1(g(m_p2, "tight", 1), 3), "; p ", ifelse(g(m_p2, "tight", 4) < 0.001, "< 0.001", paste("=", f1(g(m_p2, "tight", 4), 3)))),
    paste0("β = ", f1(g(m_p2, "narrow", 1), 3), "; p = ", f1(g(m_p2, "narrow", 4), 3)),
    paste0("β = ", f1(g(m_p4, "tight", 1), 3), "; p = ", f1(g(m_p4, "tight", 4), 3)),
    paste0("OR = ", f1(exp(ct[2, 1]), 2), "; APE = ", f1(100 * ape_lg[1]), " điểm %"),
    paste0("β_room = ", f1(t3["room", 1], 3), "; p = ", f1(t3["room", 4], 3)),
    paste0("Độ phủ ", pc(cov0), " (US\\$6 tỷ: ", pc(cov6), "); nút thắt thanh khoản ", sum(b0$bind == "Thanh khoản"), " mã, room ", sum(b0$bind == "Room"), " mã")),
  `Kết luận` = c(
    ifelse(sg$p.value < 0.05, "Dữ liệu ủng hộ H1", "Chưa đủ bằng chứng"),
    ifelse(g(m_p2, "tight", 4) < 0.05 & g(m_p2, "tight", 1) > 0, "Dữ liệu ủng hộ H2", "Chưa đủ bằng chứng"),
    ifelse(g(m_p2, "narrow", 4) < 0.05 & g(m_p2, "narrow", 1) > 0, "Dữ liệu ủng hộ H3", "Không ủng hộ H3 (quan hệ dạng ngưỡng)"),
    ifelse(g(m_p4, "tight", 4) < 0.05 & g(m_p4, "tight", 1) > 0, "Dữ liệu ủng hộ H4", "Chưa đủ bằng chứng"),
    ifelse(ct[2, 4] < 0.05 & ct[2, 1] > 0, "Dữ liệu ủng hộ H5", "Chưa đủ bằng chứng"),
    ifelse(t3["room", 4] >= 0.10 & t4["room", 4] >= 0.10 & t5["room", 4] >= 0.10, "Không bác bỏ H6 (không tìm thấy bằng chứng room giải thích bán ròng)", "Không ủng hộ H6"),
    ifelse(cov0 < 1 & sum(b0$bind == "Thanh khoản") > sum(b0$bind == "Room"), "Phù hợp H7", "Không phù hợp H7")))
knitr::kable(sumh, caption = "Bảng 8.1: Tổng hợp kết quả kiểm định các giả thuyết nghiên cứu")


## ----pol_channel, error=TRUE, fig.height=2.8, fig.cap="Hình 10.1: Vốn thụ động bị chặn theo từng kênh, kịch bản US\\$1,5 tỷ (triệu US\\$)"----
try({
abs100 <- usd_m(sum(b0$gap)); absF <- usd_m(sum(bF$gap))
bindF  <- if (sum(bF$gap) > 1e-6) names(which.max(tapply(bF$gap, bF$bind, sum))) else "Thanh khoản"
kenh <- tibble(
  kenh = c(paste0("Room, kênh loại mã (", nrow(ftse_lost), " mã bị FTSE loại)"),
           paste0("Room, kênh hấp thụ (rổ ", nrow(b0), " mã, ", short_n(b0), " mã thiếu dư địa)"),
           paste0(bindF, ", kênh hấp thụ (rổ ", nrow(bF), " mã FTSE thật)")),
  v    = c(lost_usd, abs100, absF),
  loai = c("Room", "Room", bindF))
ggplot(kenh, aes(v, reorder(kenh, v), fill = loai)) + geom_col(width = 0.6) +
  geom_text(aes(label = f1(v, 0)), hjust = -0.2, size = 3.4) +
  scale_fill_manual(values = c("Room" = unname(COL["room"]), "Thanh khoản" = unname(COL["liq"]),
                               "Free float" = unname(COL["ff"]))) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = "Triệu US$", y = NULL)
})


## ----pol_rank, error=TRUE-----------------------------------------------------
try({
st15 <- scen_tab[1, ]; st6 <- scen_tab[3, ]; stF <- scen_tab[4, ]
rank_tab <- tibble(
  c1 = c("1", "2", "3"),
  c2 = c("Đưa các mã bị FTSE loại trở lại headroom ≥ 20%; giữ mã lớn không chạm 0% room",
                           "Giữ lộ trình giải ngân nhiều đợt; tăng thanh khoản nhóm mã lớn",
                           "Công bố tỷ trọng thỏa thuận của khối ngoại theo mã làm chỉ báo cảnh báo sớm"),
  c3 = c(paste0(f1(lost_usd, 0), " + ", f1(abs100, 0)),
                                   paste0(f1(st15[[6]] * 15, 0), " (rổ 100 mã); ", f1(stF[[6]] * 15, 0), " (rổ FTSE)"),
                                   "Gián tiếp"),
  c4 = c(paste0(f1(st6[[4]] * 60, 0), " (room +5)"), paste0(f1(st6[[6]] * 60, 0), " (thanh khoản +20%)"), "Gián tiếp"),
  c5 = c("H2, H4, H5, H7; Bảng 6.6; Bảng 7.5", "H7; Bảng 7.4; Hình 7.3", "H2, H5; Bảng 5.2; Bảng 6.4"),
  c6 = c(paste0("Cao: ", pc(share_nolaw, 0), " số vốn không cần sửa luật"),
                    "Trung bình: cần nhiều cơ quan phối hợp", "Cao nhất: dữ liệu đã có, chi phí thấp"))
names(rank_tab) <- c("Ưu tiên", "Đòn bẩy chính sách", "US\\$1,5 tỷ (triệu US\\$)", "US\\$6 tỷ (triệu US\\$)",
                     "Bằng chứng chính", "Mức khả thi")
knitr::kable(rank_tab, caption = "Bảng 10.1: Xếp hạng ba ưu tiên chính sách theo vốn thu về, bằng chứng và mức khả thi")
})


## ----pol_map, error=TRUE------------------------------------------------------
try({
emap <- tibble(
  `Kết quả đã ước lượng` = c(
    paste("H1:", sumh[[3]][1]), paste("H2:", sumh[[3]][2]), paste("H3:", sumh[[3]][3]),
    paste("H4:", sumh[[3]][4]), paste("H5:", sumh[[3]][5]), paste("H6:", sumh[[3]][6]),
    paste0("H7: độ phủ ", pc(cov0), "; ", short_n(b0), " mã thiếu dư địa vì room"),
    paste0("Bảng 7.5: ", nrow(ftse_lost), " mã bị FTSE loại, khoảng ", f1(lost_usd, 0), " triệu US\\$"),
    paste0("Hình 7.3: giải ngân 20 phiên, p = 10% chỉ phủ ", f1(100 * grid$c[grid$H == 20 & grid$p == 10], 0), "%"),
    paste0("US\\$6 tỷ: ", sum(b6$gap > 1e-6 & b6$bind == "Thanh khoản"), " mã thiếu dư địa vì thanh khoản; ", top6_t, " chiếm ", pc(top6_share, 0), " phần bỏ lỡ"),
    "Hình 5.4: ca TCB, room bằng 0 đi kèm thỏa thuận chiếm phần lớn giao dịch"),
  `Ưu tiên 1` = c("", "Chính", "Phụ", "Chính", "Phụ", "", "Chính", "Chính", "", "Phụ", "Phụ"),
  `Ưu tiên 2` = c("", "", "", "", "", "", "Phụ", "", "Chính", "Chính", ""),
  `Ưu tiên 3` = c("", "Chính", "", "", "Chính", "", "", "", "", "", "Chính"),
  `Ranh giới` = c("Giới hạn", "", "Giới hạn", "", "", "Giới hạn", "", "", "", "", ""))
knitr::kable(emap, caption = "Bảng 10.2: Bản đồ bằng chứng. \"Chính\": căn cứ trực tiếp của khuyến nghị; \"Phụ\": căn cứ bổ trợ; \"Giới hạn\": kết quả đặt ranh giới cho khuyến nghị (Mục 10.5)")
})


## ----pol1_tab, error=TRUE-----------------------------------------------------
try({
knitr::kable(pol1 %>% arrange(buoc, desc(usd)) %>%
  transmute(`Bước` = buoc, `Mã` = t, `Headroom 30/6 (%)` = 100 * hr6, `Headroom 19/11 (%)` = 100 * room / fol,
            `Trần hiện tại (%)` = 100 * fol, `Trần luật định (%)` = 100 * tran_luat,
            `Cần nâng trần (điểm)` = 100 * need, `Vốn thụ động (triệu US$)` = usd),
  digits = 1, caption = "Bảng 10.3: Lộ trình theo mã cho Ưu tiên 1 (trần luật định: 30% với ngân hàng, 49% với doanh nghiệp khác; MBB có thể tới 49% theo Nghị định 69/2025)")
})


## ----pol1_fig, error=TRUE, fig.height=3.2, fig.cap="Hình 10.2: Vốn thụ động thu về cộng dồn theo ba bước của Ưu tiên 1 (triệu US\\$). Đường đứt: phần không cần sửa luật"----
try({
lab_b <- c("Bước 0" = "Bước 0: giữ nguyên", "Bước 1" = "Bước 1: doanh nghiệp tự nâng trần",
           "Bước 2" = "Bước 2: cần đổi khung trần")
colb  <- c("Bước 0" = unname(COL["ff"]), "Bước 1" = unname(COL["liq"]), "Bước 2" = unname(COL["room"]))
wf  <- pol1 %>% arrange(buoc, desc(usd)) %>%
  mutate(x1 = cumsum(usd), x0 = x1 - usd, y = match(buoc, names(lab_b)))
wfs <- wf %>% group_by(buoc, y) %>% summarise(x1 = max(x1), v = sum(usd), .groups = "drop")
nolaw <- sum(wf$usd[wf$buoc != "Bước 2"])
ggplot(wf) +
  geom_rect(aes(xmin = x0, xmax = x1, ymin = y - 0.35, ymax = y + 0.35, fill = buoc), colour = "white", linewidth = 0.6) +
  geom_text(data = filter(wf, usd >= 15), aes(x = (x0 + x1) / 2, y = y, label = t), colour = "white", size = 3, fontface = "bold") +
  geom_text(data = wfs, aes(x = x1, y = y, label = paste0("+", f1(v, 0))), hjust = -0.25, size = 3.3) +
  annotate("rect", xmin = 0, xmax = sum(wf$usd), ymin = 3.65, ymax = 4.35, fill = unname(COL["ink"])) +
  annotate("text", x = sum(wf$usd), y = 4, label = f1(sum(wf$usd), 0), hjust = -0.25, size = 3.3, fontface = "bold") +
  geom_vline(xintercept = nolaw, linetype = "dashed", colour = "grey40") +
  annotate("text", x = nolaw, y = 0.45, label = paste0("không cần sửa luật: ", pc(nolaw / sum(wf$usd), 0)),
           hjust = 1.05, size = 3.1, colour = "grey30") +
  scale_fill_manual(values = colb, breaks = names(lab_b), labels = unname(lab_b)) +
  scale_y_continuous(breaks = 1:4, labels = c("Bước 0", "Bước 1", "Bước 2", "Cộng dồn"), trans = "reverse") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(x = "Vốn thụ động ước tính thu về, cộng dồn (triệu US$)", y = NULL)
})


## ----pol1_cliff, error=TRUE, fig.height=3.2, fig.cap="Hình 10.3: Hệ số Tight theo ngưỡng định nghĩa room cạn, kèm khoảng tin cậy 95% (điểm %, từ Bảng 6.6)"----
try({
cl_tab <- tibble(nguong = factor(c("Dưới 15%", "Dưới 10%", "Dưới 5%", "Dưới 1%"),
                                 levels = c("Dưới 15%", "Dưới 10%", "Dưới 5%", "Dưới 1%")),
                 b = 100 * rob_tab[[2]][c(4, 1, 3, 5)], se = 100 * rob_tab[[3]][c(4, 1, 3, 5)])
ggplot(cl_tab, aes(nguong, b)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_errorbar(aes(ymin = b - 1.96 * se, ymax = b + 1.96 * se), width = 0.12, colour = unname(COL["room"])) +
  geom_line(aes(group = 1), colour = unname(COL["room"]), linewidth = 1) +
  geom_point(size = 3, colour = unname(COL["room"])) +
  geom_text(aes(label = f1(b)), nudge_x = 0.2, size = 3.4) +
  labs(x = "Ngưỡng định nghĩa room cạn (room còn lại / tổng room)", y = "Hệ số Tight (điểm %)")
})


## ----pol2_fig, error=TRUE, fig.height=3.4, fig.cap="Hình 10.4: Độ phủ theo số phiên giải ngân H, với ba mức tỷ lệ tham gia p, kịch bản US\\$1,5 tỷ (từ Hình 7.3)"----
try({
gp <- grid %>% filter(p %in% c(5, 10, 20)) %>%
  mutate(pl = factor(paste0("p = ", p, "%"), levels = paste0("p = ", c(5, 10, 20), "%")))
ggplot(gp, aes(H, 100 * c, colour = pl)) + geom_line(linewidth = 1) + geom_point(size = 2.2) +
  geom_text(data = filter(gp, H == 20), aes(label = f1(100 * c, 0)), hjust = 1.5, size = 3.3, show.legend = FALSE) +
  annotate("text", x = 250, y = 100 * grid$c[grid$H == 250 & grid$p == 10] + 5, label = "thiết lập cơ sở", size = 3.2) +
  scale_x_log10(breaks = c(20, 60, 120, 250, 500), expand = expansion(mult = c(0.1, 0.05))) +
  scale_colour_manual(values = c("#90cdf4", unname(COL["liq"]), "#1a365d")) +
  coord_cartesian(ylim = c(20, 105)) +
  labs(x = "H, số phiên giải ngân (thang log)", y = "Độ phủ (%)")
})


## ----pol2_lev, error=TRUE, fig.height=2.8, fig.cap="Hình 10.5: Vốn thu thêm khi dùng từng đòn bẩy ở kịch bản US\\$6 tỷ (triệu US\\$, từ Bảng 7.4)"----
try({
lev6 <- tibble(lv = c("Nới room +5 điểm %", "Tăng thanh khoản +20%", "Tăng free float +10 điểm %", "Cả ba đòn bẩy"),
               diem = c(st6[[4]], st6[[6]], st6[[5]], st6[[7]] - st6[[3]])) %>% mutate(usd = diem * 60)
ggplot(lev6, aes(usd, reorder(lv, usd), fill = lv)) + geom_col(width = 0.6) +
  geom_text(aes(label = paste0(f1(usd, 0), " (+", f1(diem), " điểm)")), hjust = -0.1, size = 3.3) +
  scale_fill_manual(values = c("Nới room +5 điểm %" = unname(COL["room"]), "Tăng thanh khoản +20%" = unname(COL["liq"]),
                               "Tăng free float +10 điểm %" = unname(COL["ff"]), "Cả ba đòn bẩy" = unname(COL["ink"])),
                    guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.35))) +
  labs(x = "Vốn thu thêm (triệu US$)", y = NULL)
})


## ----pol3_fig, error=TRUE, fig.height=3.2, fig.cap="Hình 10.6: Tỷ trọng thỏa thuận gộp (Bảng 5.2) và xác suất dự báo tháng do thỏa thuận chi phối (Bảng 6.4) theo nhóm room"----
try({
p3 <- tibble(nhom = rep(as.character(bk[[1]]), 2),
             chi_so = rep(c("Tỷ trọng thỏa thuận gộp theo giá trị", "Xác suất dự báo tháng thỏa thuận ≥ 50% (Logit)"), each = 3),
             v = c(bk[[4]], 100 * pr_b)) %>%
  mutate(nhom = factor(nhom, levels = as.character(bk[[1]])))
ggplot(p3, aes(nhom, v, fill = chi_so)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  geom_text(aes(label = paste0(f1(v), "%")), position = position_dodge(width = 0.75), vjust = -0.4, size = 3.2) +
  scale_fill_manual(values = c(unname(COL["room"]), unname(COL["gray"]))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = "Room còn lại / tổng room", y = "%")
})


## ----pol_bound, error=TRUE, fig.height=2.6, fig.cap="Hình 10.7: Quy mô dòng bán ròng năm 2026 so với vốn FTSE (nghìn tỷ đồng)"----
try({
bd <- tibble(dv = c("Khối ngoại bán ròng trên HOSE, 01/01 đến 19/11/2026", "Vốn thụ động FTSE (US$1,5 tỷ)",
                    "Ước tính FTSE gồm cả quỹ chủ động (US$6 tỷ)"),
             v = c(-ytd_net / 1000, 1.5 * 25.65, 6 * 25.65), loai = c("Bán ròng", "Vốn FTSE", "Vốn FTSE")) %>%
  mutate(dv = factor(dv, levels = rev(dv)))
ggplot(bd, aes(v, dv, fill = loai)) + geom_col(width = 0.6) +
  geom_text(aes(label = f1(v)), hjust = -0.2, size = 3.4) +
  scale_fill_manual(values = c("Bán ròng" = unname(COL["gray"]), "Vốn FTSE" = unname(COL["liq"])), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) + labs(x = "Nghìn tỷ đồng", y = NULL)
})


## ----pol_road, error=TRUE-----------------------------------------------------
try({
road <- tibble(
  `Mốc` = c("Trước kỳ rà soát 3/2027 (đợt 2, cộng dồn 30%)", "Mùa đại hội cổ đông 2027, trước kỳ 6/2027 và 9/2027 (70% tỷ trọng còn lại)",
            "Từ năm 2027", "Hàng tháng"),
  `Việc cần làm` = c(
    paste0("Bước 0: ", paste(pol1$t[pol1$buoc == "Bước 0"], collapse = ", "), " giữ headroom ≥ 20%. Bắt đầu công bố chỉ báo của Ưu tiên 3."),
    paste0("Bước 1: ", paste(pol1$t[pol1$buoc == "Bước 1"], collapse = ", "), " thông qua nâng trần sở hữu nước ngoài. Giữ lộ trình bốn đợt (Ưu tiên 2)."),
    paste0("Bước 2: rà soát khung trần cho ", paste(pol1$t[pol1$buoc == "Bước 2"], collapse = ", "), ". Chuẩn bị thanh khoản cho kịch bản US\\$6 tỷ."),
    "Cập nhật room, tỷ trọng thỏa thuận và độ phủ mô phỏng."),
  `Chủ thể` = c("Doanh nghiệp, UBCKNN, sở giao dịch", "Đại hội đồng cổ đông, NHNN, Bộ Tài chính",
                "Chính phủ, NHNN, Bộ Tài chính, HOSE", "UBCKNN, nhóm nghiên cứu"),
  `Hoàn thành khi` = c("Các mã Bước 0 được FTSE xét lại", "Các mã Bước 1 đạt headroom ≥ 20%",
                       "Có quyết định về khung trần", "Có báo cáo tháng"))
knitr::kable(road, caption = "Bảng 10.4: Lộ trình thực hiện theo các đợt giải ngân của FTSE")

kpi <- tibble(
  `Chỉ báo` = c("Vốn thụ động mất do headroom dưới 20% (triệu US\\$)", "Số mã rổ 100 thiếu dư địa vì room, US\\$1,5 tỷ",
                "Độ phủ mô phỏng, US\\$1,5 tỷ", "Độ phủ mô phỏng, US\\$6 tỷ", "Tỷ trọng thỏa thuận gộp, nhóm room dưới 10%"),
  `Hiện tại (19/11/2026)` = c(f1(lost_usd, 0), sum(b0$gap > 1e-6 & b0$bind == "Room"), pc(cov0), pc(cov6), paste0(f1(bk[[4]][1]), "%")),
  `Mục tiêu` = c(paste0("≤ ", f1(sum(pol1$usd[pol1$buoc == "Bước 2"]), 0), " sau Bước 0 và Bước 1"), "0",
                 paste0(pc(lev_cov[1]), " (nới room +5 điểm)"), paste0("≥ ", pc(cov6_all), " (cả ba đòn bẩy)"),
                 paste0("Tiến về ", f1(bk[[4]][3]), "% (mức nhóm room rộng)")),
  `Ưu tiên` = c("1", "1", "1", "2", "3"))
knitr::kable(kpi, caption = "Bảng 10.5: Chỉ báo theo dõi, giá trị hiện tại và mục tiêu mà mô phỏng cho thấy đạt được")
})


## ----next_fig, error=TRUE, fig.height=3.2, fig.cap="Hình 11.1: Độ phủ dịch chuyển bao nhiêu điểm phần trăm so với thiết lập cơ sở khi đổi từng giả định (từ Bảng 7.6)"----
try({
sd_tab <- sens_tab %>% filter(!grepl("ε|Cơ sở", `Kịch bản`)) %>%
  mutate(d = `Độ phủ (%)` - sens_tab[[3]][1], kb = gsub("\\\\", "", `Kịch bản`))
ggplot(sd_tab, aes(d, reorder(kb, abs(d)), fill = d < 0)) + geom_col(width = 0.6) +
  geom_vline(xintercept = 0, colour = "grey40") +
  geom_text(aes(label = f1(d), hjust = ifelse(d < 0, 1.15, -0.15)), size = 3.3) +
  scale_fill_manual(values = c("TRUE" = unname(COL["room"]), "FALSE" = unname(COL["liq"])), guide = "none") +
  scale_x_continuous(expand = expansion(mult = 0.15)) +
  labs(x = "Thay đổi độ phủ so với cơ sở (điểm %)", y = NULL)
})


## ----next_tab, error=TRUE-----------------------------------------------------
try({
nxt <- tibble(
  `Thứ tự` = 1:6,
  `Giới hạn hiện tại` = c(
    paste0("Nhu cầu phân bổ theo free float, chưa trừ sở hữu ngoại (−", f1(sens_tab[[3]][1] - sens_tab[[3]][5]), " điểm)"),
    paste0("Quy mô vốn bất định (−", f1(sens_tab[[3]][1] - sens_tab[[3]][2]), " điểm ở US\\$6 tỷ)"),
    paste0("Chưa phải quan hệ nhân quả; hiệu ứng cố định mã dựa vào ", length(sw), " mã đổi trạng thái"),
    "Chưa có giá giao dịch thỏa thuận",
    "Sau ngày hiệu lực mới có 2 tháng, tháng 11 chưa trọn",
    "Dashboard cần dán dữ liệu thủ công cho chế độ mô phỏng trực tiếp"),
  `Hướng tiếp theo` = c(
    "Dùng trọng số đầu tư được (investability weight) thật của FTSE cho 27 mã, trừ sở hữu ngoại hiện hữu",
    "Mô phỏng theo lịch 10/20/35/35% và các kịch bản thêm quỹ chủ động, nâng hạng MSCI",
    "Nghiên cứu sự kiện và sai biệt kép quanh các lần đổi trần room; yêu cầu công bố trần trong 12 tháng của Nghị định 245/2025 tạo thêm nhiều mã đổi trạng thái",
    "Thu thập giá thỏa thuận, so với giá khớp lệnh cùng ngày",
    "Chạy lại kiểm định dấu và kiểm định gãy cấu trúc sau đợt giải ngân 3/2027",
    "Nhúng dữ liệu mã vào sản phẩm, tự cập nhật hàng tháng; mở rộng sang HNX và UPCoM"),
  `Kết quả kỳ vọng` = c(
    paste0("Độ phủ chính xác trong khoảng ", f1(sens_tab[[3]][5]), "% đến ", pc(cov0)),
    "Biết đợt nào, mã nào nghẽn trước",
    "Ước lượng tác động nhân quả của nới room",
    "Đo phần bù room bằng tiền, lượng hóa chi phí của room cạn",
    "Biết nâng hạng có làm đổi xu hướng dòng vốn hay không",
    "Công cụ giám sát dùng được ngay cho cơ quan quản lý"))
knitr::kable(nxt, caption = "Bảng 11.1: Sáu hướng phát triển tiếp theo, mỗi hướng gắn với một giới hạn hiện tại")
})


## ----session------------------------------------------------------------------
cat(R.version.string, "\n")
pk <- c("dplyr", "tidyr", "readr", "ggplot2", "fixest", "sandwich", "lmtest", "car", "patchwork")
knitr::kable(tibble(`Gói` = pk, `Phiên bản` = sapply(pk, function(p) as.character(packageVersion(p)))),
             caption = "Bảng A.1: Phiên bản các gói R")

