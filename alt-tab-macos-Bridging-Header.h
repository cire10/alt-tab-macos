#import <Cocoa/Cocoa.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import "AppCenterApplication.h"
#import "ObjCExceptionCatcher.h"

typedef NS_ENUM(NSInteger, NSGlassEffectViewStyle) {
    NSGlassEffectViewStyleRegular = 0,
    NSGlassEffectViewStyleClear = 1
};

__attribute__((weak_import))
@interface NSGlassEffectView : NSView
@property (nonatomic) NSGlassEffectViewStyle style;
@property (nonatomic, strong) NSView *contentView;
@property (nonatomic) CGFloat cornerRadius;
@end

typedef NS_ENUM(NSInteger, SCScreenshotDynamicRange) {
    SCScreenshotDynamicRangeSdr = 0,
    SCScreenshotDynamicRangeHdr = 1
};

__attribute__((weak_import))
@interface SCScreenshotConfiguration : NSObject
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@property (nonatomic) BOOL showsCursor;
@property (nonatomic) SCScreenshotDynamicRange dynamicRange;
@end

__attribute__((weak_import))
@interface SCScreenshotOutput : NSObject
@property (nonatomic, readonly, nullable) CGImageRef sdrImage;
@end

@interface SCScreenshotManager (FutureApis)
+ (void)captureScreenshotWithFilter:(SCContentFilter *)contentFilter
                      configuration:(SCScreenshotConfiguration *)config
                  completionHandler:(void (^)(SCScreenshotOutput * _Nullable output, NSError * _Nullable error))completionHandler
    NS_SWIFT_NAME(captureScreenshot(contentFilter:configuration:completionHandler:));
@end
