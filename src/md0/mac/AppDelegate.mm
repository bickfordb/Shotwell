#include <arpa/inet.h>
#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#include "md0/mac/AppDelegate.h"
#include "md0/mac/Slider.h"
#include "md0/lib/movie.h"
#include "md0/lib/strnatcmp.h"
#include "md0/lib/remote_library.h"

using namespace std;
using namespace std::tr1;
using namespace md0::movie;
using namespace md0;

static const int kLibraryRefreshInterval = 2.0;
static NSSize kStartupSize = {1100, 600};
static NSString *kAlbum = @"album";
static NSString *kArtist = @"artist";
static NSString *kGenre = @"genre";
static NSString *kDuration = @"duration";
static NSString *kMDNSServiceType = @"_md0._tcp.";
static NSString *kRAOPServiceType = @"_raop._tcp.";
static NSString *kNextButton = @"NextButton";
static NSString *kPath = @"path";
static NSString *kPlayButton = @"PlayButton";
static NSString *kPreviousButton = @"PreviousButton";
static NSString *kProgressControl = @"ProgressControl";
static NSString *kSearchControl = @"SearchControl";
static NSString *kStatus = @"status";
static NSString *kTitle = @"title";
static NSString *kDefaultWindowTitle = @"MD0";
static NSString *kTrackNumber = @"track_number";
static NSString *kVolumeControl = @"VolumeControl";
static NSString *kYear = @"year";
static int kBottomEdgeMargin = 25;

static NSString *FormatSeconds(double seconds); 
static NSString * LibraryDir();
static NSString * LibraryPath();
static NSString *GetString(const string &s);
static bool Contains(string &haystack, string &needle);
static bool IsTrackMatchAllTerms(Track *t, vector<string> &terms);
static void HandleMovieEvent(void *ctx, MovieEvent e, void *data);

static NSString *LibraryDir() { 
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory,
      NSUserDomainMask,
      YES);
  NSString *path = [paths objectAtIndex:0];
  path = [path stringByAppendingPathComponent:@"MD0"];
  mkdir(path.UTF8String, 0755);
  return path;
}

static NSString *LibraryPath() {
  return [LibraryDir() stringByAppendingPathComponent:@"library.db"];
}

static NSString *GetString(const string &s) {
  return [NSString stringWithUTF8String:s.c_str()];
}

static NSString *GetWindowTitle(const Track &t);
static NSString *GetWindowTitle(const Track &t) { 
  if (t.title().length() && t.artist().length() && t.album().length())
    return [NSString stringWithFormat:@"%@ - %@ - %@ ", 
      GetString(t.title()),
      GetString(t.artist()),
      GetString(t.album()),
      nil];
  else if (t.title().length())
    return [NSString stringWithFormat:@"%@", GetString(t.title()), nil];
  else
    return [NSString stringWithFormat:@"%@", GetString(t.path()), nil];
}

static bool Contains(const string &haystack, const string &needle) {
  return strcasestr(haystack.c_str(), needle.c_str()) != NULL;
}


static inline int natural_compare(const string &l, const string &r) {
  if (l.length() == 0 && r.length() > 0) 
    return 1;
  else if (l.length() > 0 && r.length() == 0)
    return -1;
  else
    return strnatcasecmp(l.c_str(), r.c_str());
}

static NSString *GetTimeString(int64_t duration)  {
  return FormatSeconds(duration / 1000000.0);
}


struct TrackComparator {
private:
  vector<tuple<NSString *, Direction> > sorts_;
public:
  TrackComparator(const vector<tuple<NSString *, Direction> > &sorts) : sorts_(sorts) {};

  inline bool operator()(const Track &l, const Track &r) {
    int cmp = 0; 
    for (vector<SortField>::iterator i = sorts_.begin(); i < sorts_.end(); i++) {
      tuple<NSString *, Direction> field = *i;
      NSString *key = get<0>(field);
      Direction direction = get<1>(field);
      if (key == kArtist) { 
        cmp = natural_compare(l.artist(), r.artist());
      } else if (key == kAlbum) {
        cmp = natural_compare(l.album(), r.album());
      } else if (key == kTitle) {
        cmp = natural_compare(l.title(), r.title());
      } else if (key == kGenre) {
        cmp = natural_compare(l.genre(), r.genre());
      } else if (key == kYear) {
        cmp = natural_compare(l.year(), r.year());
      } else if (key == kPath) {
        cmp = natural_compare(l.path(), r.path());
      } else if (key == kTrackNumber) {
        cmp = natural_compare(l.track_number(), r.track_number());
      }
      if (direction == Descending)
        cmp = -cmp;
      if (cmp != 0)
        break;
      
    }
    return cmp < 0;
  }
};

static bool IsTrackMatchAllTerms(Track *t, vector<string> &terms) { 
  bool ret = true;
  for (vector<string>::iterator i = terms.begin(); i < terms.end(); i++) {
    string token = *i;
    if (!(Contains(t->artist(), token)
        || Contains(t->album(), token)
        || Contains(t->track_number(), token)
        || Contains(t->year(), token)
        || Contains(t->genre(), token)
        || Contains(t->title(), token)
        || Contains(t->path(), token))) {
      return false;
    }
  }
  return true;
}

