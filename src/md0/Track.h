#import <Cocoa/Cocoa.h>

/* Track keys */
extern NSString * const kAlbum;
extern NSString * const kArtist;
extern NSString * const kCoverArtURL;
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
  NSString *genre_;
  NSString *publisher_;
  NSString *title_;
  NSString *trackNumber_;
  NSString *url_;
  NSString *year_;
}

- (bool)isAudioOrVideo;

/* Read the ID3 tag stored at URL */
- (int)readTag;

@property (retain, atomic) NSString *album;
@property (retain, atomic) NSString *artist;
@property (retain, atomic) NSString *coverArtURL;
@property (retain, atomic) NSString *genre;
@property (retain, atomic) NSString *title;
@property (retain, atomic) NSString *publisher;
@property (retain, atomic) NSString *trackNumber;
@property (retain, atomic) NSString *url;
@property (retain, atomic) NSString *year;
@property (retain, atomic) NSNumber *isVideo;
@property (retain, atomic) NSNumber *isAudio;
@property (retain, atomic) NSNumber *createdAt;
@property (retain, atomic) NSNumber *duration;
@property (retain, atomic) NSNumber *id;
@property (retain, atomic) NSNumber *lastPlayedAt;
@property (retain, atomic) NSNumber *updatedAt;
- (bool)isLocalMediaURL;
@end
 
// vim: filetype=objcpp
