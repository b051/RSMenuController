//
//  RSMenuController.h
//  version 1.0 beta1
//
//  Created by Rex Sheng on 7/9/12.
//  Copyright (c) 2012 lognllc.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifndef RS_ENABLE_MENU_CONTROLLER_LOGGING
#ifdef DEBUG
#define RS_ENABLE_MENU_CONTROLLER_LOGGING 1
#else
#define RS_ENABLE_MENU_CONTROLLER_LOGGING 0
#endif
#endif

#if RS_ENABLE_MENU_CONTROLLER_LOGGING != 0
#define RMLog(...) NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, [NSString stringWithFormat:__VA_ARGS__])
#else
#define RMLog(...) ((void)0)
#endif

typedef NS_ENUM(NSInteger, RSMenuPanDirection) {
	RSMenuPanDirectionLeft = 1,
	RSMenuPanDirectionRight = -1,
	RSMenuPanDirectionNone = 0
};

@protocol RSMenuPanEnabledProtocol <NSObject>

@optional
- (BOOL)panEnabled;
- (void)panEnded;
- (BOOL)panEnabledOnTouch:(UITouch *)touch;

@end

@interface RSMenuController : UIViewController

- (id)initWithRootViewController:(UINavigationController *)controller margin:(CGFloat)margin;
- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated;
- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated completion:(dispatch_block_t)block;
- (UIViewController *)oneViewControllerLeft;
- (UIViewController *)oneViewControllerRight;

- (void)setRootViewControllers:(NSArray *)rootViewControllers animated:(BOOL)animated;
- (void)moveViewController:(UIViewController *)viewController toX:(CGFloat)destX animated:(BOOL)animated;
- (void)moveViewController:(UIViewController *)viewController toX:(CGFloat)destX animated:(BOOL)animated completion:(void (^)(BOOL))block;
- (void)addRootViewControllerAnimationStop:(CGFloat)stop;

- (void)showRootViewController:(BOOL)animated;
- (void)showRootViewController:(BOOL)animated completion:(dispatch_block_t)completion;
- (void)hideRootViewController:(BOOL)animated;
- (void)hideRootViewController:(BOOL)animated completion:(dispatch_block_t)completion;

@property (nonatomic, copy) NSArray *rootViewControllers;
@property (nonatomic, copy) NSArray *leftViewControllers;
@property (nonatomic, copy) NSArray *rightViewControllers;

@property (nonatomic, strong, readonly) UIViewController *topViewController;
@property (nonatomic, strong) UINavigationController *rootViewController;

@property (nonatomic, assign) CGFloat resistanceForce;
@property (nonatomic, assign) NSTimeInterval swipeDuration;
@property (nonatomic, assign) CGFloat foldedShadowRadius;
@property (nonatomic, assign) CGFloat bounceDuration;
@property (nonatomic, assign) BOOL keepSpeed;
@property (nonatomic, readonly) CGFloat margin;

@property (nonatomic, weak, readonly) UIGestureRecognizer *swipe;
@property (nonatomic, weak, readonly) UIPanGestureRecognizer *pan;
@property (nonatomic, weak, readonly) UITapGestureRecognizer *tap;

@end


@interface UIViewController (RSMenuController)

@property (nonatomic, weak, readonly) RSMenuController *menuController;

@end
