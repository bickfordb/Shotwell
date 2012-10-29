#import <Cocoa/Cocoa.h>
#include "app/Messages.pb.h"

// vim: set filetype=objcpp

/* Track keys */
extern NSString * const kAlbum;
extern NSString * const kArtist;
extern NSString * const kCoverArtID;
extern NSString * const kCreatedAt;
extern NSString * const kDuration;
extern NSString * const kGenre;
extern NSString * const kID;
extern NSString * const kIsAudio;
extern NSString * const kIsVideo;
extern NSString * const kLastPlayedAt;
extern NSString * const kPublisher;
extern NSString * const kTitle;
extern NSString * const kTrackNumber;
extern NSString * const kURL;
extern NSString * const kPath;
extern NSString * const kUpdatedAt;
extern NSString * const kYear;
extern NSArray *allTrackKeys;


@class Library;
@interface Track : TrackMessage {
}

- (bool)isAudioOrVideo;
- (NSDictionary *)dictionary;

/* Read the ID3 tag stored at URL */
- (int)readTag;
@property (copy, nonatomic, readonly) NSURL *url;
@property (retain, nonatomic) Library *library;
@property (copy, nonatomic) NSURL *coverArtURL;

+ (Track *)trackFromDictionary:(NSDictionary *)dict;
@end

// vim: filetype=objcpp
