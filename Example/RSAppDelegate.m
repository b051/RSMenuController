//
//  RSAppDelegate.m
//  Example
//
//  Created by Rex Sheng on 5/22/13.
//  Copyright (c) 2013 Rex Sheng. All rights reserved.
//

#import "RSAppDelegate.h"
#import "RSMenuController.h"
#import "RSViewController.h"

@implementation RSAppDelegate
{
	RSMenuController *menuController;
}

- (void)openLeftMenu:(id)sender
{
	[menuController showViewController:[menuController oneViewControllerLeft] animated:YES completion:nil];
}

- (void)openRightMenu:(id)sender
{
	[menuController showViewController:[menuController oneViewControllerRight] animated:YES completion:nil];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
	
	UIViewController *(^viewController)(NSString *name) = ^(NSString *name) {
		RSViewController *viewController = [[RSViewController alloc] init];
		viewController.title = name;
		return viewController;
	};
	UIViewController *rootViewController = viewController(@"root");
	rootViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"LeftMenu" style:UIBarButtonItemStylePlain target:self action:@selector(openLeftMenu:)];
	rootViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"RightMenu" style:UIBarButtonItemStylePlain target:self action:@selector(openRightMenu:)];
	menuController = [[RSMenuController alloc] initWithRootViewController:[[UINavigationController alloc] initWithRootViewController:rootViewController] margin:60];
	[menuController addRootViewControllerAnimationStop:45];
	menuController.leftViewControllers = @[viewController(@"left0"), viewController(@"left1")];
	menuController.rightViewControllers = @[viewController(@"right0"), viewController(@"right1")];
	self.window.rootViewController = menuController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
