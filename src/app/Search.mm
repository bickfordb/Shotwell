#import "app/Search.h"

NSPredicate *ParseSearchQuery(NSString *query) {
  NSPredicate *ret = nil;
  if (query && query.length) {
    NSArray *tokens = [query 
      componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *token in tokens)  {
      if (token.length == 0)
        continue;
      NSPredicate *predicate = [NSPredicate 
        predicateWithFormat:
          @"(artist CONTAINS[cd] %@)"
          " OR (album CONTAINS[cd] %@)"
          " OR (title CONTAINS[cd] %@)"
          //" OR (url.absoluteString CONTAINS[cd] %@)"
          " OR (year CONTAINS[cd] %@)"
          " OR (genre CONTAINS[cd] %@)",
        token, token, token, token, token, token, nil];
      if (!ret)
        ret = predicate;
      else
        ret = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray 
          arrayWithObjects:predicate, ret, nil]];
    }
  }
  return ret;
}

