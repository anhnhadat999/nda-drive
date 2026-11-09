#import <Foundation/Foundation.h>

// Nhat ky chan doan: ghi su kien (tat/mo man hinh, GPS, cam bien) vao Documents/ndadrive-log.txt
void PALog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
NSURL *PALogFileURL(void);

// Thu muc du lieu ghi duoc (Documents neu co, neu khong /var/mobile/Library/NDADrive ...)
NSURL *PADataDir(void);
NSURL *PATempDir(void);
