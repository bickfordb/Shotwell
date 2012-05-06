#import "app/AppDelegate.h"
#import "app/Log.h"
#import "app/NSNumberTimeFormat.h"
#import "app/Pthread.h"
#import "app/Search.h"
#import "app/SortField.h"
#import "app/Track.h"
#import "app/TrackBrowser.h"

static NSString * const kStatus = @"status";


@implementation TrackBrowser 
@synthesize emptyImage = emptyImage_;
@synthesize font = font_;
@synthesize playImage = playImage_;
@synthesize playingFont = playingFont_;
@synthesize tracks = tracks_;
@synthesize library = library_;

- (void)delete:(id)sender { 
  NSIndexSet *indices = self.tableView.selectedRowIndexes;
  [self.tableView deselectAll:self];
  ForkWith(^{
    [self cutTracksAtIndices:indices];  
  });

}

- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices { 
  NSArray *tracks = [self.tracks getMany:indices];
  for (Track *o in tracks) {
    [self.library delete:o];
  }
  return tracks;
}

- (void)copy:(id)sender { 
  NSIndexSet *indices = self.tableView.selectedRowIndexes;
  ForkWith(^{ 
    NSUInteger i = indices.lastIndex;
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    for (Track *t in [self.tracks getMany:indices]) {
      NSURL *url = [NSURL fileURLWithPath:t.url];
      [urls addObject:url];
    }
    [pb writeObjects:urls];
  });
}

- (void)cut:(id)sender { 
  NSIndexSet *indices = self.tableView.selectedRowIndexes;
  [self.tableView deselectAll:self];
  ForkWith(^{
    NSUInteger i = [indices lastIndex];
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    NSArray *tracks = [self cutTracksAtIndices:indices];
    NSArray *paths = [tracks valueForKey:kURL];
    for (NSString *i in paths) {
      [urls addObject:[NSURL fileURLWithPath:i]];
    }
    [pb writeObjects:urls];
  });
}



- (NSComparator)comparatorForKey:(NSString *)key { 
  if (key == kDuration || key == kID)
    return DefaultComparison;
  else
    return NaturalComparison;   
}

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  ForkWith(^{
    self.tracks.predicate = ParseSearchQuery(term);
    [self reload];
    if (after)
      after();
  });
}

