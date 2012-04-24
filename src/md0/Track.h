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

@property (retain, nonatomic) NSString *album;
@property (retain, nonatomic) NSString *artist;
@property (retain, nonatomic) NSString *coverArtURL;
@property (retain, nonatomic) NSString *genre;
@property (retain, nonatomic) NSString *title;
@property (retain, nonatomic) NSString *publisher;
@property (retain, nonatomic) NSString *trackNumber;
@property (retain, nonatomic) NSString *url;
@property (retain, nonatomic) NSString *year;
@property (retain, nonatomic) NSNumber *isVideo;
@property (retain, nonatomic) NSNumber *isAudio;
@property (retain, nonatomic) NSNumber *createdAt;
@property (retain, nonatomic) NSNumber *duration;
@property (retain, nonatomic) NSNumber *id;
@property (retain, nonatomic) NSNumber *lastPlayedAt;
@property (retain, nonatomic) NSNumber *updatedAt;
- (bool)isLocalMediaURL;
@end
 
// vim: filetype=objcpp
