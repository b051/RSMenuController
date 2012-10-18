//
//  RSMenuController.h
//  version 1.0 beta1
//
//  Created by Rex Sheng on 7/9/12.
//  Copyright (c) 2012 lognllc.com. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
	RSMenuPanDirectionLeft = 0,
	RSMenuPanDirectionRight,
	RSMenuPanDirectionNone
} RSMenuPanDirection;

@interface RSMenuController : UIViewController

- (id)initWithRootViewController:(UINavigationController *)controller margin:(CGFloat)margin;
- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated;
- (UIViewController *)oneViewControllerLeft;
- (UIViewController *)oneViewControllerRight;

- (void)setRootViewControllers:(NSArray *)rootViewControllers animated:(BOOL)animated;

@property (nonatomic, copy) NSArray *rootViewControllers;
@property (nonatomic, copy) NSArray *leftViewControllers;
@property (nonatomic, copy) NSArray *rightViewControllers;

@property (nonatomic, readonly) UIViewController *topViewController;
@property (nonatomic, readonly) UINavigationController *rootViewController;

@property (nonatomic, assign) CGFloat resistanceForce;
@property (nonatomic, assign) CGFloat swipeDuration;
@property (nonatomic, assign) CGFloat foldedShadowRadius;
@property (nonatomic, assign) CGFloat bounceDuration;
@property (nonatomic, assign) BOOL keepSpeed;

@end


@interface UIViewController (RSMenuController)

- (RSMenuController *)menuController;

@end