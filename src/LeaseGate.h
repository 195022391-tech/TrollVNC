#import <Foundation/Foundation.h>

// 1 = listen, 0 = wait (no account bind yet), -1 = network or bad signature.
int TVLeaseRefresh(NSString *_Nullable *_Nonnull outPassword);
void TVLeaseWriteMemory(void);
// YES when Account+Password set and DeviceToken is missing — poll faster.
BOOL TVLeasePendingPair(void);
