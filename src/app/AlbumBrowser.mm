#import <QuartzCore/CoreImage.h>
#import "app/AppDelegate.h"
#import "app/AlbumBrowser.h"
#import "app/Log.h"
#import "app/Pthread.h"
#import "app/Search.h"
#import "app/Sort.h"
#import "app/Track.h"

static NSString * const kTotal = @"total";
static NSImage *blankImage = nil; 

typedef void (^Action)(void);

@interface AlbumBrowserItem : NSObject {  
  NSMutableSet *tracks_;
  NSString *folder_;
}

@property (retain) NSString *folder;
@property (retain) NSMutableSet *tracks;

// IKImageBrowserItem protocol:
- (NSString *)imageUID;
- (NSUInteger)imageVersion;
- (NSString *)imageTitle;
- (NSString *)imageSubtitle;
- (NSString *)imageRepresentationType;
- (id)imageRepresentation;
- (BOOL)isSelectable;
@end

@implementation AlbumBrowserItem 
@synthesize tracks = tracks_;
@synthesize folder = folder_;

+ (void)initialize { 
  blankImage = [NSImage imageNamed:@"album"];
}
 
- (NSString *)imageUID {
  return folder_;
}

- (NSUInteger)imageVersion {
  return 0;
}

- (NSString *)imageTitle {
  @synchronized(tracks_) { 
    NSString *artist = nil;
    NSString *album = nil;
    NSString *title = nil;
    for (Track *t in tracks_) { 
      if (!artist) {
        artist = t.artist;
      } else if (t.artist && ![t.artist isEqual:artist]) {
        artist = @"Various Artists";
      }
      if (!album) {
        album = t.album;
      } else if (t.album && ![t.album isEqual:album]) {
        album = @"Various Albums";
      }
      title = t.title;
    }
    if (album && artist) {
      return [NSString stringWithFormat:@"%@ - %@", artist, album];
    } else if (album) {
      return album;
    } else if (artist) {
      return artist;
    } else if (title) { 
      return title;
    } else { 
      return [[[tracks_ anyObject] url] absoluteString];
    }
  }
}

- (NSString *)imageSubtitle { 
  for (Track *t in self.tracks) {
    return t.year;
  }
  return nil;
}

- (NSString *)imageRepresentationType {
  return IKImageBrowserNSImageRepresentationType;  
}

- (id)imageRepresentation {
  for (Track *t in self.tracks) {
    if (t.coverArtID) {
      return [[[NSImage alloc] initWithContentsOfURL:t.coverArtURL] autorelease];
    }
  }
  return blankImage;
}

- (BOOL)isSelectable { 
  return YES;
}

- (id)init {
  self = [super init];
  if (self) {
    self.tracks = [NSMutableSet set];
    self.folder = @"";
  }
  return self;
}

- (void)dealloc { 
  [tracks_ release];
  [folder_ release];
  [super dealloc];
}
@end

@interface AlbumBrowser (Private)
- (void)addTracks:(NSArray *)t;
- (void)removeTrack:(Track *)t;
@end

@implementation AlbumBrowser 
@synthesize items = items_;
@synthesize titleToItem = titleToItem_;
@synthesize library = library_;
@synthesize scrollView = scrollView_;
@synthesize browserView = browserView_;

- (id)initWithLibrary:(Library *)library { 
  self = [super init];
  if (self) {
    self.items = [[[SortedSeq alloc] init] autorelease];
    self.items.comparator = ^(id left, id right) { 
      return NaturalComparison([left imageTitle], [right imageTitle]);
    };
    self.library = library;
    [[NSNotificationCenter defaultCenter]
     addObserver:self 
     selector:@selector(onTrackChange:)
     name:kLibraryTrackChanged
     object:self.library];
    self.scrollView = [[[NSScrollView alloc] initWithFrame:self.view.frame] autorelease];
    self.browserView = [[[IKImageBrowserView alloc] initWithFrame:self.scrollView.frame] autorelease];
    self.browserView.canControlQuickLookPanel = YES;

    self.scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    self.browserView.autoresizingMask = (NSViewMinXMargin |
        NSViewWidthSizable | NSViewMaxXMargin | NSViewMinYMargin |
        NSViewHeightSizable | NSViewMaxYMargin);
    self.browserView.cellsStyleMask = IKCellsStyleTitled | IKCellsStyleSubtitled;
    self.browserView.cellSize = CGSizeMake(225, 225);
    self.browserView.animates = YES;
    self.browserView.delegate = self;
    self.browserView.intercellSpacing = CGSizeMake(7, 7);
    self.scrollView.focusRingType = NSFocusRingTypeNone;
    self.scrollView.frame = self.view.frame;
    self.scrollView.documentView = self.browserView;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.hasVerticalScroller = YES;
    [self.view addSubview:self.scrollView];
    self.titleToItem = [NSMutableDictionary dictionary];
    self.isBusy = true;
    ForkWith(^{ 
      NSMutableArray *seq = [NSMutableArray array];
      [self.library each:^(Track *t) { 
        [seq addObject:t];
      }];
      [self addTracks:seq];
      ForkToMainWith(^{
        [self.browserView bind:@"content" toObject:items_ withKeyPath:@"arrangedObjects" options:nil];
      });
      self.isBusy = false;
    });
  }
  return self;
}

