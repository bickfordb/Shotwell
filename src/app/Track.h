#import <Cocoa/Cocoa.h>

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
@interface Track : NSObject {
  NSNumber *createdAt_;
  NSNumber *duration_;
  NSNumber *id_;
  NSNumber *isVideo_;
  NSNumber *isAudio_;
  NSNumber *lastPlayedAt_;
  NSNumber *updatedAt_;
  NSString *album_;
  NSString *artist_;
  NSString *coverArtID_;
  Library *library_;
  NSString *genre_;
  NSString *path_;
  NSString *publisher_;
  NSString *title_;
  NSString *trackNumber_;
  NSString *year_;
  NSNumber *isCoverArtChecked_;
  long long int idCache_;
}

- (bool)isAudioOrVideo;

/* Read the ID3 tag stored at URL */
- (int)readTag;
@property (readonly) NSURL *coverArtURL;
@property (readonly) NSURL *url;
@property (retain) Library *library;
@property (retain) NSNumber *createdAt;
@property (retain) NSNumber *duration;
@property (retain) NSNumber *id;
@property (retain) NSNumber *isAudio;
@property (retain) NSNumber *isCoverArtChecked;
@property (retain) NSNumber *isVideo;
@property (retain) NSNumber *lastPlayedAt;
@property (retain) NSNumber *updatedAt;
@property (retain) NSString *album;
@property (retain) NSString *artist;
@property (retain) NSString *coverArtID;
@property (retain) NSString *genre;
@property (retain) NSString *path;
@property (retain) NSString *publisher;
@property (retain) NSString *title;
@property (retain) NSString *trackNumber;
@property (retain) NSString *year;

+ (Track *)fromJSON:(NSDictionary *)json;

@end

// vim: filetype=objcpp
