// libav based AudioSource
#import <Cocoa/Cocoa.h>

@interface LibAVSource : NSObject
- (id)initWithURL:(NSURL *)s;
- (NSString *)url;
- (NSError *)getAudio:(uint8_t *)stream length:(size_t *)streamLen;
- (int64_t)elapsed;
- (int64_t)duration;
- (void)seek:(int64_t)usecs;
- (bool)isSeeking;
@end
// vim: filetype=objcpp
