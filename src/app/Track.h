#import <Cocoa/Cocoa.h>

/* Track keys */
extern NSString * const kAlbum;
extern NSString * const kArtist;
extern NSString * const kCoverArtURL;
extern NSString * const kCreatedAt;
extern NSString * const kDuration;
extern NSString * const kFolder;
extern NSString * const kGenre;
extern NSString * const kID;
extern NSString * const kIsAudio;
extern NSString * const kIsVideo;
extern NSString * const kLastPlayedAt;
extern NSString * const kPublisher;
extern NSString * const kTitle;
extern NSString * const kTrackNumber;
extern NSString * const kURL;
extern NSString * const kUpdatedAt;
extern NSString * const kYear;
extern NSArray *allTrackKeys;

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
  NSString *coverArtURL_;
  NSString *folder_;
  NSString *genre_;
  NSString *publisher_;
  NSString *title_;
  NSString *trackNumber_;
  NSURL *url_;
  NSString *year_;
  NSNumber *isCoverArtChecked_;
  long long int idCache_;
}

- (bool)isAudioOrVideo;

/* Read the ID3 tag stored at URL */
- (int)readTag;

@property (retain) NSString *album;
@property (retain) NSString *folder;
@property (retain) NSString *artist;
@property (retain) NSString *coverArtURL;
@property (retain) NSString *genre;
@property (retain) NSString *title;
@property (retain) NSString *publisher;
@property (retain) NSString *trackNumber;
@property (retain) NSURL *url;
@property (retain) NSString *year;
@property (retain) NSNumber *isVideo;
@property (retain) NSNumber *isCoverArtChecked;
@property (retain) NSNumber *isAudio;
@property (retain) NSNumber *createdAt;
@property (retain) NSNumber *duration;
@property (retain) NSNumber *id;
@property (retain) NSNumber *lastPlayedAt;
@property (retain) NSNumber *updatedAt;

+ (Track *)fromJSON:(NSDictionary *)json;

@end
 
// vim: filetype=objcpp
