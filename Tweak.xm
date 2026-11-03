#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <fcntl.h>
#import <unistd.h>

// PalmGuard 0.2.0
// Passive capacitive styluses are usually reported as direct touches.
// This build filters a matching large-radius touch at the app window's
// hit-testing boundary instead of returning NO from every UIView.

static const CFStringRef kPGPrefsDomain = CFSTR("com.palmguard.tweak");
static BOOL gPGEnabled = NO;
static BOOL gPGLoggingEnabled = YES;
static CGFloat gPGRadiusThreshold = 25.0;
static dispatch_once_t gPGConfigOnce;
static NSHashTable<UITouch *> *gPGLoggedTouches;

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
        PGWriteLog([NSString stringWithFormat:@"PalmGuard 0.2.0 loaded enabled=%@ threshold=%.1f logging=%@",
                    gPGEnabled ? @"YES" : @"NO",
                    (double)gPGRadiusThreshold,
                    gPGLoggingEnabled ? @"YES" : @"NO"]);
    });
}

static void PGLogTouchOnce(UITouch *touch) {
    if (!gPGLoggingEnabled || !touch) return;

    @synchronized (gPGLoggedTouches) {
        if ([gPGLoggedTouches containsObject:touch]) return;
        [gPGLoggedTouches addObject:touch];
    }

    PGWriteLog([NSString stringWithFormat:
        @"PalmGuard touch type=%ld phase=%ld majorRadius=%.2f tolerance=%.2f",
        (long)touch.type, (long)touch.phase,
        (double)touch.majorRadius, (double)touch.majorRadiusTolerance]);
}

%hook UIWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    PGLoadConfiguration();

    if (event && event.type == UIEventTypeTouches) {
        for (UITouch *touch in event.allTouches) {
            if (touch.type != UITouchTypeDirect) continue;
            if (touch.phase != UITouchPhaseBegan) continue;

            // hitTest's point and locationInView:self are both in window coordinates.
            CGPoint touchPoint = [touch locationInView:self];
            if (hypot(touchPoint.x - point.x, touchPoint.y - point.y) > 8.0) continue;

            PGLogTouchOnce(touch);

            CGFloat radius = touch.majorRadius;
            if (gPGEnabled && radius > 0.0 && radius >= gPGRadiusThreshold) {
                PGWriteLog([NSString stringWithFormat:
                    @"PalmGuard filtered large touch radius=%.2f threshold=%.2f",
                    (double)radius, (double)gPGRadiusThreshold]);
                return nil;
            }
            break;
        }
    }

    return %orig;
}

%end
