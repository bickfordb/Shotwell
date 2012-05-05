#import <QuartzCore/CoreImage.h>
#import "app/AppDelegate.h"
#import "app/AlbumBrowser.h"
#import "app/Log.h"
#import "app/Pthread.h"
#import "app/Search.h"
#import "app/Track.h"

static NSString * const kTotal = @"total";
static NSImage *blankImage = nil; 
static int64_t kReloadInterval = 5 * 1000000;

typedef void (^Action)(void);
 
@interface AlbumView : NSView {
  bool inited_;
  NSString *title_;
  NSURL *url_;
  NSTextField *titleField_;
  NSImageView *cover_; 
  Action onDoubleClick_;
  NSDictionary *item_;
}
@property (copy) Action onDoubleClick;
@property (retain) NSDictionary *item;

@end
@implementation AlbumView
@synthesize onDoubleClick = onDoubleClick_;
@synthesize item = item_;

- (void)dealloc { 
  [onDoubleClick_ release];
  [item_ release];
  [cover_ release];
  [titleField_ release];
  [super dealloc];
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    inited_ = false;
  }
  return self;
}

- (void)drawRect:(NSRect)rect { 
  if (!inited_) {
    CGRect frame = self.frame;
    titleField_ = [[NSTextField alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 28)];
    NSString *title = [item_ valueForKey:@"title"];
    titleField_.stringValue = title ? title : @"";
    titleField_.textColor = [NSColor whiteColor];
    titleField_.editable = NO;
    titleField_.bezeled = NO;
    titleField_.selectable = NO;
    titleField_.backgroundColor = [NSColor clearColor];
    titleField_.alignment = NSCenterTextAlignment;
    titleField_.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    titleField_.font = [NSFont systemFontOfSize:11.0];
    [[titleField_ cell] setBackgroundStyle:NSBackgroundStyleRaised];
    cover_ = [[NSImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
    cover_.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    cover_.imageScaling = NSScaleProportionally;
    NSURL *url = [item_ valueForKey:@"url"];
    cover_.image = url ? [[[NSImage alloc] initByReferencingURL:url] autorelease] : blankImage;
    NSBox *box = [[[NSBox alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 32)] autorelease];
    box.boxType = NSBoxCustom;
    box.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    box.fillColor = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.45];
    box.borderType = NSNoBorder;
    titleField_.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [self addSubview:cover_];
    [self addSubview:box];
    [self addSubview:titleField_];
    inited_ = true;
  }
}

- (void)mouseDown:(NSEvent *)theEvent {
  [super mouseDown:theEvent];
  if (theEvent.clickCount > 1) {
    if (onDoubleClick_) {
      onDoubleClick_();
    }
  }
}
@end

@interface AlbumCollectionViewItem : NSCollectionViewItem {
  NSBox *selectionBox_;
}
@property (retain) NSBox *selectionBox;
@end

@implementation AlbumCollectionViewItem
@synthesize selectionBox = selectionBox_;

+ (void)initialize {
  blankImage = [NSImage imageNamed:@"album"];
}

- (void)dealloc { 
  [selectionBox_ release];
  [super dealloc];
}

- (void)loadView { 
  self.view = [[[AlbumView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)] autorelease];
  self.view.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  AlbumCollectionViewItem *weakSelf = self;
  ((AlbumView *)self.view).onDoubleClick = ^{
    for (Track *t in [weakSelf.representedObject valueForKey:@"tracks"]) {
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
  };
  self.selectionBox = [[[NSBox alloc] initWithFrame:CGRectMake(0, 0, 200, 200)] autorelease];
  self.selectionBox.boxType = NSBoxCustom;
  self.selectionBox.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
  self.selectionBox.fillColor = [NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.10];
  self.selectionBox.borderType = NSNoBorder;
  self.selectionBox.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  self.selectionBox.hidden = !self.isSelected;
  [self.view addSubview:self.selectionBox];
}

- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];
  self.selectionBox.hidden = !selected;
}

- (void)setRepresentedObject:(id)o { 
  [super setRepresentedObject:o];
  ((AlbumView *)self.view).item = (NSDictionary *)o;
}

@end

@implementation AlbumBrowser 
@synthesize collectionView = collectionView_;
@synthesize items = items_;
@synthesize library = library_;
@synthesize scrollView = scrollView_;
@synthesize loop = loop_;
@synthesize predicate = predicate_;

