#import "LCSharedUtils.h"
#import "FoundationPrivate.h"
#import "UIKitPrivate.h"
#import "utils.h"
@import MachO;

@implementation LCSharedUtils

+ (NSString*) teamIdentifier {
    static NSString* ans = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if !TARGET_OS_SIMULATOR
        void* taskSelf = SecTaskCreateFromSelf(NULL);
        CFErrorRef error = NULL;
        CFTypeRef cfans = SecTaskCopyValueForEntitlement(taskSelf, CFSTR("com.apple.developer.team-identifier"), &error);
        if(CFGetTypeID(cfans) == CFStringGetTypeID()) {
            ans = (__bridge NSString*)cfans;
        }
        CFRelease(taskSelf);
#endif
        if(!ans) {
            // the above seems not to work if the device is jailbroken by Palera1n, so we use the public api one as backup
            // https://stackoverflow.com/a/11841898
            NSString *tempAccountName = @"bundleSeedID";
            NSDictionary *query = @{
                (__bridge NSString *)kSecClass : (__bridge NSString *)kSecClassGenericPassword,
                (__bridge NSString *)kSecAttrAccount : tempAccountName,
                (__bridge NSString *)kSecAttrService : @"",
                (__bridge NSString *)kSecReturnAttributes: (__bridge NSNumber *)kCFBooleanTrue,
            };
            CFDictionaryRef result = nil;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == errSecItemNotFound)
                status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == errSecSuccess) {
                status = SecItemDelete((__bridge CFDictionaryRef)query); // remove temp item
                NSDictionary *dict = (__bridge_transfer NSDictionary *)result;
                NSString *accessGroup = dict[(__bridge NSString *)kSecAttrAccessGroup];
                NSArray *components = [accessGroup componentsSeparatedByString:@"."];
                NSString *bundleSeedID = [[components objectEnumerator] nextObject];
                ans = bundleSeedID;
            }
        }
    });
    return ans;
}

+ (NSString*) appGroupID {
    static NSString* appGroupID = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 检查是否有开发者设置
        NSArray* possibleAppGroups = @[ @"group.livecontainer.main", @"group.com.livecontainer.main", @"group.com.livecontainer" ];
        for (NSString* group in possibleAppGroups) {
            if ([NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group]) {
                appGroupID = group;
                return;
            }
        }
        
        // if no possibleAppGroup is found, we detect app group from entitlement file
        // Cache app group after importing cert so we don't have to analyze executable every launch
        NSString *cached = [NSUserDefaults.lcUserDefaults objectForKey:@"LCAppGroupID"];
        if (cached && [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:cached]) {
            appGroupID = cached;
            return;
        }
        CFErrorRef error = NULL;
        void* taskSelf = SecTaskCreateFromSelf(NULL);
        CFTypeRef value = SecTaskCopyValueForEntitlement(taskSelf, CFSTR("com.apple.security.application-groups"), &error);
        CFRelease(taskSelf);
        
        if(!value) {
            return;
        }
        NSArray* appGroups = (__bridge NSArray *)value;
        if(appGroups.count > 0) {
            appGroupID = [appGroups firstObject];
        }
    });
    return appGroupID;
}

+ (NSURL*) appGroupPath {
    static NSURL *appGroupPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appGroupPath = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:[LCSharedUtils appGroupID]];
    });
    return appGroupPath;
}

+ (NSString *)certificatePassword {
    NSUserDefaults* nud = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupID]];
    if(!nud) {
        nud = NSUserDefaults.standardUserDefaults;
    }
    
    return [nud objectForKey:@"LCCertificatePassword"];
}

+ (BOOL)launchToGuestApp {
    NSString *urlScheme = nil;
    NSString *tsPath = [NSString stringWithFormat:@"%@/../_TrollStore", NSBundle.mainBundle.bundlePath];
    UIApplication *application = [NSClassFromString(@"UIApplication") sharedApplication];
    
    int tries = 1;
    if (!self.certificatePassword) {
        if (!access(tsPath.UTF8String, F_OK)) {
            urlScheme = @"apple-magnifier://enable-jit?bundle-id=%@";
        } else if ([application canOpenURL:[NSURL URLWithString:@"stikjit://"]]) {
            urlScheme = @"stikjit://enable-jit?bundle-id=%@";
        } else if ([application canOpenURL:[NSURL URLWithString:@"sidestore://"]]) {
            urlScheme = @"sidestore://sidejit-enable?bid=%@";
        }
    }
    if (!urlScheme) {
        tries = 2;
        urlScheme = [NSString stringWithFormat:@"%@://livecontainer-relaunch", NSUserDefaults.lcAppUrlScheme];
    }
    NSURL *launchURL = [NSURL URLWithString:[NSString stringWithFormat:urlScheme, NSBundle.mainBundle.bundleIdentifier]];

    if ([application canOpenURL:launchURL]) {
        //[UIApplication.sharedApplication suspend];
        for (int i = 0; i < tries; i++) {
            [application openURL:launchURL options:@{} completionHandler:NULL];
            sleep(1);
        }
        return YES;
    }
    return NO;
}

