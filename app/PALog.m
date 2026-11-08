#import "PALog.h"

NSURL *PALogFileURL(void) {
    NSURL *doc = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [doc URLByAppendingPathComponent:@"ndadrive-log.txt"];
}

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
