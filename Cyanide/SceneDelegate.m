//
//  SceneDelegate.m
//  Cyanide
//
//  Created by seo on 3/24/26.
//

#import "SceneDelegate.h"
#import "SettingsViewController.h"
#import "UpdateChecker.h"

@interface SceneDelegate ()
@property (nonatomic, assign) BOOL didSelectInitialTab;

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UITabBarController *tab = (UITabBarController *)self.window.rootViewController;
    if ([tab isKindOfClass:UITabBarController.class] && tab.viewControllers.count > 1) {
        // iOS 26+: collapse the floating tab bar into a pill while the user
        // scrolls down, expand it back on scroll up. Falls through silently
        // on older OSes since the selector won't be present.
        SEL minSel = NSSelectorFromString(@"setTabBarMinimizeBehavior:");
        if ([tab respondsToSelector:minSel]) {
            NSMethodSignature *sig = [tab methodSignatureForSelector:minSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            inv.target = tab;
            inv.selector = minSel;
            NSInteger onScrollDown = 1; // UITabBarMinimizeBehavior.onScrollDown
            [inv setArgument:&onScrollDown atIndex:2];
            [inv invoke];
        }
    }
}

- (void)selectInitialTabIfNeeded {
    if (self.didSelectInitialTab) return;
    UITabBarController *tab = (UITabBarController *)self.window.rootViewController;
    if (![tab isKindOfClass:UITabBarController.class] || tab.viewControllers.count == 0) return;
    self.didSelectInitialTab = YES;
    tab.selectedIndex = 0; // Installer tab (no Log tab anymore)
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)runUpdateCheck {
    UITabBarController *tab = (UITabBarController *)self.window.rootViewController;
    if (![tab isKindOfClass:UITabBarController.class]) return;
    // UpdateChecker walks `presentedViewController` to find the topmost VC and
    // presents from there, so if the privacy alert is up, the update prompt
    // stacks on top — independent of consent state.
    [[UpdateChecker shared] checkForUpdatesIfNeededFrom:tab];
}

- (void)showPrivacyConsentIfNeeded {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud boolForKey:@"cyanide.privacy.logConsentShown"]) return;
    UIViewController *root = self.window.rootViewController;
    if (!root) return;
    NSString *msg = @"Cyanide is an experimental exploit chain — the app can be unstable, SpringBoard may respawn, and tweaks may misbehave. Automatic log collection helps diagnose what went wrong.\n\nAfter each run, Cyanide can upload a diagnostic log containing: chain stage timing, error messages, device model, and iOS version. No personal data beyond this is collected.\n\nLogs go to a private Cloudflare R2 bucket owned by @zeroxjf and expire after 30 days. Toggle anytime in Settings → About.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cyanide Log Collection"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [ud setBool:YES forKey:kSettingsLogUploadEnabled];
        [ud setBool:YES forKey:@"cyanide.privacy.logConsentShown"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Decline" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        [ud setBool:NO forKey:kSettingsLogUploadEnabled];
        [ud setBool:YES forKey:@"cyanide.privacy.logConsentShown"];
    }]];
    [root presentViewController:alert animated:YES completion:nil];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    [self selectInitialTabIfNeeded];
    settings_application_did_become_active();
    // Independent paths: privacy consent prompt (one-time) and update check
    // (every foreground, deduped per-process by UpdateChecker.didCheckThisLaunch).
    // The two can stack on first launch — that's intentional, an available
    // update shouldn't be hidden behind a privacy preference.
    [self showPrivacyConsentIfNeeded];
    [self runUpdateCheck];
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    settings_application_will_enter_foreground();
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    settings_application_did_enter_background();
}


@end
