#import <Foundation/Foundation.h>

// 1 = listen, 0 = wait (no pairing yet), -1 = network or bad signature.
int TVLeaseRefresh(NSString *_Nullable *_Nonnull outPassword);
void TVLeaseWriteMemory(void);
// YES when PairCode is set and DeviceToken is missing — poll faster.
BOOL TVLeasePendingPair(void);