- (id)initWithLibrary:(Library *)library {
  self = [super init];
  if (self) {
    self.library = library;
    self.tracks = [[[SortedSeq alloc] init] autorelease];
    
    TrackBrowser *weakSelf = self;
    self.onCellValue = ^(int rowIndex, NSTableColumn *aTableColumn) {
      Track *t = [weakSelf.tracks get:rowIndex];
      AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
      NSString *identifier = aTableColumn.identifier;
      id ret = nil;
      bool isPlaying = SharedAppDelegate().track && [t.url isEqual:SharedAppDelegate().track.url];
      if (isPlaying) {
        [[aTableColumn dataCell] setFont:isPlaying ? playingFont_ : font_];
      }
      if (identifier == kDuration) {
        ret = [((NSNumber *)[t valueForKey:kDuration]) formatSeconds];
      } else if (identifier == kStatus) {
        if (isPlaying) {
          ret = playImage_;
          [[aTableColumn dataCell] setImageScaling:0.5];
        }
      } else if (identifier == kArtist
          || identifier == kAlbum
          || identifier == kGenre
          || identifier == kURL 
          || identifier == kTitle
          || identifier == kYear
          || identifier == kTrackNumber) {
        ret = [t valueForKey:identifier];
      }
      return ret;
    };
    self.font = [NSFont systemFontOfSize:11.0];
    self.playingFont = [NSFont boldSystemFontOfSize:11.0];
    self.tableView.onKeyDown = ^(NSEvent *e) {
      if (e.keyCode == 49) {
        [SharedAppDelegate() playClicked:nil];
        return false;
      }
      return true;
    };
    NSMenu *tableMenu = [[[NSMenu alloc] initWithTitle:@"Track Menu"] autorelease];
    NSMenuItem *copy = [tableMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    NSMenuItem *cut = [tableMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"c"];
    NSMenuItem *delete_ = [tableMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    self.tableView.menu = tableMenu;


    NSTableColumn *statusColumn = [[[NSTableColumn alloc] initWithIdentifier:kStatus] autorelease];
    NSTableColumn *artistColumn = [[[NSTableColumn alloc] initWithIdentifier:kArtist] autorelease];
    NSTableColumn *albumColumn = [[[NSTableColumn alloc] initWithIdentifier:kAlbum] autorelease];
    NSTableColumn *titleColumn = [[[NSTableColumn alloc] initWithIdentifier:kTitle] autorelease];
    NSTableColumn *trackNumberColumn = [[[NSTableColumn alloc] initWithIdentifier:kTrackNumber] autorelease];
    NSTableColumn *genreColumn = [[[NSTableColumn alloc] initWithIdentifier:kGenre] autorelease];
    NSTableColumn *durationColumn = [[[NSTableColumn alloc] initWithIdentifier:kDuration] autorelease];
    NSTableColumn *yearColumn = [[[NSTableColumn alloc] initWithIdentifier:kYear] autorelease];
    NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kURL] autorelease];

    self.emptyImage = [[[NSImage alloc] initWithSize:NSMakeSize(22, 22)] autorelease];
    self.playImage = [NSImage imageNamed:@"dot"];
    [statusColumn setDataCell:[[[NSImageCell alloc] initImageCell:emptyImage_] autorelease]];
    [statusColumn setWidth:30];
    [statusColumn setMaxWidth:30];
    [artistColumn setWidth:180];
    [albumColumn setWidth:180];
    [titleColumn setWidth:252];
    [trackNumberColumn setWidth:50];
    [genreColumn setWidth:150];
    [yearColumn setWidth:50];
    [durationColumn setWidth:50];
    [pathColumn setWidth:1000];

    [[statusColumn headerCell] setStringValue:@""];
    [[artistColumn headerCell] setStringValue:@"Artist"];
    [[artistColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[albumColumn headerCell] setStringValue:@"Album"];
    [[albumColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[titleColumn headerCell] setStringValue:@"Title"];
    [[titleColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[yearColumn headerCell] setStringValue:@"Year"];
    [[yearColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[genreColumn headerCell] setStringValue:@"Genre"];
    [[genreColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[durationColumn headerCell] setStringValue:@"Duration"];
    [[durationColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[trackNumberColumn headerCell] setStringValue:@"#"];
    [[trackNumberColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    [[pathColumn headerCell] setStringValue:@"URL"];
    [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];

    [[artistColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[albumColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[titleColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[genreColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[durationColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[yearColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[trackNumberColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];

    [self.tableView addTableColumn:statusColumn];
    [self.tableView addTableColumn:trackNumberColumn];
    [self.tableView addTableColumn:titleColumn];
    [self.tableView addTableColumn:artistColumn];
    [self.tableView addTableColumn:albumColumn];
    [self.tableView addTableColumn:yearColumn];
    [self.tableView addTableColumn:durationColumn];
    [self.tableView addTableColumn:genreColumn];
    [self.tableView addTableColumn:pathColumn];
    // embed the table view in the scroll view, and add the scroll view
    // to our window.

    self.onDoubleAction = ^(int row){
      [SharedAppDelegate() playTrackAtIndex:row];
    };
    for (NSString *key in [NSArray arrayWithObjects:kArtist, kAlbum, kTrackNumber, kTitle, kURL, nil]) { 
      SortField *s = [[[SortField alloc] initWithKey:key direction:Ascending comparator:NaturalComparison] autorelease];
      [self.sortFields addObject:s];
    }
    self.onSortComparatorChanged = ^{ 
      weakSelf.tracks.comparator = weakSelf.sortComparator;
      [weakSelf reload];
    };
    [self updateTableColumnHeaders];
    self.tracks.comparator = self.sortComparator;
    self.onCellValue = ^(int row, NSTableColumn *tableColumn) {
      Track *t = [weakSelf.tracks get:row];
      NSString *ident = tableColumn.identifier;
      bool isPlaying = [SharedAppDelegate().track isEqual:t];
      if (ident != kStatus) {
        id ret = [t valueForKey:ident];
        if (ident == kDuration) {
          ret = [ret formatSeconds];
        }
        [[tableColumn dataCell] setFont:isPlaying ? playingFont_ : font_];
        return ret;
      } else {
        return isPlaying ? playImage_ : emptyImage_;  
      }
    };
    self.onRowCount = ^{ 
      return weakSelf.tracks.count;
    };
    
    ForkWith(^{
      [self.library each:^(Track *t) {
        [self.tracks add:t]; 
      }];
      [self reload];
    });
    [[NSNotificationCenter defaultCenter] 
      addObserver:self
      selector:@selector(onTrackChange:)
      name:kLibraryTrackChanged
      object:library_];
  }
  return self;
}

- (void)onTrackChange:(NSNotification *)notification {
  NSString *change = [notification.userInfo valueForKey:@"change"];
  Track *t = [notification.userInfo valueForKey:@"track"];
  if (change == kLibraryTrackAdded) {
    [self.tracks add:t];
  } else if (change == kLibraryTrackDeleted) {
    [self.tracks remove:t];
  } else if (change == kLibraryTrackChanged) {
    [self.tracks remove:t];
    [self.tracks add:t];
  }
  [self reload];
}

- (void)dealloc { 
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [library_ release];
  [playingFont_ release];
  [font_ release];
  [emptyImage_ release];
  [playImage_ release];
  [tracks_ release];
  [super dealloc];
}
@end
