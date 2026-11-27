# Lịch sử rút gọn (chỉ mở khi cần tra lại – phiên mới KHÔNG cần đọc)

## Mốc phiên bản
| Bản | Nội dung chính |
|---|---|
| ≤1.4 | Pô ảo iOS: 15 tiếng tổng hợp, hộp số ảo, GPS + cảm biến (Kalman), tự nổ máy khi CarPlay, đo âm học khoang xe, tự học độ bốc |
| 1.5–1.6 | Mô phỏng xe điện mạnh (mã lực, 0–100, trọng lượng → độ bốc), lớp gằn/dòn/cơ khí/khoang xe, thu thập im lặng, giai đoạn 7 ngày, đánh giá hệ thống. 1.5.0 màn hình đen (scene manifest) → 1.5.1 sửa |
| 1.7.0 | Bỏ CarPlay UI (văng app), thu thập chạy độc lập "Bật pô ảo", tự phát hiện xe chạy bằng GPS. Android 0.7.0 tương tự |
| 1.8.0 | Giao diện 3 tab (Nổ máy / Theo dõi im lặng / Cài đặt), 11 xe VinFast, `profiles.json` theo xe, báo cáo hệ thống, bản web dùng lõi C qua WebAssembly. CI chuyển sang Linux |
| 1.8.1 | Kiểm thử sức chịu đựng: chặn GPS/cảm biến hỏng (NaN), GPS lặp số cũ không coi là mất sóng |
| 1.8.2 | Chờ tiết kiệm pin khi xe đỗ (iOS), GPS chờ theo nguồn điện (Android) |
| 1.8.3 | Tweak chẩn đoán CarPlay (chỉ đọc) + ghi đường âm thanh |
| 1.8.4 / A 0.7.3 / web 1.8.5 | 12 lỗi từ giả lập + rà mã (hầm chui, kẹt xe, -ffast-math, tải lại trang…); trang Kiểm tra âm thanh trên web |
| 1.8.5 / A 0.7.4 / web 1.8.6 | Báo cáo 24/11 (90 chuyến, 448 km): CarPlay trễ 1035 ms → thêm Kiểm tra đầu ra CarPlay (tự chọn kiểu phát trễ thấp nhất), bù trễ tới 1,0 s; tiếng xe điện mạnh theo chân ga rõ hơn (tải^0.65); GPS kiểm tra khi đỗ không tính là lỗi; đánh giá GPS/cảm biến "đang nghỉ" khi xe đỗ |
| 1.8.6 / A 0.7.5 / web 1.8.7 | Giả lập lại 1.192 phút lái thật: bù trễ tối ưu = 40% trễ loa (bù 100% làm xấu hơn); dự đoán đạp ga (jerk) không đáng → tắt. Trang "Đo tín hiệu CarPlay" (tai & mắt, tiếng tích trong lõi C), tweak gửi tín hiệu qua Darwin notify (vượt hộp cát). Kết luận: phải giảm trễ đường phát (docs/CARPLAY-DO-TRE.md) |
| 1.8.7 | 1.8.6 treo táo sau khởi động lại: tweak chẩn đoán nạp vào mediaserverd/audiomxd. Sửa: chỉ airplayd/carkitd, mặc định tắt, chống văng lặp |

## Quyết định đã chốt
- Hồ sơ cập nhật theo xe = tệp tĩnh `profiles.json` trên GitHub Pages (miễn phí), không máy chủ thu dữ liệu; báo cáo gửi thủ công.
- Âm thanh pô luôn tổng hợp, không bản ghi; icon tự vẽ kiểu iOS.
- CarPlay không dây trên VF7 → cần chẩn đoán định dạng trước khi làm tweak lossless.
- Dữ liệu khách hàng/giao dịch giữ trong App ndarealty; Drive cho kho ảnh + dữ liệu dự án.

## Hỏi đáp đã có kết luận (không cần hỏi lại)
- **Âm thanh xe**: CarPlay chỉ ra stereo → không có Dolby Atmos thật; nâng cấp lớn nhất là chỉnh DSP STEG (căn thời gian, phân tần, EQ). Apple Music Lossless + tắt EQ/Sound Check. Tweak chỉ ép PCM được nếu xe khai báo hỗ trợ.
- **CarPlay + nhạc/YouTube khi thu thập**: không ảnh hưởng (phát trộn, không chiếm điều khiển, không dùng micro).
- **Loa sau xe**: thùng kín treo cao, ống cong xuống dưới cản, đặt giữa; woofer HanoSonic + STEG MS 650; bản vẽ ở artifact "Thùng pô dưới cản". Chờ số đo loa.
- **Mac mini M6 16/256 (cũ ~21tr) vs PC i7/32GB/RTX 4060 (~33tr mới)**: Mac hợp làm việc/dựng video/phát triển app iPhone; PC hợp game/3D/AI CUDA. M6 có thật (ra 25/8/2026, giá mới 24,99tr).
- **iPad iPadOS 27.2.1**: TrollStore không được (chỉ ≤17.0); dùng AltStore/SideStore (7 ngày, 3 app) hoặc tài khoản nhà phát triển.
- **Router Xiaomi AX3200 (RB01)**: cài OpenWrt bằng XMiR-Patcher (sao lưu kỹ); hướng dùng: chặn quảng cáo + VPN, tự gửi báo cáo khi về nhà, Wi‑Fi chào ndarealty (captive portal, chỉ mạng mình quản lý). Router không làm kho dữ liệu (không USB) – kho = Google Drive (+ NAS sau).
- **Sony Ericsson Aino**: theme `.thm` kiểu iOS cần 1 tệp .thm mẫu từ máy; icon sâu hệ thống phải nạp lại firmware (rủi ro).
- **Đã từ chối**: tìm/crack game Tru Thần, mở khoá xe bằng sóng 315 MHz, can thiệp mạng người khác, thu thập dữ liệu ngầm.

## Lưu trữ đầy đủ
Bản trò chuyện nguyên văn được gửi riêng cho chủ dự án (có thông tin cá nhân nên KHÔNG đưa lên kho công khai).