static NSString *FormatSeconds(double seconds) { 
  int hours = seconds / (60 * 60);
  seconds -= hours * 60 * 60;
  int minutes = seconds / 60;
  seconds -= minutes * 60;
  if (hours > 0)
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
  else
    return [NSString stringWithFormat:@"%02d:%02d", minutes, (int)seconds];
}

void HandleMovieEvent(void *ctx, Movie *m, MovieEvent e, void *data) { 
  AppDelegate *a = (AppDelegate *)ctx;
  [a handleMovie:m event:e data:data];
}

@implementation AppDelegate
@synthesize searchQuery = searchQuery_;

- (void)dealloc { 
  [contentView_ dealloc];
  [mainWindow_ dealloc];
  [super dealloc];
}

- (void)setupMenu {
  NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
  NSMenuItem *editMenuItem = [mainMenu itemWithTitle:@"Edit"];
  NSMenuItem *formatMenuItem = [mainMenu itemWithTitle:@"Format"];
  NSMenuItem *viewMenuItem = [mainMenu itemWithTitle:@"View"];
  NSMenuItem *fileMenuItem = [mainMenu itemWithTitle:@"File"];
  [mainMenu removeItem:formatMenuItem];
  [mainMenu removeItem:viewMenuItem];
  NSMenu *fileMenu = [fileMenuItem submenu];
  [fileMenu removeAllItems];
  NSMenu *editMenu = [editMenuItem submenu];
  [editMenu removeAllItems];

  selectAllMenuItem_ = [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  selectAllMenuItem_.target = trackTableView_;
  selectNoneMenuItem_ = [editMenu addItemWithTitle:@"Select None" action:@selector(selectNone:) keyEquivalent:@"A"];
  selectNoneMenuItem_.target = trackTableView_;
  addToLibraryMenuItem_ = [fileMenu addItemWithTitle:@"Add to Library" action:@selector(addToLibrary:) keyEquivalent:@"o"];
  addToLibraryMenuItem_.target = self;
  cutMenuItem_ = [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  cutMenuItem_.target = self;
  copyMenuItem_ = [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  copyMenuItem_.target = self;
  deleteMenuItem_ = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", NSBackspaceCharacter]];
  [deleteMenuItem_ setKeyEquivalentModifierMask:0];
  deleteMenuItem_.target = self;
  pasteMenuItem_ = [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  pasteMenuItem_.target = self;
}

- (void)addToLibrary:(id)sender { 
  // Create the File Open Dialog class.
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanChooseDirectories:YES];
  vector<string> paths;
  if ([openPanel runModal] == NSOKButton) {
    for (NSURL *p in [openPanel URLs]) { 
      paths.push_back([[p path] UTF8String]);
    }
  }
  localLibrary_->Scan(paths, false);
}

- (void)delete:(id)sender { 
  if (library_ != localLibrary_)
    return;
  @synchronized(self) { 
    NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
    NSUInteger i = [indices lastIndex];
    while (i != NSNotFound) {
      if (i >= tracks_.size())
        continue;
      needsReload_ = YES;
      Track t = tracks_.at(i);
      tracks_.erase(tracks_.begin() + i);
      localLibrary_->Delete(t.path());
      int n = allTracks_.size();
      for (int j = 0; j < n; j++) {
        if (allTracks_.at(j).path() == t.path()) {
          allTracks_.erase(allTracks_.begin() + j); 
          break;
        }
      }
      i = [indices indexLessThanIndex:i];
    }
  }
}

- (void)paste:(id)sender { 
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  NSArray *items = [pboard readObjectsForClasses:[NSArray arrayWithObjects:[NSURL class], nil]
    options:nil]; 
  vector<string> paths;
  for (NSURL *u in items) {
    if (![u isFileURL]) {
      continue;
    }
    NSString *p = [u path];
    paths.push_back(p.UTF8String);
  }
  localLibrary_->Scan(paths, false);
}

- (void)copy:(id)sender { 
  @synchronized(self) { 
    NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
    NSUInteger i = [indices lastIndex];
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    while (i != NSNotFound) {
      if (i >= tracks_.size())
        continue;
      Track t = tracks_.at(i);
      NSString *path = [NSString stringWithUTF8String:t.path().c_str()];
      NSURL *url = [NSURL fileURLWithPath:path];
      [urls addObject:url];
      i = [indices indexLessThanIndex:i];
      requestClearSelection_ = YES;
    }
    [pb writeObjects:urls];
  }
}

- (void)cut:(id)sender { 
  if (library_ != localLibrary_)
    return;

  @synchronized(self) { 
    NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
    NSUInteger i = [indices lastIndex];
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    while (i != NSNotFound) {
      if (i >= tracks_.size())
        continue;
      needsReload_ = YES;
      Track t = tracks_.at(i);
      NSString *path = [NSString stringWithUTF8String:t.path().c_str()];
      NSURL *url = [NSURL fileURLWithPath:path];
      [urls addObject:url];
      tracks_.erase(tracks_.begin() + i);
      localLibrary_->Delete(t.path());
      int n = allTracks_.size();
      for (int j = 0; j < n; j++) {
        if (allTracks_.at(j).path() == t.path()) {
          allTracks_.erase(allTracks_.begin() + j); 
          break;
        }
      }
      i = [indices indexLessThanIndex:i];
    }
    requestClearSelection_ = YES;
    [pb writeObjects:urls];
  }
}
- (void)setupWindow {
  mainWindow_ = [[NSWindow alloc] 
    initWithContentRect:NSMakeRect(150, 150, kStartupSize.width, kStartupSize.height)
    styleMask:NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask 
    backing:NSBackingStoreBuffered
    defer:YES];
  [mainWindow_ setAutorecalculatesKeyViewLoop:YES];
  [mainWindow_ display];
  [mainWindow_ makeKeyAndOrderFront:self];
  contentView_ = [mainWindow_ contentView];
  contentView_.autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
  contentView_.autoresizesSubviews = YES;
  [mainWindow_ setAutorecalculatesContentBorderThickness:YES forEdge:NSMaxYEdge];
  [mainWindow_ setAutorecalculatesContentBorderThickness:YES forEdge:NSMinYEdge];
  [mainWindow_ setContentBorderThickness:kBottomEdgeMargin forEdge:NSMinYEdge];
  mainWindow_.title = kDefaultWindowTitle;
}

- (void)setupAudioSelect { 
  int w = 160;
  int x = ((NSView *)[mainWindow_ contentView]).bounds.size.width;
  x -= w + 10;
  audioOutputSelect_ = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(x, 3, w, 18)];
  audioOutputSelect_.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  [audioOutputSelect_ setTarget:self];
  [audioOutputSelect_ setAction:@selector(audioOutputSelected:)];
  NSButtonCell *buttonCell = (NSButtonCell *)[audioOutputSelect_ cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];

  [[mainWindow_ contentView] addSubview:audioOutputSelect_];
  [self refreshAudioOutputList];
}

- (void)audioOutputSelected:(id)sender { 
  NSLog(@"selected audio output");
  NSInteger i = [sender indexOfSelectedItem];
  if (i == 0) {
    [self selectLocalAudio];
  } else {
    NSString *s = @"10.0.1.10";
    uint16_t port = 5000;
    [self selectRemoteAudioHost:s port:port];
  }
}
   
- (void)selectLocalAudio {
  md0::movie::Movie::StartSDL();
}

- (void)setupLibrarySelect { 
  int w = 160;
  int x = ((NSView *)[mainWindow_ contentView]).bounds.size.width;
  x -= w + 10;
  librarySelect_ = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(5, 3, w, 18)];
  librarySelect_.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
  NSButtonCell *buttonCell = (NSButtonCell *)[librarySelect_ cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];
  [librarySelect_ setTarget:self];
  [librarySelect_ setAction:@selector(librarySelected:)];
  [[mainWindow_ contentView] addSubview:librarySelect_];
  [self refreshLibraryList];
}

- (void)librarySelected:(id)sender { 
  NSInteger index = [librarySelect_ indexOfSelectedItem];
  if (index < 0) 
    return;
  string name([[librarySelect_ titleOfSelectedItem] UTF8String]);
  @synchronized (self) {
    if (library_ != localLibrary_)
      delete library_;
    if (index == 0) {
      library_ = localLibrary_;
    } else { 
      for (set<Service>::iterator i = services_.begin(); i != services_.end(); i++) {
        if (i->mdns_type() == "_md0._tcp." && i->name() == name) {
          library_ = new RemoteLibrary(i->host(), i->port());
          break;
        }
      }
    }
  }
  needsLibraryRefresh_ = YES;
}

- (void)selectRemoteAudioHost:(NSString *)host port:(uint16_t)port {
  md0::movie::Movie::StartRAOP([host UTF8String], port);
}

- (void)refreshAudioOutputList {
  [audioOutputSelect_ removeAllItems];
  [audioOutputSelect_ addItemWithTitle:@"Local Speakers"];
  set<Service>::iterator i;
  for (i = services_.begin(); i != services_.end(); i++) {
    if (i->mdns_type() == "_raop._tcp.") 
      [audioOutputSelect_ addItemWithTitle:GetString(i->name())];
  }
}

- (void)refreshLibraryList {
  [librarySelect_ removeAllItems];
  [librarySelect_ addItemWithTitle:@"Library"];
  set<Service>::iterator i;
  for (i = services_.begin(); i != services_.end(); i++) {
    if (i->mdns_type() == "_md0._tcp.") 
      [librarySelect_ addItemWithTitle:GetString(i->name())];
  }
}
- (void)setupTrackTable {
  trackTableFont_ = [[NSFont systemFontOfSize:11.0] retain];
  trackTablePlayingFont_ = [[NSFont boldSystemFontOfSize:11.0] retain];

  trackTableScrollView_ = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, kBottomEdgeMargin, 
    contentView_.frame.size.width, contentView_.frame.size.height - kBottomEdgeMargin)];
  trackTableScrollView_.autoresizesSubviews = YES;
  trackTableScrollView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  trackTableView_ = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 364, 200)];
  [trackTableView_ setUsesAlternatingRowBackgroundColors:YES];
  [trackTableView_ setGridStyleMask:NSTableViewSolidVerticalGridLineMask];
  [trackTableView_ setAllowsMultipleSelection:YES];

  NSTableColumn *statusColumn = [[[NSTableColumn alloc] initWithIdentifier:kStatus] autorelease];
  NSTableColumn *artistColumn = [[[NSTableColumn alloc] initWithIdentifier:kArtist] autorelease];
  NSTableColumn *albumColumn = [[[NSTableColumn alloc] initWithIdentifier:kAlbum] autorelease];
  NSTableColumn *titleColumn = [[[NSTableColumn alloc] initWithIdentifier:kTitle] autorelease];
  NSTableColumn *trackNumberColumn = [[[NSTableColumn alloc] initWithIdentifier:kTrackNumber] autorelease];
  NSTableColumn *genreColumn = [[[NSTableColumn alloc] initWithIdentifier:kGenre] autorelease];
  NSTableColumn *durationColumn = [[[NSTableColumn alloc] initWithIdentifier:kDuration] autorelease];
  NSTableColumn *yearColumn = [[[NSTableColumn alloc] initWithIdentifier:kYear] autorelease];
  NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kPath] autorelease];
   
  emptyImage_ = [[NSImage alloc] initWithSize:NSMakeSize(22, 22)];
  playImage_ = [[NSImage imageNamed:@"dot"] retain];
  startImage_ = [[NSImage imageNamed:@"start"] retain];
  stopImage_ = [[NSImage imageNamed:@"stop"] retain];
  [statusColumn setDataCell:[[NSImageCell alloc] initImageCell:emptyImage_]];
  [statusColumn setDataCell:[[NSImageCell alloc] initImageCell:emptyImage_]];
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
  [[pathColumn headerCell] setStringValue:@"Path"];
  [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];

  [[artistColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[albumColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[titleColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[genreColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[durationColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[yearColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[trackNumberColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];

  [trackTableView_ addTableColumn:statusColumn];
  [trackTableView_ addTableColumn:trackNumberColumn];
  [trackTableView_ addTableColumn:titleColumn];
  [trackTableView_ addTableColumn:artistColumn];
  [trackTableView_ addTableColumn:albumColumn];
  [trackTableView_ addTableColumn:yearColumn];
  [trackTableView_ addTableColumn:durationColumn];
  [trackTableView_ addTableColumn:genreColumn];
  [trackTableView_ addTableColumn:pathColumn];
  [trackTableView_ setDelegate:self];
  [trackTableView_ setDataSource:self];
  [trackTableView_ reloadData];
  // embed the table view in the scroll view, and add the scroll view
  // to our window.
  [trackTableScrollView_ setHasVerticalScroller:YES];
  [trackTableScrollView_ setHasHorizontalScroller:YES];
  trackTableScrollView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  [trackTableView_ setDoubleAction:@selector(trackTableDoubleClicked:)];
  [trackTableView_ setTarget:self];
  [contentView_ addSubview:trackTableScrollView_];
  [trackTableScrollView_ setDocumentView:trackTableView_];
  [trackTableView_ registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
}

- (void)setupToolbar { 
  // Setup the toolbar items and the toolbar.
  playButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 22)];
  [playButton_ setTarget:self];
  [playButton_ setTitle:@""];
  //[[playButton_ cell] setControlSize:NSMiniControlSize];
  [playButton_ setImage:startImage_];
  [playButton_ setBezelStyle:NSTexturedRoundedBezelStyle];

  [playButton_ setAction:@selector(playClicked:)];
  playButtonItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kPlayButton];
  [playButtonItem_ setEnabled:YES];
  [playButtonItem_ setView:playButton_];
 
  nextButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 22)];
  [nextButton_ setTarget:self];
  //[[nextButton_ cell] setControlSize:NSMiniControlSize];
  [nextButton_ setTitle:@""];
  [nextButton_ setImage:[NSImage imageNamed:@"right"]];
  [nextButton_ setAction:@selector(nextClicked:)];
  [nextButton_ setBezelStyle:NSTexturedRoundedBezelStyle];
  nextButtonItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kNextButton];
  [nextButtonItem_ setEnabled:YES];
  [nextButtonItem_ setView:nextButton_];

  
  // Previous button
  previousButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 22)];
  //[[previousButton_ cell] setControlSize: NSMiniControlSize];
  [previousButton_ setTarget:self];
  [previousButton_ setTitle:@""];
  [previousButton_ setBezelStyle:NSTexturedRoundedBezelStyle];
  [previousButton_ setImage:[NSImage imageNamed:@"left"]];
  [previousButton_ setAction:@selector(previousClicked:)];
  previousButtonItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kPreviousButton];
  [previousButtonItem_ setEnabled:YES];
  [previousButtonItem_ setView:previousButton_];

  [[nextButton_ cell] setImageScaling:0.8];
  [[playButton_ cell] setImageScaling:0.8];
  [[previousButton_ cell] setImageScaling:0.8];

  // Volume
  volumeSlider_ = [[Slider alloc] initWithFrame:NSMakeRect(0, 0, 100, 22)];
  [volumeSlider_ setContinuous:YES];
  [volumeSlider_ setTarget:self];
  [volumeSlider_ setAction:@selector(volumeClicked:)];
  volumeSlider_.autoresizingMask = 0;
  [[volumeSlider_ cell] setControlSize: NSSmallControlSize];
  [volumeSlider_ setMaxValue:1.0];
  [volumeSlider_ setMinValue:0.0];
  [volumeSlider_ setDoubleValue:0.5];
  volumeItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kVolumeControl];
  [volumeItem_ setView:volumeSlider_];

  NSView *progressControl = [[NSView alloc] 
    initWithFrame:NSMakeRect(0, 0, 5 + 60 + 5 + 300 + 5 + + 60 + 5, 22)];
  // Progress Bar
  progressSlider_ = [[Slider alloc] initWithFrame:NSMakeRect(5 + 60 + 5, 0, 300, 22)];
  [progressSlider_ setContinuous:YES];
  [progressSlider_ setTarget:self];
  [progressSlider_ setAction:@selector(progressClicked:)];
  progressSlider_.autoresizingMask = NSViewWidthSizable;
  [[progressSlider_ cell] setControlSize: NSSmallControlSize];
  [progressSlider_ setMaxValue:1.0];
  [progressSlider_ setMinValue:0.0];
  [progressSlider_ setDoubleValue:0.0];

  elapsedText_ = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 3, 60, 15)];
  elapsedText_.font = [NSFont systemFontOfSize:9.0];
  elapsedText_.stringValue = @"";
  elapsedText_.autoresizingMask = NSViewMaxXMargin;
  elapsedText_.alignment = NSRightTextAlignment;
  [elapsedText_ setDrawsBackground: NO];
  [elapsedText_ setEditable: NO];
  [elapsedText_ setBordered:NO];
  [progressControl addSubview:elapsedText_];

  durationText_ = [[NSTextField alloc] initWithFrame:NSMakeRect(5 + 60 + 5 + 300 + 5, 3, 60, 15)];
  durationText_.font = [NSFont systemFontOfSize:9.0];
  durationText_.stringValue = @"";
  durationText_.autoresizingMask = NSViewMinXMargin;
  durationText_.alignment = NSLeftTextAlignment;
  [durationText_ setDrawsBackground: NO];
  [durationText_ setBordered:NO];
  [durationText_ setEditable: NO];
  [progressControl addSubview:durationText_];

  [progressControl addSubview:progressSlider_];
  progressControl.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  progressSliderItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kProgressControl];
  [progressSliderItem_ setEnabled:YES];
  [progressSliderItem_ setView:progressControl];

  [[NSNotificationCenter defaultCenter] 
    addObserver:self selector:@selector(progressSliderIsUp:) name:kSliderIsUpNotification object:nil];

  [progressSliderItem_ setMaxSize:NSMakeSize(1000, 22)];
  [progressSliderItem_ setMinSize:NSMakeSize(400, 22)];

  searchField_ = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 100, 22)];
  searchField_.font = [NSFont systemFontOfSize:12.0];
  searchField_.autoresizingMask = NSViewMinXMargin;
  searchField_.target = self;
  searchField_.action = @selector(onSearch:);

  [searchField_ setRecentsAutosaveName:@"recentSearches"];

  searchItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kSearchControl];
  [searchItem_ setView:searchField_];

  toolbar_ = [[NSToolbar alloc] initWithIdentifier:@"md0toolbar"];
  [toolbar_ setDelegate:self];
  [toolbar_ setDisplayMode:NSToolbarDisplayModeIconOnly];
  [toolbar_ insertItemWithItemIdentifier:kPlayButton atIndex:0];
  [mainWindow_ setToolbar:toolbar_];
}

