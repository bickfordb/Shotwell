#include <stdio.h>
#include <string>
#include <sys/stat.h>

#include <unicode/utypes.h>   /* Basic ICU data types */
#include <unicode/ucnv.h>     /* C   Converter API    */
#include <unicode/ustring.h>  /* some more string fcns*/
#include <unicode/uchar.h>    /* char names           */
#include <unicode/uloc.h>
#include <unicode/unistr.h>
#include <unicode/bytestream.h>

#import "app/JSON.h"
#include <objc/runtime.h>

#import "app/Chromaprint.h"
#import "app/Library.h"
#import "app/Track.h"
#import "app/Log.h"
#import "app/Util.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
}

NSString * const kTrackStarted = @"TrackStarted";
NSString * const kTrackEnded = @"TrackEnded";
NSString * const kTrackAdded = @"TrackAdded";
NSString * const kTrackDeleted = @"TrackDeleted";

#define CopyString(src, sel) { \
  if (src && [src isKindOfClass:[NSString class]]) { sel([((NSString *)src) UTF8String]); } \
}

#define CopyUInt32(src, sel) { \
  if (src && [src isKindOfClass:[NSNumber class]]) { sel([((NSNumber *)src) unsignedIntValue]); } \
}

void CopyArtist(NSDictionary *artist, track::Artist *pb) {
  CopyString(artist[@"id"], pb->set_id);
  CopyString(artist[@"name"], pb->set_name);
}

void CopyTrackInfo(NSDictionary *trackInfo, track::TrackInfo *pb) {
  for (id artist in trackInfo[@"artists"]) {
    CopyArtist(artist, pb->add_artist());
  }
  CopyUInt32(trackInfo[@"position"], pb->set_position);
  CopyString(trackInfo[@"title"], pb->set_title);
}

void CopyMedium(NSDictionary *medium, track::Medium *pb) {
  CopyString(medium[@"format"], pb->set_format);
  CopyUInt32(medium[@"position"], pb->set_position);
  CopyUInt32(medium[@"track_count"], pb->set_trackcount);
  for (id track in medium[@"tracks"])
    CopyTrackInfo(track, pb->add_trackinfo());
}

void CopyRelease(NSDictionary *release, track::Release *pb) {
  for (id artist in release[@"artists"])
    CopyArtist(artist, pb->add_artist());
  CopyString(release[@"country"], pb->set_country);
  CopyUInt32(release[@"date"][@"day"], pb->mutable_date()->set_day);
  CopyUInt32(release[@"date"][@"month"], pb->mutable_date()->set_month);
  CopyUInt32(release[@"date"][@"year"], pb->mutable_date()->set_year);
  CopyString(release[@"id"], pb->set_id);
  CopyUInt32(release[@"medium_count"], pb->set_mediumcount);
  for (id i in release[@"mediums"]) {
    CopyMedium(i, pb->add_medium());
  }
  CopyString(release[@"title"], pb->set_title);
  CopyUInt32(release[@"track_count"], pb->set_trackcount);
}

void CopyReleaseGroup(NSDictionary *rg, track::ReleaseGroup *pb) {
  CopyString(rg[@"type"], pb->set_type);
  CopyString(rg[@"id"], pb->set_id);
  CopyString(rg[@"title"], pb->set_title);
  for (id artist in rg[@"artists"])
    CopyArtist(artist, pb->add_artist());
  for (id release in rg[@"releases"])
    CopyRelease(release, pb->add_release());
}

void CopyRecording(NSDictionary *recording, track::Recording *pb) {
  CopyUInt32(recording[@"duration"], pb->set_duration);
  for (id i in recording[@"releasegroups"])
    CopyReleaseGroup(i, pb->add_releasegroup());
  CopyString(recording[@"title"], pb->set_title);
  CopyString(recording[@"id"], pb->set_id);
  for (id artist in recording[@"artists"])
    CopyArtist(artist, pb->add_artist());
  CopyUInt32(recording[@"sources"], pb->set_sources);
}

