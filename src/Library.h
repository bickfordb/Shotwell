#import <Cocoa/Cocoa.h>

@class Library;
typedef void (^OnTrackChange)(Library *, NSMutableDictionary *t);


extern NSString * const kLibraryTrackChanged;
extern NSString * const kLibraryTrackSaved;
extern NSString * const kLibraryTrackAdded;
extern NSString * const kLibraryTrackDeleted;

@interface Library : NSObject {
  NSDate *lastUpdatedAt_;
}
- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)o forKeyedSubscript:(id)key;
- (int)count;
- (void)each:(void (^)(NSMutableDictionary *))block;
- (void)notifyTrack:(NSMutableDictionary *)t change:(NSString *)change;
- (void)scan:(NSArray *)paths;
@property (retain) NSDate *lastUpdatedAt;
@end
// vim: filetype=objcpp