- (void)setupDockIcon {
  [NSApp setApplicationIconImage:[NSImage imageNamed:@"md0dock"]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
  md0::movie::Movie::Init();
  trackEnded_ = NO;
  requestPrevious_ = NO;
  requestTogglePlay_ = NO;
  requestNext_ = NO;
  needsLibraryRefresh_ = NO;

  [self setupDockIcon];

  NSApplication *sharedApp = [NSApplication sharedApplication];
  localLibrary_ = new LocalLibrary();
  library_ = localLibrary_;
  localLibrary_->Open(LibraryPath().UTF8String);
  @synchronized(self) {
    if (movie_) 
      delete movie_;
    movie_ = NULL;
  }
  seekToRow_ = -1;
  needsReload_ = NO;
  lastLibraryRefresh_ = 0;

  vector<tuple<string, int> > hosts;
  tuple<string, int> host("0.0.0.0", kDefaultPort);
  hosts.push_back(host);
  daemon_ = new Daemon(hosts, localLibrary_);
  daemon_->Start();

  struct utsname the_utsname;
  uname(&the_utsname);
  NSString *nodeName = [NSString stringWithUTF8String:the_utsname.nodename];
  netService_ = [[NSNetService alloc] 
    initWithDomain:@"local."
    type:kMDNSServiceType
    name:nodeName 
    port:kDefaultPort];
  [netService_ retain];
  [netService_ publish];
  [netService_ scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

  raopServiceBrowser_ = [[NSNetServiceBrowser alloc] init];
  [raopServiceBrowser_ setDelegate:self];
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
  [raopServiceBrowser_ retain];

  mdServiceBrowser_ = [[NSNetServiceBrowser alloc] init];
  [mdServiceBrowser_ setDelegate:self];
  [mdServiceBrowser_ searchForServicesOfType:kMDNSServiceType inDomain:@"local."];
  [mdServiceBrowser_ retain];

  localLibrary_->Prune();
  [self setupWindow];
  [self setupToolbar];
  [self setupTrackTable];
  [self setupAudioSelect];
  [self setupLibrarySelect];
  [self setupMenu];

  sortFields_.clear();
  tuple<NSString *, Direction> artistSort(kArtist, Ascending);
  tuple<NSString *, Direction> albumSort(kAlbum, Ascending);
  tuple<NSString *, Direction> trackSort(kTrackNumber, Ascending);
  tuple<NSString *, Direction> titleSort(kTitle, Ascending);
  tuple<NSString *, Direction> pathSort(kPath, Ascending);
  sortFields_.push_back(artistSort);
  sortFields_.push_back(albumSort);
  sortFields_.push_back(trackSort);
  sortFields_.push_back(titleSort);
  sortFields_.push_back(pathSort);

  [self updateTableColumnHeaders];
  predicateChanged_ = YES;
  sortChanged_ = YES;

  pollMovieTimer_ = [NSTimer scheduledTimerWithTimeInterval:.15 target:self selector:@selector(onPollMovieTimer:) userInfo:nil repeats:YES];
  pollLibraryTimer_ = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(onPollLibraryTimer:) userInfo:nil repeats:YES];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {  
  NSLog(@"validate drop");
  return operation;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
  NSPasteboard *pasteboard = [info draggingPasteboard];
  NSArray *paths = [pasteboard propertyListForType:NSFilenamesPboardType];
  BOOL ret = NO;
  vector<string> paths0;
    
  for (NSString *path in paths)
    paths0.push_back([path UTF8String]);
  localLibrary_->Scan(paths0, false);
  return paths0.size() ? YES : NO;
}
     
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
  [netService retain];
  [netService setDelegate:self];
  [netService resolveWithTimeout:10.0];
}

- (void)netServiceDidResolveAddress:(NSNetService *)netService {
  string addr;

  string name([[netService hostName] UTF8String]);
  for (NSData *d in [netService addresses]) {
    struct sockaddr *a = ((struct sockaddr *)[d bytes]);
    if (a->sa_family != AF_INET) { // we only want ipv4
      continue;
    }
    char buf[256];
    buf[0] = 0;
    if (inet_ntop(AF_INET, &((struct sockaddr_in *)a)->sin_addr, buf, 256)) {
      addr = (const char *)buf;
      break;
    }
  } 
  if (addr.length() > 0) {
    Service s(addr, [netService port], [[netService hostName] UTF8String], [[netService type] UTF8String]);
    services_.insert(s);
  }
  [self refreshAudioOutputList];
  [self refreshLibraryList];
  [netService autorelease];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
  NSLog(@"failed to resolve: %@ dict:%@", sender, errorDict);
}


- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
  NSString *ident = tableColumn.identifier;
  if (!ident || ident == kStatus) { 
    return;
  }

  @synchronized(self) { 
    int found = -1;
    int idx = 0;
    for (vector<SortField>::iterator i = sortFields_.begin(); i < sortFields_.end(); i++) {
      NSString *f = get<0>(*i);
      if (f == ident) {
        found = idx; 
        break;
      }
      idx++;
    }
    if (found < 0) {
      tuple<NSString *, Direction> f(ident, Ascending);
      sortFields_.insert(sortFields_.begin(), f);
    } else if (found > 0) {
      tuple<NSString *, Direction> f(ident, Ascending);
      sortFields_.erase(sortFields_.begin() + found); 
      sortFields_.insert(sortFields_.begin(), f);
    } else { 
      Direction d = get<1>(sortFields_[0]);
      d = (d == Ascending) ? Descending : Ascending;
      tuple<NSString *, Direction> f(ident, d);
      sortFields_.erase(sortFields_.begin());
      sortFields_.insert(sortFields_.begin(), f);
    }
    sortChanged_ = YES;

  }
  [self updateTableColumnHeaders];
}

