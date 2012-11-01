#import "app/Chromaprint.h"

int main(int argc, char **argv) {
  int ret = 0;
  for (int i = 1; i < argc; i++) {
    NSString *acousticID;
    double score;
    (void)ChromaprintGetAcousticID(nil, [NSString stringWithUTF8String:argv[i]], &acousticID, &score);
    NSLog(@"acousticID: %@, score: %f", acousticID, score);
  }
  return ret;
}
