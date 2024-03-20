#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#include <rootless.h>

extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

@import SafariServices;

@interface PSUIPrefsListController : PSListController
@end

@interface UINavigationController (PL)
@property (readonly, nonatomic) UINavigationBar *navigationBar;
@end

@interface UINavigationBar (PL) <UIContextMenuInteractionDelegate>
@end

@interface UIView (PL)
- (UIViewController *)_viewControllerForAncestor;
@end

@interface SpringBoard: NSObject
+ (id)sharedApplication;
- (void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
@end

void setApplicationLanguage(NSString *languageCode) {
	if (languageCode == nil) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppleLanguages"]; // Setting this will force change of locale
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithObjects:languageCode, nil] forKey:@"AppleLanguages"];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)@"com.mtac.preference.localizer/relaunchSettings", nil, nil, true); // Send relaunch notification
	[[UIApplication sharedApplication] performSelector:@selector(suspend) withObject:nil afterDelay:0]; // Suspend Settings
}

NSArray *languageList() {
	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *settingsContent = [manager contentsOfDirectoryAtPath:@"/Applications/Preferences.app" error:nil];
	NSMutableArray *languageList = [NSMutableArray new];
	for (NSString *item in settingsContent) {
		if ([item.pathExtension isEqualToString:@"lproj"]) {
			[languageList addObject:[item stringByDeletingPathExtension]];
		}
	}
	return [languageList sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

%group Preferences
%hook UINavigationBar
- (void)didMoveToWindow {
	%orig;
	UIContextMenuInteraction *menuInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
	[self addInteraction:menuInteraction]; // Add interaction to all navigation bars
	NSLog(@"[+] PL DEBUG: List -> %@", languageList());
}
%new
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    UIContextMenuConfiguration *config = [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu* _Nullable(NSArray<UIMenuElement*>* _Nonnull suggestedActions) {
        NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
		NSMutableArray *languages = [NSMutableArray new];
		for (NSString *language in languageList()) {
			NSString *languageDisplayName = [locale localizedStringForLanguageCode:language];
			UIAction *languageAction = [UIAction actionWithTitle:[NSString stringWithFormat:@"%@ • %@", languageDisplayName, language] image:nil identifier:nil handler:^(__kindof UIAction *_Nonnull action) {
				setApplicationLanguage(language); 
			}];
			[languages addObject:languageAction];
		}
		
		UIMenu *languageList = [UIMenu menuWithTitle:@"Set Language" image:[UIImage systemImageNamed:@"globe"] identifier:nil options:0 children:languages];

		UIAction *resetAction = [UIAction actionWithTitle:@"Reset" image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"] identifier:nil handler:^(__kindof UIAction *_Nonnull action) {
			setApplicationLanguage(nil);
        }];
		resetAction.attributes = UIMenuElementAttributesDestructive;

        UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[languageList, resetAction]];
        return menu;
    }];
    return config;
}
%new
- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration {
    UIPreviewParameters *params = [[UIPreviewParameters alloc] init];
    params.backgroundColor = [UIColor clearColor];
    params.shadowPath = [UIBezierPath bezierPath];
    
    UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:self parameters:params];
    return preview;
}
%end
%end

%group SpringBoard
void relaunchSettings() {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		BKSTerminateApplicationForReasonAndReportWithDescription(@"com.apple.Preferences", 5, false, NULL); // Terminate Settings
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[((SpringBoard *)[%c(SpringBoard) sharedApplication]) launchApplicationWithIdentifier:@"com.apple.Preferences" suspended:0]; // Relaunch after delay
	});
}
%end

%ctor {
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	if ([bundleID isEqualToString:@"com.apple.Preferences"]) {
		%init(Preferences);
	} 
	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)relaunchSettings, (CFStringRef)@"com.mtac.preference.localizer/relaunchSettings", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
	}
}