- (void)removeTrack:(Track *)t {
  AlbumBrowserItem *item = nil;
  NSString *key = t.path.stringByDeletingLastPathComponent;
  if (!key) {
    return;
  }
  @synchronized(titleToItem_) {
    item = [titleToItem_ objectForKey:key];      
  }
  if (!item) {
    return; 
  }
  @synchronized(item.tracks) {
    [item.tracks removeObject:t];
  }
  if (item.tracks.count == 0) {
    @synchronized(titleToItem_) {
      [titleToItem_ removeObjectForKey:key];
    }
    ForkToMainWith(^{
      [items_ removeObject:item];
    });
  }
}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasDoubleClickedAtIndex:(NSUInteger)index {
  NSArray *items = self.items.array;
  if (index < items.count) {
    AlbumBrowserItem *item = [self.items get:index];
    for (Track *t in item.tracks) {
      NSMutableArray *terms = [NSMutableArray array];
      if (t.artist && t.artist.length) 
        [terms addObject:t.artist];
      if (t.album && t.album.length) 
        [terms addObject:t.album];
      NSString *term = [terms componentsJoinedByString:@" "];
      // make this nicer.
      [SharedAppDelegate().mainWindowController selectBrowser:MainWindowControllerTrackBrowser];
      [SharedAppDelegate() search:term after:^{
        [SharedAppDelegate() playTrackAtIndex:0];
      }];
      break;
    }
  }
}


- (void)addTracks:(NSArray *)tracks { 
  for (Track *track in tracks) {
    AlbumBrowserItem *item = nil;
    NSString *key = track.path.stringByDeletingLastPathComponent;
    if (!key) {
      continue;
    }
    @synchronized(titleToItem_) {
      item = [titleToItem_ objectForKey:key];      
    }
    bool isNew = false;
    NSString *oldTitle;
    if (!item) {
      isNew = true;
      item = [[[AlbumBrowserItem alloc] init] autorelease];
      item.folder = key;
      @synchronized(titleToItem_) {
        [titleToItem_ setObject:item forKey:key];
      }
      isNew = true;
    } else { 
      oldTitle = item.imageTitle;
    }
    @synchronized(item.tracks) {
      [item.tracks addObject:track];
    }
    if (isNew) { 
      [self.items add:item];
    } else if (![item.imageTitle isEqualToString:oldTitle]) {
      [self.items remove:item];
      [self.items add:item];
    }
  }
}

- (void)dealloc { 
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self.browserView unbind:@"content"];
  [library_ release];
  [browserView_ release];
  [scrollView_ release];
  [items_ release];
  [titleToItem_ release];
  [super dealloc];
}

- (void)onTrackChange:(NSNotification *)notification {
  Track *t = [notification.userInfo valueForKey:@"track"];
  NSString *change = [notification.userInfo valueForKey:@"change"];

  @synchronized(items_) { 
    if (change == kLibraryTrackDeleted) {
      [self removeTrack:t];
    } else if (change == kLibraryTrackAdded) {
      [self addTracks:[NSArray arrayWithObjects:t, nil]];
    } else if (change == kLibraryTrackSaved) {
      [self removeTrack:t];
      [self addTracks:[NSArray arrayWithObjects:t, nil]];
    }
  }
}

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  ForkWith(^{
    NSPredicate *predicate = ParseSearchQuery(term);
    NSPredicate *albumPredicate = predicate ? [NSPredicate predicateWithBlock:Block_copy(^(id item, NSDictionary *opts) {
      NSSet *tracks = [item valueForKey:@"tracks"];
      for (id t in tracks) {
        if ([predicate evaluateWithObject:t]) {
          return YES;
        }
      }
      return NO;
    })] : nil;
    self.items.predicate = albumPredicate;
    if (after)
      after();
  });
}
@end
