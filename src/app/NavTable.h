#import <Cocoa/Cocoa.h>
#import "app/ImageAndTextCell.h"

typedef NSMutableDictionary NavNode;
typedef void (^OnAction)();

NavNode *NodeCreate();
id NodeGet(NavNode *node, NSString *k);
void NodeSet(NavNode *node, NSString *k, id v);
void NodeAppend(NavNode *node, NavNode *otherNode);
NSTextFieldCell *NodeTextCell();
NSTextFieldCell *NodeImageTextCell(NSImage *image);

extern NSString * const kNodeIsGroup;
extern NSString * const kNodeChildren;
extern NSString * const kNodeTitle;
extern NSString * const kNodeTitleCell;
extern NSString * const kNodeStatus;
extern NSString * const kNodeOnSelect;
extern NSString * const kNodeIsSelectable;

@interface NavTable : NSView <NSOutlineViewDelegate, NSOutlineViewDataSource> {
  NSScrollView *scrollView_;
  NSOutlineView *outlineView_;
  NSTreeController *treeController_;
  NSMutableDictionary *rootNode_;
}

@property (retain) NSMutableDictionary *rootNode;
@property (retain) NSScrollView *scrollView;
@property (retain) NSOutlineView *outlineView;
 - (void)reload;
@end

// vim: filetype=objcpp
