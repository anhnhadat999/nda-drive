#import "PALog.h"

// Thu muc du lieu GHI DUOC THAT. App cai qua jailbreak (/var/jb/Applications) duoc iOS tra ve
// duong dan "Containers/Data/Application/..." nhung thu muc do khong ton tai -> moi lan ghi deu loi.
// Thu lan luot va kiem tra bang cach ghi thu mot tep.
static BOOL writable(NSURL *u) {
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *probe = [u URLByAppendingPathComponent:@".probe"];
    BOOL ok = [[NSData dataWithBytes:"1" length:1] writeToURL:probe options:0 error:nil];
    [fm removeItemAtURL:probe error:nil];
    return ok;
}
NSURL *PADataDir(void) {
    static NSURL *dir; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray<NSURL *> *c = [NSMutableArray array];
        NSURL *doc = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        if (doc) [c addObject:doc];
        [c addObject:[NSURL fileURLWithPath:@"/var/mobile/Library/NDADrive" isDirectory:YES]];
        [c addObject:[NSURL fileURLWithPath:@"/var/jb/var/mobile/Library/NDADrive" isDirectory:YES]];
        [c addObject:[NSURL fileURLWithPath:@"/var/mobile/Documents/NDADrive" isDirectory:YES]];
        [c addObject:[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"NDADrive" isDirectory:YES]];
        [c addObject:[NSURL fileURLWithPath:@"/tmp/NDADrive" isDirectory:YES]];
        for (NSURL *u in c) if (writable(u)) { dir = u; break; }
        if (!dir) dir = c.firstObject;
    });
    return dir;
}
NSURL *PATempDir(void) {
    NSURL *t = [PADataDir() URLByAppendingPathComponent:@"tmp" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:t withIntermediateDirectories:YES attributes:nil error:nil];
    return t;
}
NSURL *PALogFileURL(void) { return [PADataDir() URLByAppendingPathComponent:@"ndadrive-log.txt"]; }

void PALog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    static dispatch_queue_t q; static NSDateFormatter *df; static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.ndarealty.ndadrive.log", DISPATCH_QUEUE_SERIAL);
        df = [NSDateFormatter new]; df.dateFormat = @"dd/MM HH:mm:ss.SSS";
    });
    NSDate *now = [NSDate date];
    dispatch_async(q, ^{
        NSURL *u = PALogFileURL();
        NSString *line = [NSString stringWithFormat:@"%@  %@\n", [df stringFromDate:now], msg];
        NSFileManager *fm = NSFileManager.defaultManager;
        NSDictionary *at = [fm attributesOfItemAtPath:u.path error:nil];
        if ([at fileSize] > 400 * 1024) [fm removeItemAtURL:u error:nil];   // giu nhat ky gon nhe
        if (![fm fileExistsAtPath:u.path]) [@"" writeToURL:u atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSFileHandle *h = [NSFileHandle fileHandleForWritingToURL:u error:nil];
        [h seekToEndOfFile];
        [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    });
    NSLog(@"[NDADrive] %@", msg);
}
