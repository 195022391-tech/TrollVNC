#import "LeaseGate.h"
#import "BulletinManager.h"

#import <mach/mach.h>
#import <openssl/evp.h>

// Must match phone-lease.pem on the license server. Public key only.
static const unsigned char kLeasePub[32] = {
    0xff, 0xaa, 0xaa, 0xc5, 0x9e, 0x15, 0x0a, 0x9f, 0x64, 0x9d, 0x49,
    0xb1, 0x12, 0x63, 0x95, 0xf6, 0x33, 0x43, 0x3e, 0x99, 0xdf, 0x02,
    0xe6, 0x74, 0x99, 0x95, 0xa4, 0xc5, 0x89, 0x06, 0x7c, 0xf6};

static NSString *const kDom = @"com.82flex.trollvnc";
static NSString *const kURL = @"https://touping.facaishu.vip";

static id TVPref(NSString *key) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDom);
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kDom));
}

static void TVSetPref(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)kDom);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDom);
}

static CFAbsoluteTime sPairFailBannerAt = 0;

static void TVPairBanner(NSString *msg) {
    if (![msg isKindOfClass:[NSString class]] || msg.length == 0)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[BulletinManager sharedManager] popBannerWithContent:msg userInfo:nil];
    });
}

static void TVPairFailBanner(void) {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - sPairFailBannerAt < 20)
        return;
    sPairFailBannerAt = now;
    TVPairBanner(@"配对失败，请检查配对码后重试");
}

static NSData *TVB64URL(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0)
        return nil;
    NSString *s = [[text stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
        stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSUInteger pad = (4 - (s.length % 4)) % 4;
    if (pad)
        s = [s stringByPaddingToLength:s.length + pad withString:@"=" startingAtIndex:0];
    return [[NSData alloc] initWithBase64EncodedString:s options:0];
}

static NSDictionary *TVPost(NSString *path, NSDictionary *body, NSInteger *status) {
    *status = 0;
    NSURL *url = [NSURL URLWithString:[kURL stringByAppendingString:path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 12;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSInteger code = 0;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
                                       data = d;
                                       if ([r isKindOfClass:[NSHTTPURLResponse class]])
                                           code = ((NSHTTPURLResponse *)r).statusCode;
                                       (void)e;
                                       dispatch_semaphore_signal(sem);
                                     }] resume];
    if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC)) != 0)
        return nil;
    *status = code;
    if (!data)
        return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

static BOOL TVVerify(NSData *payload, NSData *sig) {
    if (!payload.length || sig.length != 64)
        return NO;
    EVP_PKEY *key = EVP_PKEY_new_raw_public_key(EVP_PKEY_ED25519, NULL, kLeasePub, sizeof(kLeasePub));
    if (!key)
        return NO;
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    int ok = EVP_DigestVerifyInit(ctx, NULL, NULL, NULL, key) == 1 &&
             EVP_DigestVerify(ctx, (const unsigned char *)sig.bytes, sig.length,
                              (const unsigned char *)payload.bytes, payload.length) == 1;
    EVP_MD_CTX_free(ctx);
    EVP_PKEY_free(key);
    return ok;
}

BOOL TVLeasePendingPair(void) {
    NSString *token = TVPref(@"DeviceToken");
    if ([token isKindOfClass:[NSString class]] && token.length >= 16)
        return NO;
    NSString *code = TVPref(@"PairCode");
    return [code isKindOfClass:[NSString class]] && code.length >= 4;
}

void TVLeaseWriteMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
        return;
    unsigned long long phys = [NSProcessInfo processInfo].physicalMemory;
    double mb = info.resident_size / 1048576.0;
    double pct = phys ? (100.0 * info.resident_size / phys) : 0;
    TVSetPref(@"MemoryUsage", [NSString stringWithFormat:@"%.0f MB · %.1f%%", mb, pct]);
}

int TVLeaseRefresh(NSString *__autoreleasing *outPassword) {
    *outPassword = nil;
    TVLeaseWriteMemory();
    NSString *token = TVPref(@"DeviceToken");
    if (![token isKindOfClass:[NSString class]] || token.length < 16) {
        NSString *code = TVPref(@"PairCode");
        if (![code isKindOfClass:[NSString class]] || code.length < 4)
            return 0;
        NSInteger status = 0;
        NSDictionary *resp = TVPost(@"/api/device/pair", @{@"code" : code}, &status);
        NSString *got = resp[@"deviceToken"];
        if (status != 200 || ![got isKindOfClass:[NSString class]] || got.length < 16) {
            TVPairFailBanner();
            return -1;
        }
        TVSetPref(@"DeviceToken", got);
        TVSetPref(@"PairCode", @"");
        TVPairBanner(@"配对成功");
        token = got;
    }
    NSInteger status = 0;
    NSDictionary *resp = TVPost(@"/api/device/lease", @{@"deviceToken" : token}, &status);
    if (!resp)
        return -1;
    NSData *payload = TVB64URL(resp[@"payload"]);
    NSData *sig = TVB64URL(resp[@"sig"]);
    if (status != 200 || !TVVerify(payload, sig))
        return -1;
    id obj = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]])
        return -1;
    long long exp = [obj[@"exp"] longLongValue];
    NSString *pw = obj[@"pw"];
    long long now = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    if (exp <= now || ![pw isKindOfClass:[NSString class]] || pw.length != 8)
        return -1;
    *outPassword = pw;
    return 1;
}