+ (BOOL)launchContainerWithBundleId:(NSString*)launchBundleId fromScheme:(NSString*)scheme {
    NSString *openUrl = nil;
    NSString *containerFolderName = nil;
    
    // Check for additional parameters in the URL
    if (scheme) {
        NSURLComponents *components = [NSURLComponents componentsWithString:scheme];
        if (components) {
            for (NSURLQueryItem *queryItem in components.queryItems) {
                if ([queryItem.name isEqualToString:@"open-url"]) {
                    NSString *encodedUrl = queryItem.value;
                    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedUrl options:0];
                    if (decodedData) {
                        openUrl = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
                    }
                } else if ([queryItem.name isEqualToString:@"container-folder-name"]) {
                    containerFolderName = queryItem.value;
                }
            }
        }
    }
    if(launchBundleId) {
        if (openUrl) {
            [NSUserDefaults.lcUserDefaults setObject:openUrl forKey:@"launchAppUrlScheme"];
        }
        
        // Attempt to restart LiveContainer with the selected guest app
        [NSUserDefaults.lcUserDefaults setObject:launchBundleId forKey:@"selected"];
        [NSUserDefaults.lcUserDefaults setObject:containerFolderName forKey:@"selectedContainer"];
        return [self launchToGuestApp];
    }
    
    return NO;
}

+ (void)setWebPageUrlForNextLaunch:(NSString*) urlString {
    [NSUserDefaults.lcUserDefaults setObject:urlString forKey:@"webPageToOpen"];
}

+ (NSURL*)containerLockPath {
    static dispatch_once_t once;
    static NSURL *infoPath;
    
    dispatch_once(&once, ^{
        infoPath = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer/containerLock.plist"];
    });
    return infoPath;
}

+ (BOOL)isLCSchemeInUse:(NSString*)lc {
    NSURL* infoPath = [self containerLockPath];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        return NO;
    }
    
    NSNumber* num57 = info[lc];
    if(![num57 isKindOfClass:NSNumber.class]) {
        return NO;
    }
    
    uint64_t val57 = [num57 longLongValue];
    audit_token_t token;
    token.val[5] = val57 >> 32;
    token.val[7] = val57 & 0xffffffff;
    
    errno = 0;
    csops_audittoken(token.val[5], 0, NULL, 0, &token);
    return errno != ESRCH;
}

+ (NSString*)getContainerUsingLCSchemeWithFolderName:(NSString*)folderName {
    NSURL* infoPath = [self containerLockPath];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        return nil;
    }
    
    NSDictionary* appUsageInfo = info[folderName];
    if (!appUsageInfo) {
        return nil;
    }
    uint64_t val57 = [appUsageInfo[@"auditToken57"] longLongValue];
    audit_token_t token;
    token.val[5] = val57 >> 32;
    token.val[7] = val57 & 0xffffffff;

    errno = 0;
    csops_audittoken(token.val[5], 0, NULL, 0, &token);
    if (errno == ESRCH) {
        [info removeObjectForKey:folderName];
        [info writeToFile:infoPath.path atomically:YES];
        return nil;
    }
    
    return folderName;
}

+ (void)cleanupUnusedContainers {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:[self containerLockPath].path];
    if (!info) {
        return;
    }
    
    for (NSString *folderName in [info.allKeys copy]) {
        if (![self isLCSchemeInUse:folderName]) {
            [info removeObjectForKey:folderName];
        }
    }
    
    [info writeToFile:[self containerLockPath].path atomically:YES];
}