void CopyAcoustID(NSDictionary *acoustID, track::AcoustID *pb) {
  CopyString(acoustID[@"id"], pb->set_id);
  if (acoustID[@"score"])
    pb->set_score([acoustID[@"score"] doubleValue]);
  for (id i in acoustID[@"recordings"])
    CopyRecording(i, pb->add_recording());
}

static Class trackClass;

static NSString *ToUTF8(const char *src) {
  UErrorCode err = U_ZERO_ERROR;
  int32_t sig_len = 0;
  const char *src_encoding = ucnv_detectUnicodeSignature(src, strlen(src), &sig_len, &err);
  if (err) {
    return @"?";
  }
  UnicodeString us(src, strlen(src), src_encoding);
  std::string dst;
  StringByteSink<std::string> sbs(&dst);
  us.toUTF8(sbs);
  return [NSString stringWithUTF8String:dst.c_str()];
}

NSString * const kAcoustID = @"acoustID";
NSString * const kAlbum = @"album";
NSString * const kArtist = @"artist";
NSString * const kCreatedAt = @"createdAt";
NSString * const kCoverArtID = @"coverArtID";
NSString * const kDuration = @"duration";
NSString * const kIsCoverArtChecked = @"isCoverArtChecked";
NSString * const kGenre = @"genre";
NSString * const kID = @"id";
NSString * const kIsAcoustIDChecked = @"isAcoustIDChecked";
NSString * const kIsAudio = @"isAudio";
NSString * const kIsVideo = @"isVideo";
NSString * const kLastPlayedAt = @"lastPlayedAt";
NSString * const kPath = @"path";
NSString * const kPublisher = @"publisher";
NSString * const kTitle = @"title";
NSString * const kTrackNumber = @"trackNumber";
NSString * const kURL = @"url";
NSString * const kUpdatedAt = @"updatedAt";
NSString * const kYear = @"year";

static NSArray *allTrackKeys = @[
    kAcoustID,
    kAlbum,
    kArtist,
    kCoverArtID,
    kCreatedAt,
    kDuration,
    kGenre,
    kID,
    kIsAcoustIDChecked,
    kIsAudio,
    kIsCoverArtChecked,
    kIsVideo,
    kLastPlayedAt,
    kPath,
    kPublisher,
    kTitle,
    kTrackNumber,
    kUpdatedAt,
    kYear];

static NSDictionary *tagKeyToTrackKey = @{
    @"artist": kArtist,
    @"album": kAlbum,
    @"year": kYear,
    @"title": kTitle,
    @"date": kYear,
    @"track": kTrackNumber,
    @"genre": kGenre};

/*
ignoreExtensions: Skip indexing the following extensions to save time since they never have useful info/can be large
*/

static NSArray *ignoreExtensions = @[@".jpg", @".nfo", @".sfv", @".torrent",
               @".m3u", @".diz", @".rtf", @".ds_store", @".txt", @".m3u8", @".htm", @".url",
               @".html", @".atom", @".rss", @".crdownload", @".dmg", @".zip", @".rar",
               @".jpeg", @".part", @".ini", @".", @".log", @".db", @".cue", @".gif", @".png"];

@implementation Track {
}
@synthesize library = library_;

- (NSURL *)url {
  return [library_ urlForTrack:self];
}

- (NSURL *)coverArtURL {
  return [library_ coverArtURLForTrack:self];
}

- (void)dealloc {
  delete ((track::Track *)message_);
  [library_ release];
  [super dealloc];
}

+ (void)initialize {
  trackClass = [Track class];
  av_log_set_level(AV_LOG_QUIET);
  avcodec_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
  ;
}

