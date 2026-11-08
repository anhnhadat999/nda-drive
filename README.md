# NDA Drive

Pô ảo cho xe: giả lập tiếng pô xe xăng thể thao trên iPhone đã jailbreak (Dopamine, iOS 15–16, rootless).

- Cắm Apple CarPlay → tiếng đề máy, nổ máy.
- Xe chạy → tiếng động cơ theo tốc độ GPS: hộp số ảo 6 cấp, tự sang số, nổ lụp bụp khi nhả ga.
- Rút CarPlay → tắt máy.
- 15 kiểu tiếng: 6 mẫu Porsche (911 GT3, 718 Cayman GT4 RS, 911 Turbo S, 911 Carrera S, 718 Cayman S, Carrera GT) và V12, V10, V8 tăng áp, V8 Mỹ, 6 máy, 5 máy, VTEC, 4 máy turbo, rotary.
  Âm thanh được tổng hợp bằng toán học, không dùng bản ghi âm của hãng xe nào.

## Thành phần
| Thư mục | Vai trò |
|---|---|
| `app/` | App NDA Drive: chạy ngầm, GPS, tạo âm thanh (`PASynth.c`), phát hiện CarPlay, màn hình cài đặt |
| `tweak/` | Tweak nhỏ trong SpringBoard: tự mở ngầm app sau khi jailbreak/respring và khi cắm CarPlay |
| `test/sim.c` | Chạy thử bộ tạo âm trên máy tính, xuất WAV |

## Biên dịch
GitHub Actions tự biên dịch mỗi lần đẩy mã lên, kết quả ở mục **Releases → latest** (`.deb`).

Biên dịch thủ công (cần Theos): `make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`

## Cài trên iPhone
1. Mở Dopamine, bấm Jailbreak (nếu chưa).
2. Tải tệp `.deb` trong Releases, mở bằng **Sileo** (hoặc Filza → Install).
3. Respring. Mở app **Pô Ảo**, bấm **Cấp quyền vị trí** và chọn **Luôn luôn**.
4. Chọn kiểu động cơ, chỉnh âm lượng. Thử bằng mục **Thử khi đỗ xe**.

## An toàn
Chỉnh âm lượng vừa phải để vẫn nghe được còi xe và xe ưu tiên.
