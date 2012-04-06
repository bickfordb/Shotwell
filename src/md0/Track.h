#import <Cocoa/Cocoa.h>

extern NSString * const kID;
extern NSString * const kArtist;
extern NSString * const kAlbum;
extern NSString * const kTitle;
extern NSString * const kGenre;
extern NSString * const kYear;
extern NSString * const kURL;
extern NSString * const kTrackNumber;
extern NSString * const kDuration;
extern NSString * const kLastPlayedAt;
extern NSString * const kIsVideo;
extern NSString * const kUpdatedAt;
extern NSString * const kCreatedAt;
int ReadTag(NSString *, NSMutableDictionary *track);
void Init();
// vim: filetype=objcpp
