#import "app/PreferencesWindowController.h"

static NSString * const kGeneral = @"General";

@implementation PreferencesWindowController 
@synthesize automaticPathsEditor = automaticPathsEditor_;

- (void)dealloc { 
  [automaticPathsEditor_ release];
  [super dealloc];
}

- (id)initWithLocalLibrary:(LocalLibrary *)localLibrary {
  self = [super init];

  if (self) {
    self.automaticPathsEditor = [[[AutomaticPathsEditor alloc] initWithLocalLibrary:localLibrary] autorelease];
    self.window.contentSize = self.automaticPathsEditor.view.frame.size;

    // Fix the responder chain:
    [self.window.contentView addSubview:self.automaticPathsEditor.view];
    self.automaticPathsEditor.view.nextResponder = self.automaticPathsEditor;
    self.automaticPathsEditor.nextResponder = self.window.contentView;

    self.window.title = @"Preferences";
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"] autorelease];
    toolbar.delegate = self;
    self.window.toolbar = toolbar;
  }
  return self;
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
  NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
  NSView *view = nil;
  if (itemIdentifier == kGeneral) { 
    item.label = @"General";
    item.target = self;
    item.action = @selector(generalSelected:);
    NSImageView *view = [[[NSImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)] autorelease];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.image = [NSImage imageNamed:@"NSPreferencesGeneral"];
    item.view = view;
  }
  if (view) {
    item.view = view;
    item.enabled = YES;
  }
  return item;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar { 
  return [NSArray arrayWithObjects:kGeneral, nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}
- (void)toolbarWillAddItem:(NSNotification *)notification {
}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}
@end
