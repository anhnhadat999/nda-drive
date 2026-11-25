# TIẾP TỤC – bàn giao NDA Drive (cập nhật 25/11/2026)

## 1. Đang ở đâu
| Nền tảng | Phiên bản | Tải về |
|---|---|---|
| iPhone 12 (iOS 15.1.1, Dopamine rootless) | **1.8.5** (build 32) | release `latest` → `com.ndarealty.ndadrive_X_iphoneos-arm64.deb`; nguồn Sileo `https://raw.githubusercontent.com/anhnhadat999/nda-drive/gh-pages/` |
| Android (Samsung A7) | **0.7.4** (code 11) | release `android-latest` → `NDADrive-android-X.apk` |
| Web (iPhone/Android/màn hình VF7) | **1.8.6-web** | https://anhnhadat999.github.io/nda-drive/drive.html |
| Xe | VinFast VF 7 Plus 349 HP, 2.205 kg, 0–100 5,8 s, **CarPlay không dây** | |

## 2. Bản đồ hệ thống (chỉ mở đúng tệp cần)
- **Lõi C dùng chung 3 nền tảng** – `app/PASynth.c` (15 tiếng tổng hợp + vật lý số/vòng tua/tải, `mute`, `pa_step`), `app/PAFusion.c` (Kalman GPS+IMU, học hướng máy, trễ GPS, chặn NaN + `heal()`, `paf_speed_usable` giữ tốc độ 60 s khi mất GPS), `app/PALearn.c` (tự học độ bốc/phong cách).
- **iOS** `app/`:
  - `PAEngine.m` = bộ não: chế độ (`startDriveMode`/`startTracking`), `evaluate` (shouldRun), `detectDriving` (>12 km/h 4 s → nổ; <4 km/h **liên tục** 180 s → kết thúc), chờ tiết kiệm pin (đỗ >2 phút: GPS 100 m, tắt cảm biến; dậy khi >8 km/h hoặc đi >80 m), canh gác GPS/IMU/âm thanh, `snapshotRoute`.
  - Giao diện 3 tab: `PARootViewController` (Nổ máy: nút ENGINE START STOP, la bàn, 2 đồng hồ), `PADashboardViewController` (Theo dõi im lặng), `PASettingsMenuViewController` → các trang con (`PACarsViewController` tiếng, `PAVehicleViewController` xe + biệt danh người lái thử, `PASettingsViewController initWithSections:`, `PAReportViewController`).
  - Dữ liệu: `PAMotion.m` (CSV 37 cột/chuyến + `tripStats`), `PATrial` (7 ngày), `PAAssess` (đánh giá), `PADiag` (báo cáo .zip), `PAExport`, `PAVehicles` (11 xe VinFast), `PAProfiles` (tải `profiles.json`).
- **Tweak** `tweak/`: `Tweak.x` (SpringBoard: mở ngầm app, báo CarPlay); `CarPlayDiag.x` (CHỈ ĐỌC, nạp airplayd/carkitd/mediaserverd/audiomxd: ghi plist cấu hình CarPlay + AudioConverter vào `/var/jb/var/mobile/Library/NDADrive/carplay-diag/`, tắt bằng tệp `carplay-diag.off`).
- **Android** `android/…/ndadrive/`: `EngineService.kt` (foreground, GPS chờ 2 s cắm sạc / 10 s chạy pin, tự phát hiện xe chạy), `nda_jni.c`. **Chưa có giao diện 3 tab + chọn xe.**
- **Web** `web/app.html` + `web/wasm/` (lõi C → WebAssembly bằng clang/lld, `web/build-web.sh` nhúng base64 → `repo-static/drive.html`). Có trang **Kiểm tra âm thanh** (3 phép thử) + đường phát qua trình phát media.
- **Máy chủ tĩnh** `repo-static/` → nhánh gh-pages: `drive.html`, `profiles.json` (thông số xe + bộ tinh chỉnh tiếng theo xe, tăng `rev` để đẩy cho mọi máy), kho Sileo.
- **CI**: `.github/workflows/build.yml` (**ubuntu-24.04 + Theos Linux toolchain** – GitHub thiếu máy macOS), `android.yml` (chỉ chạy khi đổi `android/**` hoặc lõi C).
- **Kiểm thử**: `test/run_tests.sh` (synth, fusion 5 kịch bản, EQ, zip, mute, âm học, học, **stress** NaN/∞/thời gian lùi). Công cụ: `tools/analyze_trip.py`.
- Khác: `extras/aino-proxy/` (proxy trình duyệt cho Sony Aino).