+ (void)moveSharedDataBackToAppGroup {
    // move all apps in shared folder back
    NSString *docPath = [NSString stringWithFormat:@"%s/Documents", getenv("LC_HOME_PATH")];
    NSString *sharedAppDataFolderPath = [docPath stringByAppendingPathComponent:@"SharedData"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSURL *appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
    NSURL *docPathUrl = [NSURL fileURLWithPath:docPath];
    
    // Check if app group is accessible
    if (!appGroupFolder) {
        return;
    }
    
    // move all apps in shared folder back
    NSArray<NSString *> * sharedDataFoldersToMove = [fm contentsOfDirectoryAtPath:sharedAppDataFolderPath error:&error];
    
    // something went wrong with app group
    if(!appGroupFolder && sharedDataFoldersToMove.count > 0) {
        [NSUserDefaults.lcUserDefaults setObject:@"LiveContainer was unable to move the data of shared app back because LiveContainer cannot access app group. Please check JITLess diagnose page in LiveContainer settings for more information." forKey:@"error"];
        return;
    }
    
    for(int i = 0; i < [sharedDataFoldersToMove count]; ++i) {
        NSString* destPath = [appGroupFolder.path stringByAppendingPathComponent:[NSString stringWithFormat:@"Data/Application/%@", sharedDataFoldersToMove[i]]];
        if([fm fileExistsAtPath:destPath]) {
            [fm
             moveItemAtPath:[sharedAppDataFolderPath stringByAppendingPathComponent:sharedDataFoldersToMove[i]]
             toPath:[docPathUrl.path stringByAppendingPathComponent:[NSString stringWithFormat:@"FOLDER_EXISTS_AT_APP_GROUP_%@", sharedDataFoldersToMove[i]]]
             error:&error
            ];
            
        } else {
            [fm
             moveItemAtPath:[sharedAppDataFolderPath stringByAppendingPathComponent:sharedDataFoldersToMove[i]]
             toPath:destPath
             error:&error
            ];
        }
    }
    
}

+ (NSBundle*)findBundleWithBundleId:(NSString*)bundleId isSharedAppOut:(bool*)isSharedAppOut {
    NSString *docPath = [NSString stringWithFormat:@"%s/Documents", getenv("LC_HOME_PATH")];
    
    NSURL *appGroupFolder = nil;
    
    NSString *bundlePath = [NSString stringWithFormat:@"%@/Applications/%@", docPath, bundleId];
    NSBundle *appBundle = [[NSBundle alloc] initWithPath:bundlePath];
    // not found locally, let's look for the app in shared folder
    if (!appBundle) {
        appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
        
        bundlePath = [NSString stringWithFormat:@"%@/Applications/%@", appGroupFolder.path, bundleId];
        appBundle = [[NSBundle alloc] initWithPath:bundlePath];
        if(appBundle) {
            *isSharedAppOut = true;
        }
    } else {
        *isSharedAppOut = false;
    }
    return appBundle;
}

// This method is here for backward compatability, preferences is direcrly saved to app's preference folder.
+ (void)dumpPreferenceToPath:(NSString*)plistLocationTo dataUUID:(NSString*)dataUUID {
    NSFileManager* fm = [[NSFileManager alloc] init];
    NSError* error1;
    
    NSDictionary* preferences = [NSUserDefaults.lcUserDefaults objectForKey:dataUUID];
    if(!preferences) {
        return;
    }
    
    [fm createDirectoryAtPath:plistLocationTo withIntermediateDirectories:YES attributes:@{} error:&error1];
    for(NSString* identifier in preferences) {
        NSDictionary* preference = preferences[identifier];
        NSString *itemPath = [plistLocationTo stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", identifier]];
        if([preference count] == 0) {
            // Attempt to delete the file
            [fm removeItemAtPath:itemPath error:&error1];
            continue;
        }
        [preference writeToFile:itemPath atomically:YES];
    }
    [NSUserDefaults.lcUserDefaults removeObjectForKey:dataUUID];
}

+ (NSString*)findDefaultContainerWithBundleId:(NSString*)bundleId {
    // find app's default container
    NSURL* appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
    
    NSString* bundleInfoPath = [NSString stringWithFormat:@"%@/Applications/%@/LCAppInfo.plist", appGroupFolder.path, bundleId];
    NSMutableDictionary* infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:bundleInfoPath];
    if(!infoDict) {
        return nil;
    }
    
    NSString* containerFolderName = infoDict[@"containerFolderName"];
    if(!containerFolderName) {
        return nil;
    }
    
    // check if the container folder is still in use
    if([self isLCSchemeInUse:containerFolderName]) {
        return containerFolderName;
    }
    
    return nil;
}

@end