- (NSString *)description {
  NSMutableString *ret = [NSMutableString string];
  [ret appendString:@"{"];
  int i = 0;
  for (NSString *key in allTrackKeys) {
    if (i != 0) {
      [ret appendString:@", "];
    }
    [ret appendFormat:@"%@: %@", key, [self valueForKeyPath:key]];
    i += 1;
  }
  [ret appendString:@"}"];
  return ret;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  } else if (!other) {
    return NO;
  } else if ((object_getClass(other) == trackClass) || [other isKindOfClass:trackClass]) {
    Track *other0 = (Track *)other;
    return other0->message_->id() == message_->id();
  } else {
    return NO;
  }
}

- (NSUInteger)hash {
  return (NSUInteger)message_->id();
}

- (int)readTag {
  int ret = 0;
  NSString *path = self.path;
  //DEBUG(@"reading tag: %@", path);
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionaryEntry *tag = NULL;
  int audioStreamIndex = -1;

  if (!path || !path.length) {
    ret = -1;
    goto done;
  }

  for (NSString *ext in ignoreExtensions) {
    if ([path hasSuffix:ext]) {
      ret = -10;
      goto done;
    }
  }

  memset(&st, 0, sizeof(st));
  if (!path || stat(path.UTF8String, &st) < 0) {
    ret = -2;
    goto done;
  }
  if (avformat_open_input(&c, path.UTF8String, NULL, NULL) < 0) {
    ret = -3;
    goto done;
  }
  if (avformat_find_stream_info(c, NULL) < 0) {
    ret = -4;
    goto done;
  }

  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audioStreamIndex = i;
      break;
    }
  }

  if (audioStreamIndex >= 0) {
    UInt64 d = ((c->streams[audioStreamIndex]->duration * c->streams[audioStreamIndex]->time_base.num) / c->streams[audioStreamIndex]->time_base.den) * 1000000;
    self.duration = d;
  }
  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
      self.isVideo = YES;
      continue;
    }
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      self.isAudio = YES;
      continue;
    }
  }

  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    NSString *tagKey = [NSString stringWithUTF8String:tag->key];
    INFO(@"metadata key: %@", tagKey);
    NSString *trackKey = [tagKeyToTrackKey objectForKey:tagKey];
    if (trackKey) {
      NSString *value = ToUTF8(tag->value);
      if (value && value.length > 0) {
        [self setValue:value forKey:trackKey];
      }
    }
  }
done:
  if (c)
    avformat_close_input(&c);
  if (c)
    avformat_free_context(c);
  //DEBUG(@"read tag result: %d", (int)ret);
  return ret;
}

- (bool)isAudioOrVideo {
  return self.isAudio || self.isVideo;
}

- (NSDictionary *)dictionary {
  NSMutableDictionary *data = [NSMutableDictionary dictionary];
  for (NSString *key in allTrackKeys) {
    if (key == kURL)
      continue;
    id val = [self valueForKey:key];
    if (!val)
      continue;
    [data setValue:val forKey:key];
  }
  return data;
}

+ (Track *)trackFromDictionary:(NSDictionary *)dict {
  if (!dict)
    return nil;
  Track *t = [[[Track alloc] init] autorelease];
  t.album = [dict objectForKey:kAlbum];
  t.artist = [dict objectForKey:kArtist];
  t.coverArtID = [dict objectForKey:kCoverArtID];
  t.duration = [[dict objectForKey:kDuration] unsignedLongLongValue];
  t.genre = [dict objectForKey:kGenre];
  t.id = [[dict objectForKey:kID] unsignedLongLongValue];
  t.isAudio = [[dict objectForKey:kIsAudio] boolValue];
  t.isCoverArtChecked = [[dict objectForKey:kIsCoverArtChecked] boolValue];
  t.isVideo = [[dict objectForKey:kIsVideo] boolValue];
  t.lastPlayedAt = [[dict objectForKey:kLastPlayedAt] unsignedLongLongValue];
  t.path = [dict objectForKey:kPath];
  t.publisher = [dict objectForKey:kPublisher];
  t.title = [dict objectForKey:kTitle];
  t.trackNumber = [dict objectForKey:kTrackNumber];
  t.updatedAt = [[dict objectForKey:kUpdatedAt] unsignedLongLongValue];
  t.year = [dict objectForKey:kYear];
  return t;
}

