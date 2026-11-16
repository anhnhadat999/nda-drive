# Quy tắc làm việc – NDA Drive (chủ dự án: anh Đức Anh)

## Giao tiếp
- Trả lời **tiếng Việt**, ngắn, dễ hiểu cho người không chuyên. Kết quả trước, giải thích sau.
- Không hỏi lại điều đã có trong `TIEP-TUC.md`. Chỉ hỏi khi thiếu dữ liệu mà chỉ chủ dự án có.

## Tiết kiệm token (bắt buộc)
1. **Đọc `TIEP-TUC.md` trước**, không đọc lại cả kho. Mở tệp bằng `grep -n` / `sed -n 'a,bp'` đúng đoạn cần sửa.
2. Sửa nhiều chỗ: 1 lệnh `python3` thay chuỗi có `assert` (đọc tệp → thay → ghi). **Không bao giờ** `open(p,'w')` trước khi đọc xong (đã làm mất trắng tệp 2 lần).
3. Không chụp màn hình / in log dài nếu không cần; lọc bằng `tail`, `grep`.
4. Chờ CI bằng **một** lệnh `until …; do sleep 20; done` (không chuỗi `sleep`, không hỏi lặp).
5. Rà soát lớn → giao 1 trợ lý (Agent) chạy nền, mình làm việc khác.
6. Báo cáo .zip chủ dự án gửi: giải nén vào scratchpad, đọc `bao-cao.json` bằng `python3 -c` lấy đúng khoá cần; CSV chuyến đi dùng `tools/analyze_trip.py`.

## Quy trình phát hành (mỗi đợt sửa)
1. `./test/run_tests.sh` phải **ĐẠT** (có bài sức chịu đựng 15 tiếng × 11 xe).
2. Sửa web → `CC=clang-18 web/build-web.sh` (sinh `repo-static/drive.html`), thử bằng Playwright (Chromium có sẵn).
3. Tăng phiên bản: `app/Resources/Info.plist` (Short + build) + `control`; Android `android/app/build.gradle` (versionCode/Name) nếu đụng Android hoặc lõi C; web `APP_VER` trong `web/app.html`.
4. Commit (cuối thông điệp 2 dòng ghi công bên dưới) → `git push origin main` → chờ CI → tải `.deb`/`.apk` từ release kiểm tra → gửi tệp + giải thích ngắn.
5. CI hỏng vì mạng (apt, api.github.com) → chạy lại (`rerun_workflow_run`), không sửa mã.

Ghi công commit:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: <đường dẫn phiên hiện tại>
```
Không ghi tên mô hình trong commit/mã. Không tạo PR nếu không được yêu cầu.

## Ranh giới (giữ nguyên)
- Không video khi lái; không tweak/nguồn crack; không bản ghi tiếng pô có bản quyền (chỉ tổng hợp); không chép icon Apple.
- Thu thập dữ liệu: chỉ khi người dùng bật, ẩn danh, **không toạ độ GPS, tên, số điện thoại**; không lưu âm thanh micro.
- Không đưa khoá ký / mật khẩu vào kho công khai (khoá Android nằm trong cache CI).
- Không xâm nhập mạng/thiết bị của người khác; captive portal chỉ trên router mình quản lý hoặc được chủ mạng đồng ý.
- Dữ liệu khách hàng/giao dịch ở App ndarealty (kho riêng `anhnhadat999/ndarealty`, có CLAUDE.md riêng), không chép ra Drive/router.