## 3. Bài học (đừng lặp lại)
- Entitlement/khung CarPlay còn sót → app văng khi cắm CarPlay. Scene manifest → màn hình đen. Tên `+load` trùng NSObject. Trùng tên class giữa các tệp.
- `-ffast-math` (Android) xoá mất `isfinite` → luôn kèm `-fno-finite-math-only`. Chú thích `//` trên cùng dòng `{ … }` trong gradle nuốt dấu ngoặc.
- Một bản tin GPS NaN từng làm hỏng Kalman vĩnh viễn (đã chặn). GPS lặp số cũ không được coi là mất sóng (≤6 lần).
- Web: Safari chỉ cho bật âm thanh **ngay trong lúc chạm** + nút Im lặng tắt Web Audio (dùng `navigator.audioSession='playback'` + tệp im lặng). Dùng `performance.now()` cho cả cảm biến và GPS (không dùng `event.timeStamp`). Lưu tạm chuyến mỗi 15 s (trình duyệt xe hay tải lại trang).
- Lệnh shell có heredoc chứa chữ giống `rm` có thể bị chặn → viết tệp bằng công cụ Write.

## 4. Đang chờ chủ dự án gửi
0. **Kết quả "Kiểm tra đầu ra CarPlay"** (iPhone 1.8.5 tự chạy lần đầu cắm CarPlay; có trong báo cáo .zip mục `carplay_thu_dau_ra`). Báo cáo 24/11: CarPlay không dây VF7 trễ **1035 ms**, 48 kHz stereo.
1. **Báo cáo 3 máy** (iPhone 1.8.4, A7 0.7.3, web trên VF7) sau 2–3 ngày chạy chung 1 xe (máy gắn chặt, chỉ 1 máy phát tiếng).
2. ~~Chẩn đoán CarPlay~~: báo cáo 24/11 chỉ có log carkitd (Wi‑Fi/MDM), **không có** airplayd/mediaserverd → chưa biết định dạng mã hoá. Cần khởi động lại iPhone (userspace reboot) để tweak nạp vào airplayd rồi xuất lại.
3. **Kết quả Kiểm tra âm thanh trên trình duyệt VF7** (Thử 1/2/3) + YouTube trên trình duyệt xe có tiếng không.
4. Mẫu **DSP STEG** + sơ đồ loa; số đo loa (lỗ khoét, vòng bắt ốc, chiều sâu) cho thùng pô.
5. Một tệp **.thm** từ Sony Aino (để làm theme kiểu iOS đúng chuẩn).
6. Nội dung **Wi‑Fi chào ndarealty** (căn nổi bật, số/Zalo, có ô để lại SĐT không).

## 5. Việc tiếp theo – xếp theo ưu tiên (làm khi có dữ liệu ở mục 4)
| # | Việc | Cần | Ước lượng |
|---|---|---|---|
| P1 | Đọc `carplay_thu_dau_ra`: nếu kiểu dẫn đường/lời nói không nhanh hơn → thử kiểu PlayAndRecord (kênh thoại, trễ thấp nhưng mono/chất kém, cần chủ dự án đồng ý) | mục 4.0 | ngắn |
| P1 | Phân tích báo cáo 3 máy → chỉnh `profiles.json` (rev+1) cho VF 7 Plus, bù trễ theo máy | mục 4.1 | 1 phiên |
| P1 | Sửa âm thanh web trên VF7 theo kết quả thử (nếu chỉ Thử 1 nghe → phát bằng chuỗi tệp WAV) | mục 4.3 | ngắn |
| P1 | Tweak can thiệp CarPlay: ưu tiên PCM / tăng bitrate AAC (có công tắc) **chỉ khi** chẩn đoán cho thấy xe hỗ trợ | mục 4.2 | 1 phiên |
| P2 | Android: giao diện 3 tab + chọn xe + biệt danh (đồng bộ với iOS) | – | 1 phiên |
| P2 | Đo âm học khoang xe → bảng gợi ý DSP STEG (trễ/phân tần/EQ) | mục 4.4 | 1 phiên |
| P3 | Router AX3200 (RB01) OpenWrt: chặn quảng cáo + VPN; tự gửi báo cáo khi về nhà; captive portal ndarealty | cài OpenWrt + mục 4.6 | mỗi việc 1 phiên |
| P3 | Theme Sony Aino kiểu iOS | mục 4.5 | ngắn |
| P3 | Kho Google Drive (Kho ảnh / Dự án + bảng danh mục) | chủ dự án đồng ý tạo | ngắn |

## 6. Tra lịch sử
Mốc phiên bản, quyết định đã chốt, các câu hỏi đã có kết luận: `docs/LICH-SU.md` (chỉ mở khi cần).

## 7. Cách chủ dự án làm việc
Chỉ nói ý tưởng hoặc gửi tệp/ảnh bằng lời tự nhiên – Claude tự hiểu (bảng trong `CLAUDE.md`), tự làm trọn vòng.
Cuối mỗi phiên Claude tự cập nhật mục 1, 4, 5 của tệp này.