- (void)reload { 
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    NSPredicate *p = [predicate_ retain];
    @synchronized(items_) { 
      for (Track *t in items_) { 
        if (p && ![p evaluateWithObject:t]) 
          continue;
        NSString *key = t.artistAlbumYearTitle;
        if (!key)
          continue;
        NSMutableArray *m = [d valueForKey:key];
        if (!m) {
          m = [NSMutableArray array];
          [d setValue:m forKey:key];     
        }
        [m addObject:t];
      }
    }
    [p release];
    NSMutableArray *items = [NSMutableArray array];
    [d enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) { 
      NSMutableDictionary *i = [NSMutableDictionary dictionary];
      [i setValue:key forKey:@"title"];
      [i setValue:val forKey:@"tracks"];
      for (Track *t in ((NSArray *)val)) {
        if (t.coverArtURL) {
          [i setValue:[NSURL URLWithString:t.coverArtURL] forKey:@"url"];
          break;
        }
      }
      [items addObject:i];
    }];
    [items sortUsingComparator:^(id left, id right) {
      return NaturalComparison([left valueForKey:@"title"], [right valueForKey:@"title"]);
    }];
    ForkToMainWith(^{ 
      self.collectionView.content = items;
    });
}

- (void)checkReload { 
  if (!requestReload_) 
    return;
  requestReload_ = false;
  [self reload];
  self.isBusy = false; 
}

- (id)initWithLibrary:(Library *)library { 
  self = [super init];
  __block AlbumBrowser *weakSelf = self;
  if (self) {
    self.loop = [Loop loop];
    self.items = [NSMutableSet set];
    [self.loop 
      every:kReloadInterval 
      with:^{ 
        [weakSelf checkReload];
      }];
    self.library = library;
    [[NSNotificationCenter defaultCenter]
     addObserver:self 
     selector:@selector(onTrackChange:)
     name:kLibraryTrackChanged
     object:self.library];
    self.scrollView = [[[NSScrollView alloc] initWithFrame:self.view.frame] autorelease];
    self.collectionView = [[[NSCollectionView alloc] initWithFrame:self.scrollView.frame] autorelease];
    self.collectionView.selectable = YES;
    self.collectionView.allowsMultipleSelection = YES;
    self.collectionView.maxItemSize = CGSizeMake(400, 400);
    self.collectionView.minItemSize = CGSizeMake(200, 200);

    self.collectionView.backgroundColors = [NSArray arrayWithObjects:[NSColor blackColor], nil];
    self.collectionView.itemPrototype = [[[AlbumCollectionViewItem alloc] initWithNibName:nil bundle:nil] autorelease];
    self.scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    self.collectionView.autoresizingMask = (NSViewMinXMargin |
        NSViewWidthSizable | NSViewMaxXMargin | NSViewMinYMargin |
        NSViewHeightSizable | NSViewMaxYMargin);
    self.scrollView.focusRingType = NSFocusRingTypeNone;
    CGRect frame = self.view.frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    self.collectionView.frame = frame;
    self.scrollView.frame = frame;
    self.scrollView.documentView = self.collectionView;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.hasVerticalScroller = YES;
    [self.view addSubview:self.scrollView];
    self.isBusy = true;
    ForkWith(^{ 
      [self.library each:^(Track *t) { 
        @synchronized(items_) {
          [items_ addObject:t];
        }
        requestReload_ = true;
      }];
    });
  }
  return self;
}
- (void)dealloc { 
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [loop_ release];
  [library_ release];
  [collectionView_ release];
  [scrollView_ release];
  [items_ release];
  [super dealloc];
}

- (void)onTrackChange:(NSNotification *)notification {
  Track *t = [notification.userInfo valueForKey:@"track"];
  NSString *change = [notification.userInfo valueForKey:@"change"];

  @synchronized(items_) { 
    if (change == kLibraryTrackDeleted) {
      [items_ removeObject:t]; 
    } else if (change == kLibraryTrackAdded) {
      [items_ addObject:t]; 
    }
  }
  self.isBusy = true;
  requestReload_ = true;
}

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  ForkWith(^{
    self.predicate = ParseSearchQuery(term);
    requestReload_ = true;
    self.isBusy = true;
    if (after)
      after();
  });
}
@end
