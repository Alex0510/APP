// NSUserDefaults+LiveContainer.m
// 实现NSUserDefaults的LiveContainer分类

#import "utils.h"

@implementation NSUserDefaults(LiveContainer)

+ (instancetype)lcUserDefaults {
    static NSUserDefaults *defaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{        
        defaults = [NSUserDefaults standardUserDefaults];
    });
    return defaults;
}

+ (instancetype)lcSharedDefaults {
    return [self lcUserDefaults];
}

+ (NSString *)lcAppGroupPath {
    // 返回应用组路径
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *groupContainerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:@"group.com.example.livecontainer"];
    return groupContainerURL.path;
}

+ (NSString *)lcAppUrlScheme {
    // 返回应用URL Scheme
    return @"livecontainer";
}

+ (NSBundle *)lcMainBundle {
    return [NSBundle mainBundle];
}

+ (NSDictionary *)guestAppInfo {
    // 返回访客应用信息
    return @{};
}

+ (bool)isLiveProcess {
    // 检查是否为Live进程
    return YES;
}

+ (bool)isSharedApp {
    // 检查是否为共享应用
    return NO;
}

+ (NSString*)lcGuestAppId {
    // 返回访客应用ID
    return @"com.example.guestapp";
}

+ (bool)isSideStore {
    // 检查是否为SideStore
    return NO;
}

+ (bool)sideStoreExist {
    // 检查SideStore是否存在
    return NO;
}

@end