- (void)updateTableColumnHeaders {
  for (NSTableColumn *c in trackTableView_.tableColumns) { 
    [trackTableView_ setIndicatorImage:nil inTableColumn:c];
  }
  for (vector<SortField>::iterator i = sortFields_.begin(); i < sortFields_.end(); i++) {
    SortField f = *i;
    NSString *ident = get<0>(f);
    Direction d = get<1>(f);
    NSImage *img = [NSImage imageNamed:d == Ascending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"];
    [trackTableView_ setIndicatorImage:img inTableColumn:[trackTableView_ tableColumnWithIdentifier:ident]];
  }
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
  if (itemIdentifier == kPlayButton) { 
    return playButtonItem_;  
  } else if (itemIdentifier == kProgressControl) { 
    return progressSliderItem_;
  } else if (itemIdentifier == kVolumeControl) { 
    return volumeItem_;
  } else if (itemIdentifier == kSearchControl) { 
    return searchItem_;
  } else if (itemIdentifier == kPreviousButton) { 
    return previousButtonItem_;
  } else if (itemIdentifier == kNextButton)  {
    return nextButtonItem_;
  }
  return nil;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar { 
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}

- (void)toolbarWillAddItem:(NSNotification *)notification {

}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}

- (void)executeSearch { 
  NSArray *parts = [searchQuery_ componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  vector<string> parts0;
  if (parts) {
    for (NSString *p in parts) {
      string s = p.UTF8String; 
      if (s.length() > 0)
        parts0.push_back(s); 
    }
  }
  @synchronized(self) {
    tracks_.clear();
    for (vector<Track>::iterator i = allTracks_.begin(); i < allTracks_.end(); i++) {
      Track t(*i);
      if (parts0.size() == 0 || IsTrackMatchAllTerms(&t, parts0)) {
        tracks_.push_back(t);
      }
    }
    needsReload_ = YES;
  }
}

- (void)onSearch:(id)sender { 
  self.searchQuery = searchField_.stringValue;
  predicateChanged_ = YES;
  needsReload_ = YES;
}

- (void)volumeClicked:(id)sender { 
  SetVolume(volumeSlider_.doubleValue);
}

- (void)progressSliderIsUp:(NSNotification *)notification {
  if (movie_)
    movie_->Seek(progressSlider_.doubleValue * movie_->Duration());  
}

- (void)progressClicked:(id)sender { 
  if (movie_) {
    double duration = movie_->Duration();
    [self displayElapsed:(progressSlider_.doubleValue * duration) duration:duration];
  }
}

- (void)displayElapsed:(double)elapsed duration:(double)duration {
  [progressSlider_ setEnabled:YES];
  double pct = duration > 0 ? elapsed / duration : 0;
  durationText_.stringValue = FormatSeconds(duration);
  elapsedText_.stringValue = FormatSeconds(elapsed);
  if (![progressSlider_ isMouseDown] && !movie_->IsSeeking())
    [progressSlider_ setDoubleValue:pct];
}

- (void)executeSort { 
  @synchronized(self) {
    TrackComparator cmp(sortFields_);
    sort(allTracks_.begin(), allTracks_.end(), cmp);  
  }
}

- (void)onPollMovieTimer:(id)sender { 
  if (track_.path().length() > 0) {
    mainWindow_.title = GetWindowTitle(track_);
  } else { 
    mainWindow_.title = @"MD0";
  }
  if (trackEnded_) {
    [self playNextTrack];
    trackEnded_ = NO;
  }

  if (requestNext_) {
    [self playNextTrack];
    requestNext_ = NO;
  }

  if (requestPrevious_) {
    [self playPreviousTrack];
    requestPrevious_ = NO;
  }

  if (requestClearSelection_) { 
    [trackTableView_ deselectAll:self];
    requestClearSelection_ = NO;
  }

  if (requestTogglePlay_) {
    @synchronized (self) {
      if (movie_) { 
        bool playing = movie_->state() == kPlayingMovieState;
        if (playing) { 
          movie_->Stop();
        } else { 
          movie_->Play();
        }
      } else { 
        [self playNextTrack];
      }
      requestTogglePlay_ = NO;
    }
  }

  if (movie_ != NULL) {
    if (![progressSlider_ isMouseDown] && !movie_->IsSeeking()) { 
      double duration = movie_->Duration();
      double elapsed = movie_->Elapsed();
      [self displayElapsed:elapsed duration:duration];
    }
    MovieState st = movie_->state();
    if (st == kPlayingMovieState)  {
      playButton_.image = stopImage_;
    } else { 
      playButton_.image = startImage_;
    }
  } else { 
    [progressSlider_ setEnabled:NO];
    [progressSlider_ setDoubleValue:0];
    durationText_.stringValue = @"";
    elapsedText_.stringValue = @"";
    playButton_.image = startImage_;
  }
  
  @synchronized (self) { 
    long double t = library_->last_update();
    struct timeval now;
    gettimeofday(&now, NULL);
    long double now0 = ((long double)now.tv_sec) + (((long double)now.tv_usec) / 1000000.0);

    if (needsLibraryRefresh_
        || (lastLibraryRefresh_ == 0)
        || ((lastLibraryRefresh_ < t) && ((now0 - lastLibraryRefresh_) > kLibraryRefreshInterval))) {
      predicateChanged_ = YES;
      sortChanged_ = YES;
      allTracks_.clear();
      library_->GetAll(&allTracks_);
      needsLibraryRefresh_ = NO;
      needsReload_ = YES;
      sortChanged_ = YES;
      lastLibraryRefresh_ = now0;
    }
  }
  if (sortChanged_) {
    [self executeSort];
    predicateChanged_ = YES;
    needsReload_ = YES;
    sortChanged_ = NO;
  }
  if (predicateChanged_) {
    [self executeSearch];
    predicateChanged_ = NO;
    needsReload_ = YES;
  } 

  if (needsReload_) {
    [trackTableView_ reloadData];
    needsReload_ = NO;
  }

  if (seekToRow_ >= 0) {
    [trackTableView_ scrollRowToVisible:seekToRow_];
    seekToRow_ = -1;
  }
}

- (void)onPollLibraryTimer:(id)sender { 
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
  [mdServiceBrowser_ searchForServicesOfType:kMDNSServiceType inDomain:@"local."];
}

- (void)trackTableDoubleClicked:(id)sender { 
  int row = [trackTableView_ clickedRow];
  if (row >= 0 && row < tracks_.size()) {
    [self playTrackAtIndex:row];
  }
}

- (void)playTrackAtIndex:(int)index { 
  @synchronized(self) {
    if (index < 0)
      return;
    if (index >= tracks_.size())
      return;
    Track aTrack = tracks_.at(index);
    NSLog(@"play: %s", aTrack.path().c_str());
    if (movie_) {
      movie_->Stop();
    }
    track_ = aTrack;
    if (movie_)
      delete movie_;
    movie_ = new Movie(aTrack.path().c_str());
    movie_->Play();
    movie_->SetListener(HandleMovieEvent, self);
    seekToRow_ = index;
    needsReload_ = YES;
  }
}

- (void)handleMovie:(Movie *)movie event:(MovieEvent)event data:(void *)data {
  if (movie != movie_)
    return;
  switch (event) { 
    case kAudioFrameProcessedMovieEvent:
      break;
    case kRateChangeMovieEvent:
      break;
    case kEndedMovieEvent: 
      // Handle this async to avoid deadlock / threading situations
      trackEnded_ = YES;
      break;
    default:
      break;
  }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return tracks_.size();
}

/*
 * Play the next track.
 */
- (void)playNextTrack {
  int idx = 0;
  int found = -1;  
  if (track_.path().length()) { 
    for (vector<Track>::iterator i = tracks_.begin(); i < tracks_.end(); i++) {
       if (i->path() == track_.path()) {
         found = idx;       
         break;
       }
       idx++;
    }
  } 
  [self playTrackAtIndex:found + 1];
}

- (void)playPreviousTrack {
  int idx = 0;
  int found = -1;  
  int req = 0;
  if (track_.path().length()) { 
    for (vector<Track>::const_iterator i = tracks_.begin(); i < tracks_.end(); i++) {
       if (i->path() == track_.path()) {
         found = idx;       
         break;
       }
       idx++;
    }
    if (found > 0) 
      req = found - 1;
  } 
  [self playTrackAtIndex:req];
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  Track t(tracks_.at(rowIndex));
  NSString *identifier = aTableColumn.identifier;
  id result = nil;
  NSString *s = nil;
  bool isPlaying = (track_.path().length()
        && movie_
        && t.path() == track_.path());
  if (identifier == kArtist)
    s = GetString(t.artist());
  else if (identifier == kAlbum)
    s = GetString(t.album());
  else if (identifier == kGenre)
    s = GetString(t.genre());
  else if (identifier == kDuration)
    s = GetTimeString(t.duration());
  else if (identifier == kYear)
    s = GetString(t.year());
  else if (identifier == kTitle)
    s = GetString(t.title());
  else if (identifier == kTrackNumber)
    s = GetString(t.track_number());
  else if (identifier == kPath)
    s = GetString(t.path());
  else if (identifier == kStatus) {
    if (isPlaying) {
      result = playImage_;
      [[aTableColumn dataCell] setImageScaling:0.5];
    }
  }
  if (s) {
    result = s;
    [[aTableColumn dataCell] setFont:isPlaying ? trackTablePlayingFont_ : trackTableFont_];
  } else { 
     
  }
  return result;
}

- (void)playClicked:(id)sender { 
  NSLog(@"play clicked");
  requestTogglePlay_ = YES;
}

- (void)nextClicked:(id)sender { 
  NSLog(@"next clicked");
  requestNext_ = YES;
}

- (void)previousClicked:(id)sender { 
  NSLog(@"previous clicked");
  requestPrevious_ = YES;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  return NO;
}


@end

