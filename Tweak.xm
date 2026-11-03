#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <fcntl.h>
#import <unistd.h>

// PalmGuard 0.1.1 — diagnostic-first prototype.
// Passive capacitive styluses are normally indistinguishable from fingers.
// This experimental filter uses UITouch.majorRadius as a heuristic only.

static const CFStringRef kPGPrefsDomain = CFSTR("com.palmguard.tweak");
static BOOL gPGEnabled = NO;
static BOOL gPGLoggingEnabled = YES;
static CGFloat gPGRadiusThreshold = 25.0;
static dispatch_once_t gPGConfigOnce;
static NSHashTable<UITouch *> *gPGLoggedTouches;

static void PGLoadConfiguration(void) {
    dispatch_once(&gPGConfigOnce, ^{
        CFPreferencesAppSynchronize(kPGPrefsDomain);

        CFPropertyListRef enabled = CFPreferencesCopyAppValue(CFSTR("Enabled"), kPGPrefsDomain);
        if (enabled && CFGetTypeID(enabled) == CFBooleanGetTypeID()) {
            gPGEnabled = CFBooleanGetValue((CFBooleanRef)enabled);
        }
        if (enabled) CFRelease(enabled);

        CFPropertyListRef logging = CFPreferencesCopyAppValue(CFSTR("LogTouches"), kPGPrefsDomain);
        if (logging && CFGetTypeID(logging) == CFBooleanGetTypeID()) {
            gPGLoggingEnabled = CFBooleanGetValue((CFBooleanRef)logging);
        }
        if (logging) CFRelease(logging);

        CFPropertyListRef radius = CFPreferencesCopyAppValue(CFSTR("RadiusThreshold"), kPGPrefsDomain);
        if (radius && CFGetTypeID(radius) == CFNumberGetTypeID()) {
            double value = 25.0;
            if (CFNumberGetValue((CFNumberRef)radius, kCFNumberDoubleType, &value)) {
                gPGRadiusThreshold = (CGFloat)fmin(fmax(value, 8.0), 80.0);
            }
        }
        if (radius) CFRelease(radius);

        gPGLoggedTouches = [NSHashTable weakObjectsHashTable];
    });
}

static void PGWriteLog(NSString *message) {
    @autoreleasepool {
        NSString *directory = @"/var/mobile/Library/Logs";
        NSString *path = [directory stringByAppendingPathComponent:@"PalmGuard.log"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        NSData *data = [[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        int fd = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            (void)write(fd, data.bytes, data.length);
            close(fd);
        }
    }
}

static void PGLogTouchOnce(UITouch *touch) {
    if (!gPGLoggingEnabled || !touch) return;
    @synchronized (gPGLoggedTouches) {
        if ([gPGLoggedTouches containsObject:touch]) return;
        [gPGLoggedTouches addObject:touch];
    }

    PGWriteLog([NSString stringWithFormat:
        @"PalmGuard type=%ld phase=%ld majorRadius=%.2f tolerance=%.2f",
        (long)touch.type, (long)touch.phase,
        (double)touch.majorRadius, (double)touch.majorRadiusTolerance]);
}

%hook UIView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    PGLoadConfiguration();

    if (event && event.type == UIEventTypeTouches) {
        NSSet<UITouch *> *touches = event.allTouches;
        for (UITouch *touch in touches) {
            if (touch.type != UITouchTypeDirect) continue;
            if (touch.phase != UITouchPhaseBegan) continue;

            CGPoint location = [touch locationInView:self];
            if (hypot(location.x - point.x, location.y - point.y) > 3.0) continue;

            PGLogTouchOnce(touch);

            if (gPGEnabled) {
                CGFloat radius = touch.majorRadius;
                if (radius > 0.0 && radius >= gPGRadiusThreshold) {
                    return NO;
                }
            }
        }
    }

    return %orig;
}

%end
