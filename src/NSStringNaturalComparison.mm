// See original author copyright notice in NSStringNaturalComparison.h

#include <ctype.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

#import "NSStringNaturalComparison.h"

typedef char nat_char;

/* These are defined as macros to make it easier to adapt this code to
 * different characters types or comparison functions. */
static inline int
nat_isdigit(nat_char a)
{
     return isdigit((unsigned char) a);
}


static inline int
nat_isspace(nat_char a)
{
     return isspace((unsigned char) a);
}


static inline nat_char
nat_toupper(nat_char a)
{
     return toupper((unsigned char) a);
}



static int
compare_right(nat_char const *a, nat_char const *b)
{
     int bias = 0;

     /* The longest run of digits wins.  That aside, the greatest
	value wins, but we can't know that it will until we've scanned
	both numbers to know that they have the same magnitude, so we
	remember it in BIAS. */
     for (;; a++, b++) {
	  if (!nat_isdigit(*a)  &&  !nat_isdigit(*b))
	       return bias;
	  else if (!nat_isdigit(*a))
	       return -1;
	  else if (!nat_isdigit(*b))
	       return +1;
	  else if (*a < *b) {
	       if (!bias)
		    bias = -1;
	  } else if (*a > *b) {
	       if (!bias)
		    bias = +1;
	  } else if (!*a  &&  !*b)
	       return bias;
     }

     return 0;
}


static int
compare_left(nat_char const *a, nat_char const *b)
{
     /* Compare two left-aligned numbers: the first to have a
        different value wins. */
     for (;; a++, b++) {
	  if (!nat_isdigit(*a)  &&  !nat_isdigit(*b))
	       return 0;
	  else if (!nat_isdigit(*a))
	       return -1;
	  else if (!nat_isdigit(*b))
	       return +1;
	  else if (*a < *b)
	       return -1;
	  else if (*a > *b)
	       return +1;
     }
	
     return 0;
}


static int strnatcmp0(nat_char const *a, nat_char const *b, int fold_case)
{
     int ai, bi;
     nat_char ca, cb;
     int fractional, result;

     assert(a && b);
     ai = bi = 0;
     while (1) {
	  ca = a[ai]; cb = b[bi];

	  /* skip over leading spaces or zeros */
	  while (nat_isspace(ca))
	       ca = a[++ai];

	  while (nat_isspace(cb))
	       cb = b[++bi];

	  /* process run of digits */
	  if (nat_isdigit(ca)  &&  nat_isdigit(cb)) {
	       fractional = (ca == '0' || cb == '0');

	       if (fractional) {
		    if ((result = compare_left(a+ai, b+bi)) != 0)
			 return result;
	       } else {
		    if ((result = compare_right(a+ai, b+bi)) != 0)
			 return result;
	       }
	  }

	  if (!ca && !cb) {
	       /* The strings compare the same.  Perhaps the caller
                  will want to call strcmp to break the tie. */
	       return 0;
	  }

	  if (fold_case) {
	       ca = nat_toupper(ca);
	       cb = nat_toupper(cb);
	  }
	
	  if (ca < cb)
	       return -1;
	  else if (ca > cb)
	       return +1;

	  ++ai; ++bi;
     }
}



int strnatcmp(nat_char const *a, nat_char const *b) {
     return strnatcmp0(a, b, 0);
}


/* Compare, recognizing numeric string and ignoring case. */
int strnatcasecmp(nat_char const *a, nat_char const *b) {
     return strnatcmp0(a, b, 1);
}

@implementation NSString (NaturalComparison)
- (NSComparisonResult)naturalCompare:(NSString *)other {
  return strnatcmp(self.UTF8String, other.UTF8String);
}
- (NSComparisonResult)naturalCompareCaseInsensitive:(NSString *)other {
  return strnatcasecmp(self.UTF8String, other.UTF8String);
}
@end