+ (NSString *)webScriptNameForKey:(const char *)name {
  return [NSString stringWithUTF8String:name];
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
  return YES;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
  return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
  NSString *s = NSStringFromSelector(aSelector);
  return [s stringByReplacingOccurrencesOfString:@":" withString:@"_"];
}

- (void)finalizeForWebScript {
}

- (id)init {
  self = [super init];
  if (self) {
    message_ = new track::Track();
  }
  return self;
}

- (track::Track *)message {
  return message_;
}

#define DefineStringProperty(PROTOFIELD, OBJCGETTER, OBJCSETTER) \
- (NSString *)OBJCGETTER { \
  if (!message_->has_##PROTOFIELD()) { \
    return nil; \
  } \
  std::string *s = message_->mutable_##PROTOFIELD(); \
  NSString *ret = [[[NSString alloc] initWithBytes:s->c_str() length:s->length() encoding:NSUTF8StringEncoding] autorelease]; \
  return ret; \
} \
\
- (void)OBJCSETTER:(NSString *)value { \
  if (value.length == 0) \
    value = nil; \
  if (!value) { \
    message_->clear_##PROTOFIELD(); \
  } else { \
    const char *buf = [value UTF8String]; \
    message_->set_##PROTOFIELD(buf); \
  } \
}

#define DefineCProperty(TYPE, PROTO, OCGET, OCSET) \
- (TYPE)OCGET { \
  return message_->PROTO(); \
} \
\
- (void)OCSET:(TYPE)v { \
  message_->set_##PROTO(v); \
} \

#define DefineUInt64Property(PROTO, OCGET, OCSET) DefineCProperty(UInt64, PROTO, OCGET, OCSET)
#define DefineBoolProperty(PROTO, OCGET, OCSET) DefineCProperty(BOOL, PROTO, OCGET, OCSET)

DefineStringProperty(album, album, setAlbum)
DefineStringProperty(artist, artist, setArtist)
DefineStringProperty(coverartid, coverArtID, setCoverArtID)
DefineStringProperty(genre, genre, setGenre)
DefineStringProperty(path, path, setPath)
DefineStringProperty(publisher, publisher, setPublisher)
DefineStringProperty(title, title, setTitle)
DefineStringProperty(year, year, setYear)
DefineStringProperty(tracknumber, trackNumber, setTrackNumber)
DefineUInt64Property(id, id, setId)
DefineBoolProperty(isaudio, isAudio, setIsAudio)
DefineBoolProperty(isvideo, isVideo, setIsVideo)
DefineBoolProperty(iscoverartchecked, isCoverArtChecked, setIsCoverArtChecked)
DefineBoolProperty(isacoustidchecked, isAcoustIDChecked, setIsAcoustIDChecked)
DefineUInt64Property(createdat, createdAt, setCreatedAt)
DefineUInt64Property(lastplayedat, lastPlayedAt, setLastPlayedAt)
DefineUInt64Property(updatedat, updatedAt, setUpdatedAt)
DefineUInt64Property(duration, duration, setDuration)

- (void)refreshAcoustID {
  if (true) {
    return;
  }
  DEBUG(@"checking acoustic id for: %@", self.path);
  NSDictionary *acoustID = nil;
  int st = ChromaprintGetAcoustID(nil, self.path, &acoustID, nil);
  if (st) {
    ERROR(@"got acoustid status: %d", st);
  } else {
    DEBUG(@"Got acoust ID: %@", acoustID);
  }
  if (acoustID) {
    CopyAcoustID(acoustID, message_->mutable_acoustid());
    std::string msg = message_->DebugString();
    INFO(@"after parsing: %s", msg.c_str());
  }
}

- (NSDictionary *)acoustID {
  return @{};
}

@end
