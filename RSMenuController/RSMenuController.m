//
//  RSMenuController.m
//  version 1.0 beta1

//
//  Created by Rex Sheng on 7/9/12.
//  Copyright (c) 2012 lognllc.com. All rights reserved.
//

#import "RSMenuController.h"
#import <QuartzCore/QuartzCore.h>
#import "RSPanLeftRightGestureRecognizer.h"
#import "RSSwipeGestureRecognizer.h"
#import <objc/runtime.h>

@implementation UIView (RSMenuController)

- (void)RS_showShadow:(CGFloat)radius
{
	if (radius) {
		self.layer.shadowOpacity = 1;
		self.layer.shadowOffset = CGSizeZero;
		self.layer.shadowRadius = radius;
		self.layer.shadowColor = [UIColor blackColor].CGColor;
		self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
	} else {
		self.layer.shadowRadius = 0;
	}
}

@end

@implementation UIViewController (RSMenuController)

static char kRSMenuController;

@dynamic menuController;

- (RSMenuController *)menuController
{
	return objc_getAssociatedObject(self, &kRSMenuController);
}

- (void)setMenuController:(RSMenuController *)menuController
{
	if ([self respondsToSelector:@selector(viewControllers)]) {
		NSArray *viewControllers = [(UINavigationController *)self viewControllers];
		[viewControllers setValue:menuController forKeyPath:@"menuController"];
	}
	objc_setAssociatedObject(self, &kRSMenuController, menuController, OBJC_ASSOCIATION_ASSIGN);
}

- (void)RS_hide
{
	if ([self.view superview]) {
		[self.view removeFromSuperview];
		RMLog(@"hide vc %@", self);
	}
}

- (void)RS_show
{
	if (![self.view superview]) {
		UIView *superview = [self menuController].view;
		CGRect rect = superview.bounds;
		self.view.frame = rect;
		RMLog(@"show vc %@", self);
		[superview insertSubview:self.view atIndex:0];
	}
}

- (BOOL)RS_panEnabled:(BOOL *)panEnabled
{
	if (self.presentedViewController) {
		*panEnabled = NO;
		return YES;
	}
	if ([self respondsToSelector:@selector(panEnabled)]) {
		*panEnabled = [(id<RSMenuPanEnabledProtocol>)self panEnabled];
		return YES;
	}
	return NO;
}

@end

@interface RSMenuController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) RSSwipeGestureRecognizer *swipe;
@property (nonatomic, weak) RSPanLeftRightGestureRecognizer *pan;
@property (nonatomic, weak) UITapGestureRecognizer *tap;
@property (nonatomic, weak) id<UINavigationControllerDelegate> originalNavigationControllerDelegate;
@property (nonatomic, weak) UIViewController *currentFold;
@property (nonatomic, weak) UIViewController *panning;

@property (nonatomic) CGFloat margin;
@property (nonatomic) CGFloat panOriginX;
@property (nonatomic) CGRect activeFrame;
@property (nonatomic) NSInteger topIndex;

@end

@implementation RSMenuController
{
	BOOL reachLeftEnd;
	BOOL reachRightEnd;
	BOOL showingLeftView;
	BOOL showingRightView;
}

- (id)initWithRootViewController:(UINavigationController *)controller margin:(CGFloat)margin
{
	if (self = [super init]) {
		_margin = margin;
		_rootViewController = controller;
		_resistanceForce = 15.0f;
		_swipeDuration = .25f;
		_bounceDuration = .2f;
		_foldedShadowRadius = 10.f;
		_keepSpeed = YES;
	}
	return self;
}

- (void)setLeftViewControllers:(NSArray *)leftViewControllers
{
	for (UIViewController *vc in _leftViewControllers)
		vc.menuController = nil;
	_leftViewControllers = leftViewControllers;
	for (UIViewController *vc in _leftViewControllers)
		vc.menuController = self;
}

- (void)setRightViewControllers:(NSArray *)rightViewControllers
{
	for (UIViewController *vc in _rightViewControllers)
		vc.menuController = nil;
	_rightViewControllers = rightViewControllers;
	for (UIViewController *vc in _rightViewControllers)
		vc.menuController = self;
}

