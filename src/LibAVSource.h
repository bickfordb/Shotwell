// libav based AudioSource
#import <Cocoa/Cocoa.h>
#import "AudioSource.h"

@interface LibAVSource : NSObject <AudioSource>
- (id)initWithURL:(NSURL *)s;
- (NSString *)url;
@end
// vim: filetype=objcpp
