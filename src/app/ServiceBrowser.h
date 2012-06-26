#import <Cocoa/Cocoa.h>
// vim: filetype=objcpp
//
typedef void (^OnNetService)(NSNetService *netService);

@interface ServiceBrowser : NSNetServiceBrowser <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
  OnNetService onRemoved_;
  OnNetService onAdded_;
}
- (id)initWithType:(NSString *)type onAdded:(OnNetService)onAdded onRemoved:(OnNetService)onRemoved;
@end


