# Độ trễ & tín hiệu CarPlay – kết quả đo và lộ trình

## 1. Kết quả từ dữ liệu thật (báo cáo 24/11, VF 7 Plus, CarPlay không dây)
- iOS báo trễ ra loa CarPlay: **1035 ms** (48 kHz, stereo). Loa iPhone: ~10 ms.
- Giả lập lại **1.192 phút lái thật** (30 chuyến) qua lõi C (`tools/replay_trip.c`):

| Tình huống | Tiếng đạp ga nghe thấy chậm | Sai tốc độ tiếng |
|---|---|---|
| Loa không trễ (iPhone/dây) | 0,57 s (do lọc nhiễu nội bộ) | 0,4 km/h |
| CarPlay 1,04 s, không bù | 1,17 s | 2,34 km/h |
| CarPlay, bù tốc độ 100% (bản ≤1.8.5) | 1,23 s | 2,38 km/h |
| **CarPlay, bù tốc độ 40% (1.8.6)** | 1,15 s | **2,25 km/h** |
| Dự đoán cả cú đạp ga (jerk 100%) | 1,04 s | 2,49 km/h, đảo số ×5, gằn sai lúc ×2 |

**Kết luận:** dự đoán chỉ bù được phần nhỏ. Cú đạp/nhả ga của người lái không đoán trước được, đoán càng mạnh càng sai.
Muốn tiếng ăn chân ga qua CarPlay phải **giảm độ trễ đường phát**. Các tham số lọc nội bộ đã ở mức tối ưu:
lọc nhanh hơn chỉ đỡ 0,1 s nhưng đảo số tăng 4–6 lần.

## 2. Các cách đo đã có trong app (1.8.6)
| # | Cách | Đo được gì | Độ tin cậy |
|---|---|---|---|
| A | iOS báo trễ (`outputLatency`) theo 3 kiểu phát (nhạc / dẫn đường / lời nói) – tự chạy lần đầu cắm CarPlay | trễ iOS ước tính theo kiểu phát | trung bình (iOS có thể báo con số cố định) |
| B | **Tai & mắt**: loa xe phát "tích", vòng tròn chớp lệch một khoảng kéo được; kéo tới khi trùng → lưu | trễ THẬT tới tai người nghe | ±30–50 ms, không cần thiết bị |
| C | **Tweak qua Darwin notify** (vượt hộp cát): báo tweak đã nạp vào airplayd/carkitd/mediaserverd/audiomxd chưa; lọc từ thông điệp cài đặt CarPlay: loại luồng (96 thời gian thực / 103 đệm), kiểu nén (PCM/ALAC/AAC-LC/AAC-ELD/Opus), tần số, mẫu/khung, trễ tối đa; `audioLatencies` xe tự báo theo kiểu âm thanh; bộ mã hoá + bitrate | định dạng & trễ xe khai báo | cao (số của chính giao thức) |
| D | Đo âm học hiện có (micro iPhone) khi đang cắm CarPlay | trễ đường thoại (PlayAndRecord) | cao, nhưng là đường gọi điện |

Kết quả nằm trong báo cáo .zip: `carplay_thu_dau_ra`, `carplay_tre_do_tai_mat_ms`, `carplay_tin_hieu`.

## 3. Lộ trình giảm trễ (theo thứ tự thử)
1. **Kiểu phát dẫn đường / lời nói** (đã làm, tự chọn nếu iOS báo nhanh hơn ≥120 ms). Nếu đo tai & mắt cũng nhanh hơn → giữ.
2. **Đường thời gian thực (luồng 96, "alt audio")**: CarPlay dùng luồng đệm 103 cho nhạc (trễ ~1–2 s) và luồng 96 cho thoại/cảnh báo (trễ thấp).
   Khi tweak báo được 2 luồng + `audioLatencies` → biết chênh lệch thật. Nếu luồng 96 nhanh và chất lượng chấp nhận được (AAC-ELD 44–48 kHz):
   - thử phiên `PlayAndRecord` + `VoiceChat`/`Default` (kênh thoại; có thể mono/16–24 kHz) – cần chủ dự án đồng ý vì bật chấm cam micro;
   - hoặc tweak trong airplayd gắn âm thanh NDA Drive vào luồng 96 (nghiên cứu, rủi ro cao, có công tắc tắt).
3. **Giảm bộ đệm phía xe**: nếu luồng 103 khai báo `latencyMax` lớn, thử tweak giảm (chỉ khi xe chấp nhận, có công tắc).
4. **Không qua CarPlay**: web trên trình duyệt VF7 phát thẳng ra loa xe (trễ trình duyệt ~50–150 ms) – xem kết quả "Kiểm tra âm thanh" web.
5. **Đo chéo 2 máy** (dự phòng): Android/web nghe tiếng tích có mã thời gian qua micro, đồng bộ giờ mạng → trễ tuyệt đối (±50 ms).

## 4. Công cụ
- `tools/replay_trip.c` – chạy lại tệp CSV chuyến đi qua lõi C. Tuỳ chọn: `-L` trễ loa, `-lead` bù, `-j` dự đoán jerk, `-g` đường cong tải.
- `test/data/chuyen_that_*.csv` – 3×10 phút chuyến thật (chỉ thời gian/tốc độ/gia tốc/độ dốc, không toạ độ) dùng trong `test/run_tests.sh`.
- `tweak/NDACarSignal.h` – mã hoá bản ghi tín hiệu 64 bit dùng chung tweak ↔ app.
