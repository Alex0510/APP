//
//  APP-Bridging-Header.h
//  APP
//  of pxx917144686
//  统一的桥接头文件 - 包含所有Swift与Objective-C的桥接声明
//

#ifndef APP_Bridging_Header_h
#define APP_Bridging_Header_h

// iOS系统框架
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <stdbool.h>
#import <stdint.h>

// 导入Mach-O相关头文件
#import "MachOUtils.h"

// 核心头文件
#import "../动态库注入/Tweaks.h"
#import "../动态库注入/LCMachOUtils.h"
#import "../动态库注入/LCSharedUtils.h"
#import "../动态库注入/utils.h"
#import "../动态库注入/FoundationPrivate.h"
#import "../动态库注入/UIKitPrivate.h"

// litehook头文件
#import "../动态库注入/litehook/src/litehook.h"

// 声明核心函数
extern int LCPatchExecSlice(const char *path, struct mach_header_64 *header, bool doInject);
extern NSString *LCParseMachO(const char *path, bool readOnly, void (^callback)(const char *path, struct mach_header_64 *header, int fd, void* filePtr));
extern bool checkCodeSignature(const char* path);
extern void init_bypassDyldLibValidation(void);
extern void DyldHooksInit(bool hideLiveContainer, uint32_t spoofSDKVersion);

// 声明TweakLoader相关函数
extern void* dlopenBypassingLock(const char *path, int mode);
extern void* getCachedSymbol(NSString* symbolName, struct mach_header_64* header);
extern void saveCachedSymbol(NSString* symbolName, struct mach_header_64* header, uint64_t offset);

// 声明系统钩子初始化函数
extern void NUDGuestHooksInit(void);
extern void SecItemGuestHooksInit(void);
extern void NSFMGuestHooksInit(void);
extern void initDead10ccFix(void);

// 声明工具函数
extern void* getDyldBase(void);
extern struct dyld_all_image_infos *_alt_dyld_get_all_image_infos(void);
extern kern_return_t builtin_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot);

// 声明ARM64指令模拟函数
extern uint64_t aarch64_emulate_adrp(uint32_t instruction, uint64_t pc);
extern bool aarch64_emulate_add_imm(uint32_t instruction, uint32_t *dst, uint32_t *src, uint32_t *imm);
extern uint64_t aarch64_emulate_adrp_add(uint32_t instruction, uint32_t addInstruction, uint64_t pc);
extern uint64_t aarch64_emulate_adrp_ldr(uint32_t instruction, uint32_t ldrInstruction, uint64_t pc);

// 声明NSUserDefaults扩展
@interface NSUserDefaults (LiveContainer)
+ (instancetype)lcUserDefaults;
+ (instancetype)lcSharedDefaults;
+ (NSString *)lcAppGroupPath;
+ (NSString *)lcAppUrlScheme;
+ (NSBundle *)lcMainBundle;
+ (NSDictionary *)guestAppInfo;
+ (bool)isLiveProcess;
+ (bool)isSharedApp;
+ (bool)isSideStore;
+ (bool)sideStoreExist;
+ (NSString*)lcGuestAppId;
@end

// 声明NSBundle扩展
@interface NSBundle (LiveContainer)
- (instancetype)initWithPathForMainBundle:(NSString *)path;
@end

// 声明NSString扩展
@interface NSString (LiveContainer)
- (NSString *)lc_realpath;
@end

#endif /* APP_Bridging_Header_h */