- (void)setRootViewControllers:(NSArray *)rootViewControllers
{
	[self setRootViewControllers:rootViewControllers animated:NO];
}

- (void)setRootViewControllers:(NSArray *)rootViewControllers animated:(BOOL)animated
{
	if (animated) {
		_originalNavigationControllerDelegate = _rootViewController.delegate;
		_rootViewController.delegate = self;
		[self moveViewController:_currentFold toX:self.view.bounds.size.width animated:YES completion:^(BOOL success) {
			if ([_rootViewController.viewControllers isEqualToArray:rootViewControllers]) {
				[self navigationController:_rootViewController didShowViewController:nil animated:YES];
			} else
				_rootViewController.viewControllers = rootViewControllers;
		}];
	} else {
		_rootViewController.viewControllers = rootViewControllers;
	}
}

- (NSArray *)rootViewControllers
{
	return [_rootViewController viewControllers];
}

#pragma mark - View Lifecycle
- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor clearColor];
	_rootViewController.view.frame = self.view.bounds;
	[self.view addSubview:_rootViewController.view];
	
	[self showViewController:_rootViewController animated:NO];
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
	_tap = tap;
	_tap.delegate = self;
	[self.view addGestureRecognizer:_tap];
	
	RSSwipeGestureRecognizer *swipe = [[RSSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipe:)];
	_swipe = swipe;
	_swipe.delegate = self;
	_swipe.minDistance = (self.view.bounds.size.width - _margin) * .3f;
	[self.view addGestureRecognizer:_swipe];
	RSPanLeftRightGestureRecognizer *pan = [[RSPanLeftRightGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
	_pan = pan;
	_pan.delegate = self;
	[self.view addGestureRecognizer:_pan];
	[_pan requireGestureRecognizerToFail:_swipe];
	[_tap requireGestureRecognizerToFail:_pan];
}

#pragma mark -
- (UIViewController *)viewControllerAtIndex:(NSInteger)index
{
	if (index == 0) return _rootViewController;
	else if (index > 0) {
		index--;
		if (self.rightViewControllers.count > index) {
			return (self.rightViewControllers)[index];
		} else {
			return nil;
		}
	} else {
		index = -index - 1;
		if (self.leftViewControllers.count > index) {
			return (self.leftViewControllers)[index];
		} else {
			return nil;
		}
	}
}

- (void)moveViewControllersAccordingToTopIndexAnimated:(BOOL)animated except:(UIViewController *)except
{
	CGFloat width = self.view.bounds.size.width;
	if (_topIndex > 0) {
		[self toggleViewControllersDirection:RSMenuPanDirectionRight];
		for (int i = 0; i < MAX(0, _topIndex - 2); i++) {
			UIViewController *viewController = [self viewControllerAtIndex:i];
			if (viewController != except) {
				[self moveViewController:viewController toX:-width animated:animated];
			}
		}
		UIViewController *viewController = [self viewControllerAtIndex:_topIndex - 1];
		if (viewController != except) {
			[self moveViewController:viewController toX:_margin - width animated:animated];
		}
		if (_topIndex - 2 >= 0) {
			UIViewController *viewController = [self viewControllerAtIndex:_topIndex - 2];
			if (viewController != except) {
				[self moveViewController:viewController toX:_margin / 3 - width animated:animated];
			}
		}
		for (int i = _topIndex + 1; i < self.leftViewControllers.count + 1; i++) {
			UIViewController *viewController = [self viewControllerAtIndex:i];
			if (viewController != except) {
				[self moveViewController:viewController toX:0 animated:NO];
			}
		}
	} else if (_topIndex < 0) {
		[self toggleViewControllersDirection:RSMenuPanDirectionLeft];
		for (int i = 0; i < MIN(0, -_topIndex - 2); i++) {
			UIViewController *viewController = [self viewControllerAtIndex:-i];
			if (viewController != except) {
				[self moveViewController:viewController toX:width animated:animated];
			}
		}
		UIViewController *viewController = [self viewControllerAtIndex:_topIndex + 1];
		if (viewController != except) {
			[self moveViewController:viewController toX:width - _margin animated:animated];
		}
		if (_topIndex + 2 <= 0) {
			UIViewController *viewController = [self viewControllerAtIndex:_topIndex + 2];
			if (viewController != except) {
				[self moveViewController:viewController toX:width - _margin / 3 animated:animated];
			}
		}
		for (int i = _topIndex - 1; i > -self.leftViewControllers.count - 1; i--) {
			UIViewController *viewController = [self viewControllerAtIndex:i];
			if (viewController != except) {
				[self moveViewController:viewController toX:0 animated:NO];
			}
		}
	} else {
		if (_rootViewController != except) {
			[self moveViewController:_rootViewController toX:0 animated:animated];
		}
	}
}

- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated
{
	if (_topViewController != controller) {
		RMLog(@"setTop in showViewController:animated:");
		[self setTopViewController:controller];
		[self moveViewControllersAccordingToTopIndexAnimated:animated except:_topViewController];
		[self moveViewController:_topViewController toX:0 animated:animated completion:^(BOOL finished) {
			[self reloadViewControllersIfNecessary:YES];
		}];
	}
}

- (void)hideRootViewController:(BOOL)animated
{
	CGFloat width = self.view.bounds.size.width;
	[self moveViewController:_rootViewController toX:width animated:animated completion:^(BOOL finished) {
		[self reloadViewControllersIfNecessary:YES];
	}];
}

- (void)showRootViewController:(BOOL)animated
{
	CGFloat width = self.view.bounds.size.width;
	[self moveViewController:_rootViewController toX:width - self.margin animated:animated completion:^(BOOL finished) {
		[self reloadViewControllersIfNecessary:YES];
	}];
}

- (void)setTopViewController:(UIViewController *)controller
{
	if (!controller) return;
	_topViewController = controller;
	_topViewController.view.userInteractionEnabled = YES;
	_topViewController.menuController = self;
	RMLog(@"new top %@", _topViewController);
	if (_topViewController == _rootViewController) {
		_topIndex = 0;
		
		reachLeftEnd = self.leftViewControllers.count == 0;
		reachRightEnd = self.rightViewControllers.count == 0;
		_currentFold = nil;
		_swipe.enabled = NO;
		_pan.directions = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
		_activeFrame = self.view.bounds;
		RMLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
		
		return;
	}
	
	if (self.leftViewControllers) {
		NSUInteger index = [self.leftViewControllers indexOfObject:_topViewController];
		if (index != NSNotFound) {
			reachLeftEnd = index == self.leftViewControllers.count - 1;
			reachRightEnd = NO;
			_topIndex = -index - 1;
			_swipe.enabled = YES;
			_pan.directions = 0;
			_swipe.direction = UISwipeGestureRecognizerDirectionLeft;
			CGRect frame = self.view.bounds;
			_activeFrame = CGRectMake(0, 0, frame.size.width - _margin, frame.size.height);
			if (index == 0) {
				_currentFold = _rootViewController;
			} else {
				_currentFold = (self.leftViewControllers)[index - 1];
			}
			_currentFold.view.userInteractionEnabled = NO;
			RMLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
			return;
		}
	}
	
	if (self.rightViewControllers) {
		NSUInteger index = [self.rightViewControllers indexOfObject:_topViewController];
		if (index != NSNotFound) {
			reachLeftEnd = NO;
			reachRightEnd = index == self.rightViewControllers.count - 1;
			_topIndex = index + 1;
			_swipe.enabled = YES;
			_pan.directions = 0;
			_swipe.direction = UISwipeGestureRecognizerDirectionRight;
			CGRect frame = self.view.bounds;
			_activeFrame = CGRectMake(_margin, 0, frame.size.width - _margin, frame.size.height);
			if (index == 0) {
				_currentFold = _rootViewController;
			} else {
				_currentFold = (self.rightViewControllers)[index - 1];
			}
			_currentFold.view.userInteractionEnabled = NO;
			RMLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
			return;
		}
	}
}

- (UIViewController *)oneViewControllerLeft
{
	return [self viewControllerAtIndex:_topIndex - 1];
}

- (UIViewController *)oneViewControllerRight
{
	return [self viewControllerAtIndex:_topIndex + 1];
}

- (void)showRootController
{
    [self showViewController:_rootViewController animated:NO];
}

- (void)_toggleViewControllersFromCurrentPosition:(NSArray *)array
{
	BOOL start = NO;
	for (UIViewController *vc in array) {
		if (vc != _topViewController) {
			if (start) {
				RMLog(@"hide vc %@", vc);
				[vc RS_hide];
			} else {
				[vc RS_show];
			}
		} else {
			start = YES;
			[vc RS_show];
		}
	}
}
#pragma mark - GestureRecognizers
- (void)toggleViewControllersDirection:(RSMenuPanDirection)dir
{
	showingRightView = dir == RSMenuPanDirectionRight;
	showingLeftView = dir == RSMenuPanDirectionLeft;
	if (dir == RSMenuPanDirectionLeft) {
		for (UIViewController *vc in _rightViewControllers) [vc RS_hide];
		//		[self _toggleViewControllersFromCurrentPosition:self.leftViewControllers];
		for (UIViewController *vc in _leftViewControllers) [vc RS_show];
	} else if (dir == RSMenuPanDirectionRight) {
		for (UIViewController *vc in _leftViewControllers) [vc RS_hide];
		//		[self _toggleViewControllersFromCurrentPosition:self.rightViewControllers];
		for (UIViewController *vc in _rightViewControllers) [vc RS_show];
	} else {
		for (UIViewController *vc in _leftViewControllers) [vc RS_hide];
		for (UIViewController *vc in _rightViewControllers) [vc RS_hide];
	}
}

- (void)reloadViewControllersIfNecessary:(BOOL)reset
{
	CGFloat x = _rootViewController.view.frame.origin.x;
	if (x > 0.0f) {
		return [self toggleViewControllersDirection:RSMenuPanDirectionLeft];
	}
	if (x < 0.0f) {
		return [self toggleViewControllersDirection:RSMenuPanDirectionRight];
	}
	if (reset) {
		[self toggleViewControllersDirection:RSMenuPanDirectionNone];
	}
}

- (void)moveViewController:(UIViewController *)viewController toX:(CGFloat)destX animated:(BOOL)animated completion:(void (^)(BOOL))block
{
	if (!viewController) {
		if (block) block(NO);
		return;
	}
	BOOL offScreen = ABS(destX) >= self.view.bounds.size.width;
	
	if (destX == 0 || offScreen) {
		[viewController.view RS_showShadow:0];
	} else {
		[viewController.view RS_showShadow:_foldedShadowRadius];
	}
	
	CGRect frame = viewController.view.frame;
	if (viewController == _topViewController && ((destX > 0.0f && reachLeftEnd) || (destX < 0.0f && reachRightEnd))) {
		if (frame.origin.x == 0.0f) {
			if (block) block(NO);
			return;
		}
		frame.origin.x = 0.0f;
	} else {
		if (frame.origin.x == destX) {
			if (block) block(NO);
			return;
		}
		frame.origin.x = destX;
	}
	if (animated) {
		self.view.userInteractionEnabled = NO;
		[UIView animateWithDuration:_swipeDuration animations:^{
			viewController.view.frame = frame;
		} completion:^(BOOL finished) {
			self.view.userInteractionEnabled = YES;
			_topViewController.view.userInteractionEnabled = YES;
			if (block) block(finished);
		}];
	} else {
		viewController.view.frame = frame;
		if (block) block(YES);
	}
}

- (void)moveViewController:(UIViewController *)viewController toX:(CGFloat)destX animated:(BOOL)animated
{
	[self moveViewController:viewController toX:destX animated:animated completion:nil];
}

- (BOOL)panningLocked:(RSMenuPanDirection)dir
{
	if (dir == RSMenuPanDirectionRight) {
		if (showingLeftView) {
			if (reachLeftEnd) return YES;
			if (_panning == _currentFold) {
				return YES;
			}
		} else if (showingRightView) {
			if (_panning == _topViewController) {
				return YES;
			}
		}
	} else {
		if (showingRightView) {
			if (reachRightEnd) return YES;
			RMLog(@"_panning %@, _currentFold %@", _panning, _currentFold);
			if (_panning == _currentFold) {
				return YES;
			}
		} else if (showingLeftView) {
			if (_panning == _topViewController) {
				return YES;
			}
		}
	}
	return NO;
}

- (void)finishAnimation:(CGFloat)velocity
{
	self.view.userInteractionEnabled = NO;
	CGFloat absVelocity = ABS(velocity);
	BOOL bounce = absVelocity > 50;
	
	CGFloat finalX = _panning.view.frame.origin.x;
	if (_panOriginX > 0) finalX = MAX(0, finalX);
	if (_panOriginX < 0) finalX = MIN(0, finalX);
	RMLog(@"finalX = %f", finalX);
	
	CGFloat width = _panning.view.frame.size.width;
	CGFloat destX;
	CGFloat limit = _panning == _topViewController ? .45f : .12f;
	
	if (finalX > _panOriginX) {
		//left to right swipe
		BOOL ignore = [self panningLocked:RSMenuPanDirectionRight];
		ignore = ignore || MAX(0, finalX - _panOriginX + velocity) / width < limit;
		if (ignore) {
			//ignored & reset
			destX = _panOriginX;
			bounce = NO;
		} else {
			if (_panning == _currentFold) {
				RMLog(@"setTop in finishAnimation:");
				[self setTopViewController:_currentFold];
			} else {
				RMLog(@"setTop in finishAnimation:");
				[self setTopViewController:[self oneViewControllerLeft]];
			}
			destX = showingLeftView ? (width - _margin) : 0;
		}
	} else if (_panOriginX > finalX) {
		//right to left
		BOOL ignore = [self panningLocked:RSMenuPanDirectionLeft];
		ignore = ignore || MAX(0, _panOriginX - finalX - velocity) / width < limit;
		if (ignore) {
			//ignored & reset
			destX = _panOriginX;
			bounce = NO;
		} else {
			if (_panning == _currentFold) {
				RMLog(@"setTop in finishAnimation:");
				[self setTopViewController:_currentFold];
			} else {
				RMLog(@"setTop in finishAnimation:");
				[self setTopViewController:[self oneViewControllerRight]];
			}
			destX = showingRightView ? (_margin - width) : 0;
		}
	} else {
		[self reloadViewControllersIfNecessary:NO];
		self.view.userInteractionEnabled = YES;
		return;
	}
	
	if (_panning != _rootViewController) {
		[self moveViewControllersAccordingToTopIndexAnimated:YES except:_panning];
	}
	
	CGFloat span = ABS(finalX - destX);
	
	CGFloat duration = _keepSpeed ? (span / width) * _swipeDuration : _swipeDuration;
	if (bounce) {
		duration = MIN(duration, span / absVelocity); // bouncing we'll use the current velocity to determine
	}
	//RMLog(@"%f => %f, destX = %f, duration = %f", _panOriginX, finalX, destX, duration);
	
	CALayer *layer = _panning.view.layer;
	[CATransaction begin];
	[CATransaction setCompletionBlock:^{
		[self reloadViewControllersIfNecessary:YES];
		[layer removeAllAnimations];
		self.view.userInteractionEnabled = YES;
	}];
	
	destX += (width / 2);
	CGPoint pos = layer.position;
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	
	NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
	[values addObject:[NSValue valueWithCGPoint:pos]];
	if (bounce) {
		duration += _bounceDuration;
		[values addObject:[NSValue valueWithCGPoint:CGPointMake(destX + 10, pos.y)]];
	}
	[values addObject:[NSValue valueWithCGPoint:CGPointMake(destX, pos.y)]];
	
	layer.position = CGPointMake(destX, pos.y);
	animation.calculationMode = @"cubic";
	animation.values = values;
	animation.duration = duration;
	animation.removedOnCompletion = NO;
	animation.fillMode = kCAFillModeForwards;
	[layer addAnimation:animation forKey:nil];
	[CATransaction commit];
}

- (void)swipe:(RSSwipeGestureRecognizer *)gesture
{
	//	RMLog(@"swipe %d", gesture.state);
	if (gesture.state == UIGestureRecognizerStateRecognized) {
		if (_topIndex < 0) {
			[self showViewController:[self oneViewControllerRight] animated:YES];
		} else if (_topIndex > 0) {
			[self showViewController:[self oneViewControllerLeft] animated:YES];
		}
	}
}

- (void)pan:(UIPanGestureRecognizer *)gesture
{
	if (gesture.state == UIGestureRecognizerStateBegan) {
		CGPoint loc = [gesture locationInView:self.view];
		if (CGRectContainsPoint(_currentFold.view.frame, loc)) {
			_panning = _currentFold;
		} else {
			_panning = _topViewController;
			[_topViewController.view endEditing:NO];
		}
		[_panning.view RS_showShadow:_foldedShadowRadius];
		RMLog(@"_top%s = %@ _currentFold = %@", _panning == _topViewController ? "(panning)" : "", _topViewController,  _currentFold);
		_panOriginX = _panning.view.frame.origin.x;
	} else if (gesture.state == UIGestureRecognizerStateChanged) {
		if (![self panEnabled]) return;
		CGPoint translation = [gesture translationInView:self.view];
		CGRect frame = _panning.view.frame;
		[gesture setTranslation:CGPointZero inView:self.view];
		
		CGFloat destX = translation.x + frame.origin.x;
		if (_panOriginX > 0) destX = MAX(0, destX);
		if (_panOriginX < 0) destX = MIN(0, destX);
		
		if (_panning == _rootViewController) {
			[self moveViewController:_rootViewController toX:destX animated:NO];
			[self reloadViewControllersIfNecessary:NO];
		} else {
			if (destX > _panOriginX) {
				if ([self panningLocked:RSMenuPanDirectionRight]) {
					if (showingLeftView) {
						destX = frame.origin.x + translation.x / _resistanceForce;
					} else {
						destX = _panOriginX;
					}
				}
			} else if (destX < _panOriginX) {
				if ([self panningLocked:RSMenuPanDirectionLeft]) {
					if (showingRightView) {
						destX = frame.origin.x + translation.x / _resistanceForce;
					} else {
						destX = _panOriginX;
					}
				}
			}
			frame.origin.x = destX;
			_panning.view.frame = frame;
		}
	} else if (gesture.state == UIGestureRecognizerStateEnded) {
		CGFloat velocity = [gesture velocityInView:self.view].x;
		[self finishAnimation:velocity];
	} else if (gesture.state == UIGestureRecognizerStateCancelled) {
		RMLog(@"pan canceled");
	}
}

- (void)tap:(UITapGestureRecognizer *)gesture
{
	RMLog(@"tap to show currentFold %@", _currentFold);
	[self showViewController:_currentFold animated:YES];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	if (gestureRecognizer == _tap) {
		return _currentFold && _currentFold.view.frame.origin.x == _currentFold.view.bounds.size.width - _margin;
	}
	return YES;
}

- (BOOL)panEnabled
{
	UIViewController *vc = _topViewController;
	BOOL panEnabled = YES;
	while ([vc isKindOfClass:[UINavigationController class]]) {
		if ([vc RS_panEnabled:&panEnabled])
			return panEnabled;
		vc = [(UINavigationController *)vc topViewController];
	}
	[vc RS_panEnabled:&panEnabled];
	return panEnabled;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
	BOOL inActiveFrame = CGRectContainsPoint(_activeFrame, [touch locationInView:self.view]);
	if (gestureRecognizer == _tap) {
		return !inActiveFrame;
	}
//	if (gestureRecognizer == _pan) {
//		if (inActiveFrame) {
//			return [self panEnabled];
//		}
//		return YES;
//	}
//	if (gestureRecognizer == _swipe) {
//		return !inActiveFrame;
//	}
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	if (gestureRecognizer == _pan) {
		if ([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && [NSStringFromClass(otherGestureRecognizer.class) hasPrefix:@"UI"]) {
			[otherGestureRecognizer requireGestureRecognizerToFail:gestureRecognizer];
		}
		return YES;
	}
	return NO;
}

#pragma mark - UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	[self showViewController:_rootViewController animated:YES];
	navigationController.delegate = _originalNavigationControllerDelegate;
}

@end
