#import <Cocoa/Cocoa.h>

@protocol LibraryDelegate 
- (void)trackAdded:(NSDictionary *)t;
- (void)trackRemoved:(NSDictionary *)t;
- (void)trackSaved:(NSDictionary *)t;
@end

typedef void (^DictionaryFtor)(NSDictionary *d);

@interface Library : NSObject {
  id <LibraryDelegate> delegate_;
  int64_t lastUpdatedAt_;
}

- (void)each:(DictionaryFtor)f; 
- (int)count;
@property int64_t lastUpdatedAt;
@property (assign, atomic) id <LibraryDelegate> delegate;
@end
// vim: filetype=objcpp
