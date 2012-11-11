#import <Cocoa/Cocoa.h>
#include "app/pb/Track.pb.h"

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
extern NSString * const kIsCoverArtChecked;
extern NSString * const kIsVideo;
extern NSString * const kLastPlayedAt;
extern NSString * const kPublisher;
extern NSString * const kTitle;
extern NSString * const kTrackNumber;
extern NSString * const kURL;
extern NSString * const kPath;
extern NSString * const kUpdatedAt;
extern NSString * const kYear;
extern NSString * const kAcoustID;
extern NSString * const kIsAcoustIDChecked;
extern NSString * const kTrackStarted;
extern NSString * const kTrackEnded;
extern NSString * const kTrackAdded;
extern NSString * const kTrackDeleted;

@class Library;
@interface Track : NSObject {
  track::Track *message_;
  Library *library_;
}

- (NSDictionary *)dictionary;

/* Read the ID3 tag stored at URL */
- (int)readTag;
@property (copy, nonatomic, readonly) NSURL *url;
@property (retain, nonatomic) Library *library;
@property (copy, nonatomic) NSURL *coverArtURL;
@property (copy) NSString *path;
@property (copy) NSString *artist;
@property (copy) NSString *album;
@property (copy) NSString *genre;
@property (copy) NSString *publisher;
@property (copy) NSString *title;
@property (copy) NSString *trackNumber;
@property (copy) NSString *year;
@property (copy) NSString *coverArtID;
@property uint64_t createdAt;
@property uint64_t duration;
@property uint64_t lastPlayedAt;
@property uint64_t updatedAt;
@property uint64_t id;
@property BOOL isAudio;
@property BOOL isVideo;
@property BOOL isCoverArtChecked;
@property BOOL isAcoustIDChecked;
@property (copy, readonly) NSDictionary *acoustID;

+ (Track *)trackFromDictionary:(NSDictionary *)dict;
- (track::Track *)message;
- (void)refreshAcoustID;
@end

// vim: filetype=objcpp
