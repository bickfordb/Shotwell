#import "app/Log.h"
#import "app/Search.h"
#import "app/Track.h"

static NSString * const kColon = @":";
static NSString * const kSpace = @" ";
static NSString * const kQuote = @"\"";
static NSPredicate *WildcardPredicate(NSString *term);
static NSPredicate *FieldPredicate(NSString *field, NSString *term);
static NSPredicate *AndPredicate(NSPredicate *left, NSPredicate *right);


static NSPredicate *AndPredicate(NSPredicate *left, NSPredicate *right) {
  if (!left)
    return right;
  else if (!right)
    return left;
  else {
    return [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:left, right, nil]]; 
  }
}

static NSArray *ScanQuery(NSString *query) {
  NSScanner *scanner = [NSScanner scannerWithString:query]; 
  NSCharacterSet *specialChars = [NSCharacterSet characterSetWithCharactersInString:@": \""];
  NSCharacterSet *quote = [NSCharacterSet characterSetWithCharactersInString:kQuote];
  NSCharacterSet *notQuote = quote.invertedSet;
  NSCharacterSet *nonSpecialChars = specialChars.invertedSet;
  NSMutableArray *tokens = [NSMutableArray array];
  while (!scanner.isAtEnd) {
    NSString *s = nil;
    if ([scanner scanCharactersFromSet:nonSpecialChars intoString:&s]) {
      [tokens addObject:s];
      continue;
    } else if ([scanner scanString:kColon intoString:&s]) {
      [tokens addObject:kColon];
      continue;
    } else if ([scanner scanString:kQuote intoString:&s]) {
      if ([scanner scanCharactersFromSet:notQuote intoString:&s]) {
        [tokens addObject:s];
      }
      [scanner scanString:kQuote intoString:&s];
    } else if ([scanner scanString:kSpace intoString:&s]) {
    }
  }
  return tokens;
}

NSPredicate *ParseSearchQuery(NSString *query) {
  NSArray *tokens = ScanQuery(query);
  NSPredicate *ret = nil;
  int i = 0;
  while (i < tokens.count) {
    NSString *token0 = [tokens objectAtIndex:i];
    NSString *token1 = ((i + 1) < tokens.count) ? [tokens objectAtIndex:i + 1] : nil;
    i++;
    if ([token1 isEqualToString:kColon]) {
      i++;
      NSString *token2 = nil;
      while (i < tokens.count) { 
        token2 = [tokens objectAtIndex:i];
        i++; 
        if ([token2 isEqualToString:kColon]) {
          token2 = nil;
          continue;
        } else { 
          break;
        }
      }
      ret = AndPredicate(ret, token2 ? FieldPredicate(token0, token2) : WildcardPredicate(token0));
    } else { 
      ret = AndPredicate(ret, WildcardPredicate(token0));
    }
  }
  return ret;
}

static NSPredicate *WildcardPredicate(NSString *term) {
  return [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:
      FieldPredicate(kArtist, term),
      FieldPredicate(kAlbum, term),
      FieldPredicate(kTitle, term),
      FieldPredicate(kPath, term),
      FieldPredicate(kPublisher, term),
      FieldPredicate(kYear, term),
      FieldPredicate(kGenre, term), nil]];
}

static NSPredicate *FieldPredicate(NSString *field, NSString *term) {
  if (![[NSSet setWithObjects:kArtist, kAlbum, kTitle, kPath, kPublisher, kYear, kGenre, nil] containsObject:field])
    return nil; 
  return [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%@ CONTAINS[cd] %%@", field], term, nil];
}

