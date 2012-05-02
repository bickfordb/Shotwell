#import <QuartzCore/CoreImage.h>
#import "app/AppDelegate.h"
#import "app/ArtistBrowser.h"
#import "app/Track.h"

static NSString * const kTotal = @"total";

static NSImage *blankImage = nil; 

@interface ArtistCollectionViewItem : NSCollectionViewItem {
  NSButton *titleView_;
  NSImageView *coverView_;
}
@property (retain) NSButton *titleView;
@property (retain) NSImageView *coverView;
@end

@implementation ArtistCollectionViewItem
@synthesize titleView = titleView_;
@synthesize coverView = coverView_;

+ (void)initialize {
  blankImage = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
  blankImage.backgroundColor = [NSColor blackColor];
  NSLog(@"initialized image: %@", blankImage);
}

- (void)dealloc { 
  [coverView_ release];
  [titleView_ release];
  [super dealloc];
}

- (void)loadView { 
  self.view = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)] autorelease];
  self.view.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  CGRect frame = self.view.frame;
  self.titleView = [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 22)] autorelease];
  self.titleView.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
  self.titleView.stringValue = @"";
  self.titleView.bezelStyle = NSRoundRectBezelStyle;
  self.coverView = [[[NSImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)] autorelease];
  self.coverView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  self.coverView.imageScaling = NSScaleToFit;
  [self.view addSubview:self.coverView];
  [self.view addSubview:self.titleView];
}

- (void)setRepresentedObject:(id)o { 
  [super setRepresentedObject:o];
  NSString *artist = [o valueForKey:@"artist"];
  self.titleView.title = artist ? artist : @"";
  [self.titleView sizeToFit];
  CGRect titleFrame = self.titleView.frame;
  titleFrame.origin.x = (self.view.frame.size.width - titleFrame.size.width) / 2.0;
  titleFrame.origin.y = (self.view.frame.size.height - titleFrame.size.height) / 2.0;
  self.titleView.frame = titleFrame;
  NSURL *url = nil;
  for (Track *t in [o valueForKey:@"tracks"]) {
    if (t.coverArtURL) { 
      url = [NSURL URLWithString:t.coverArtURL];
      break;
    }   
  }
  NSImage *image = url ? [[[NSImage alloc] initByReferencingURL:url] autorelease] : blankImage;
  self.coverView.image = image;
}

@end

@implementation ArtistBrowser 
@synthesize collectionView = collectionView_;
@synthesize items = items_;
@synthesize library = library_;
@synthesize scrollView = scrollView_;

- (void)reload { 
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  [self.library each:^(Track *t) {
    if (!t.artist)
      return;
    NSMutableArray *m = [d valueForKey:t.artist];
    if (!m) {
      m = [NSMutableArray array];
      [d setValue:m forKey:t.artist];     
    }
    [m addObject:t];
  }];
  NSMutableArray *items = [NSMutableArray array];
  [d enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) { 
    NSMutableDictionary *i = [NSMutableDictionary dictionary];
    [i setValue:key forKey:@"artist"];
    [i setValue:val forKey:@"tracks"];
    [items addObject:i];
  }];
  [items sortUsingComparator:^(id left, id right) {
    NSString *artistLeft = [left valueForKey:@"artist"];
    NSString *artistRight = [right valueForKey:@"artist"];
    return NaturalComparison(artistLeft, artistRight);
  }];
  self.collectionView.content = items;
}

- (id)initWithLibrary:(Library *)library { 
  self = [super init];
  if (self) {
    self.library = library;
    self.items = [[[SortedSeq alloc] init] autorelease];
    self.scrollView = [[[NSScrollView alloc] initWithFrame:self.view.frame] autorelease];
    self.collectionView = [[[NSCollectionView alloc] initWithFrame:self.scrollView.frame] autorelease];
    self.collectionView.itemPrototype = [[[ArtistCollectionViewItem alloc] initWithNibName:nil bundle:nil] autorelease];
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
    [self reload];
  }
  return self;
}
- (void)dealloc { 
  [library_ release];
  [collectionView_ release];
  [scrollView_ release];
  [items_ release];
  [super dealloc];
}
@end
