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

- (BOOL)RS_panEnabled:(BOOL *)panEnabled touch:(UITouch *)touch
{
	if (self.presentedViewController) {
		*panEnabled = NO;
		return YES;
	}
	if ([self respondsToSelector:@selector(panEnabledOnTouch:)]) {
		*panEnabled = [(id<RSMenuPanEnabledProtocol>)self panEnabledOnTouch:touch];
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

@property (nonatomic, weak) id<UINavigationControllerDelegate> originalNavigationControllerDelegate;
@property (nonatomic, weak) UIViewController *currentFold;
@property (nonatomic, weak) UIViewController *panning;

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
	__weak RSPanLeftRightGestureRecognizer *_pan;
	__weak RSSwipeGestureRecognizer *_swipe;
	NSArray *stops;
}

- (id)initWithRootViewController:(UINavigationController *)controller margin:(CGFloat)margin
{
	if (self = [super init]) {
		self.margin = margin;
		_rootViewController = controller;
		_resistanceForce = 15.0f;
		_swipeDuration = .25f;
		_bounceDuration = .2f;
		_foldedShadowRadius = 10.f;
		_keepSpeed = YES;
	}
	return self;
}

- (void)setMargin:(CGFloat)margin
{
	_margin = margin;
	[self addRootViewControllerAnimationStop:-margin];
}

- (void)addRootViewControllerAnimationStop:(CGFloat)stop
{
	if (!stops) stops = @[@0, @(stop)];
	else {
		NSMutableArray *_stops = [stops mutableCopy];
		[_stops addObject:@(stop)];
		stops = _stops;
	}
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
		CGFloat width = _currentFold.view.bounds.size.width;
		[self moveViewController:_currentFold toX:_topIndex > 0 ? -width : width animated:YES completion:^(BOOL success) {
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
	
	[self showViewController:_rootViewController animated:NO completion:nil];
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
	_tap = tap;
	_tap.delegate = self;
	[self.view addGestureRecognizer:_tap];
	
	RSSwipeGestureRecognizer *swipe = [[RSSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipe:)];
	swipe.delegate = self;
	swipe.minDistance = (self.view.bounds.size.width - _margin) * .3f;
	[self.view addGestureRecognizer:_swipe = swipe];
	
	RSPanLeftRightGestureRecognizer *pan = [[RSPanLeftRightGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
	pan.delegate = self;
	[self.view addGestureRecognizer:_pan = pan];
	
	[_pan requireGestureRecognizerToFail:_swipe];
	[_tap requireGestureRecognizerToFail:_pan];
}

#pragma mark -
- (UIViewController *)viewControllerAtIndex:(NSInteger)index
{
	if (index == 0) return _rootViewController;
	if (index > 0) {
		index--;
		if (self.rightViewControllers.count > index) {
			return self.rightViewControllers[index];
		} else {
			return nil;
		}
	}
	index = -index - 1;
	if (self.leftViewControllers.count > index) {
		return self.leftViewControllers[index];
	} else {
		return nil;
	}
}

- (void)moveViewControllersAccordingToTopIndexAnimated:(BOOL)animated except:(UIViewController *)except completion:(void(^)(BOOL))completion
{
	CGFloat width = self.view.bounds.size.width;
	if (_topIndex > 0) {
		[self toggleViewControllersDirection:RSMenuPanDirectionRight];
		for (int i = 0; i < MAX(0, _topIndex - 2); i++) {
			UIViewController *viewController = [self viewControllerAtIndex:i];
			if (viewController != except) {
				[self moveViewController:viewController toX:-width animated:animated completion:completion];
			}
		}
		UIViewController *viewController = [self viewControllerAtIndex:_topIndex - 1];
		if (viewController != except) {
			[self moveViewController:viewController toX:_margin - width animated:animated completion:completion];
		}
		if (_topIndex - 2 >= 0) {
			UIViewController *viewController = [self viewControllerAtIndex:_topIndex - 2];
			if (viewController != except) {
				[self moveViewController:viewController toX:_margin / 3 - width animated:animated completion:completion];
			}
		}
		for (int i = _topIndex + 1; i < self.leftViewControllers.count + 1; i++) {
			UIViewController *viewController = [self viewControllerAtIndex:i];
			if (viewController != except) {
				[self moveViewController:viewController toX:0 animated:NO completion:completion];
			}
		}
	} else if (_topIndex < 0) {
		[self toggleViewControllersDirection:RSMenuPanDirectionLeft];
		for (int i = 0; i < MIN(0, -_topIndex - 2); i++) {
			UIViewController *viewController = [self viewControllerAtIndex:-i];
			if (viewController != except) {
				[self moveViewController:viewController toX:width animated:animated completion:completion];
			}
		}
		UIViewController *viewController = [self viewControllerAtIndex:_topIndex + 1];
		if (viewController != except) {
			[self moveViewController:viewController toX:width - _margin animated:animated completion:completion];
		}
		if (_topIndex + 2 <= 0) {
			UIViewController *viewController = [self viewControllerAtIndex:_topIndex + 2];
			if (viewController != except) {
				[self moveViewController:viewController toX:width - _margin / 3 animated:animated completion:completion];
			}
		}
		for (int i = _topIndex - 1; i > -self.leftViewControllers.count - 1; i--) {
			UIViewController *viewController = [self viewControllerAtIndex:i];
			if (viewController != except) {
				[self moveViewController:viewController toX:0 animated:NO completion:completion];
			}
		}
	} else {
		if (_rootViewController != except) {
			[self moveViewController:_rootViewController toX:0 animated:animated completion:completion];
		}
	}
}

- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated completion:(dispatch_block_t)block
{
	if (_topViewController != controller) {
		RMLog(@"setTop in showViewController:animated:");
		[self setTopViewController:controller];
		[self moveViewControllersAccordingToTopIndexAnimated:animated except:_topViewController completion:^(BOOL success) {
			if (block) block();
		}];
		[self moveViewController:_topViewController toX:0 animated:animated completion:^(BOOL finished) {
			[self reloadViewControllersIfNecessary:YES];
		}];
	}
}

- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated
{
	[self showViewController:controller animated:animated completion:nil];
}

- (void)hideRootViewController:(BOOL)animated
{
	[self hideRootViewController:animated completion:nil];
}

- (void)hideRootViewController:(BOOL)animated completion:(dispatch_block_t)completion
{
	CGFloat width = self.view.bounds.size.width;
	[self moveViewController:_rootViewController toX:width animated:animated completion:^(BOOL finished) {
		[self reloadViewControllersIfNecessary:YES];
		if (completion) completion();
	}];
}

- (void)showRootViewController:(BOOL)animated
{
	[self showRootViewController:animated completion:nil];
}

- (void)showRootViewController:(BOOL)animated completion:(dispatch_block_t)completion
{
	CGFloat width = self.view.bounds.size.width;
	[self moveViewController:_rootViewController toX:width - self.margin animated:animated completion:^(BOOL finished) {
		[self reloadViewControllersIfNecessary:YES];
		if (completion) completion();
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
	[self showViewController:_rootViewController animated:NO completion:nil];
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
		for (UIViewController *vc in _leftViewControllers) [vc RS_show];
	} else if (dir == RSMenuPanDirectionRight) {
		for (UIViewController *vc in _leftViewControllers) [vc RS_hide];
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

- (BOOL)panningLockedOnController:(UIViewController *)controller direction:(RSMenuPanDirection)dir
{
	if (dir == RSMenuPanDirectionRight) {
		if (showingLeftView) {
			if (reachLeftEnd || controller == _currentFold) return YES;
		}
		return NO;
	}
	if (dir == RSMenuPanDirectionLeft) {
		if (showingRightView) {
			if (reachRightEnd || controller == _currentFold) return YES;
		}
		return NO;
	}
	return YES;
}

- (void)endAnimationOnViewController:(UIViewController *)controller destX:(CGFloat)destX
{
    self.view.userInteractionEnabled = NO;
	CGRect frame = controller.view.frame;
	CGFloat x = frame.origin.x;
	CGFloat width = frame.size.width;
	CGFloat span = ABS(x - destX) / width;
	BOOL bounce = _bounceDuration && span > .5;
	CGFloat duration = _keepSpeed ? MAX(.5f, span) * _swipeDuration : _swipeDuration;
	CALayer *layer = controller.view.layer;
	[CATransaction begin];
	[CATransaction setCompletionBlock:^{
		[self reloadViewControllersIfNecessary:YES];
		self.view.userInteractionEnabled = YES;
	}];
	
	destX += (width / 2);
	CGPoint pos = layer.position;
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	
	NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
	[values addObject:[NSValue valueWithCGPoint:pos]];
	if (bounce) {
		duration += _bounceDuration * span;
		[values addObject:[NSValue valueWithCGPoint:CGPointMake(destX + 10, pos.y)]];
	}
	[values addObject:[NSValue valueWithCGPoint:CGPointMake(destX, pos.y)]];
	
	layer.position = CGPointMake(destX, pos.y);
	animation.calculationMode = @"cubic";
	animation.values = values;
	animation.duration = duration;
	[layer addAnimation:animation forKey:nil];
	[CATransaction commit];
}

- (void)endPanningOnViewController:(UIViewController *)controller velocity:(CGFloat)velocity
{
	velocity = velocity * _swipeDuration;
	CGFloat width = controller.view.frame.size.width;
	CGFloat finalX = controller.view.frame.origin.x;
	CGFloat destX = finalX + velocity;
	
	if (_panOriginX < 0) destX = MIN(destX, 0);
	if (_panOriginX > 0) destX = MAX(destX, 0);
	BOOL toRight = destX > _panOriginX;
	BOOL toLeft = destX < _panOriginX;
	RSMenuPanDirection direction = toRight ? RSMenuPanDirectionRight : (toLeft ? RSMenuPanDirectionLeft : RSMenuPanDirectionNone);
	BOOL ignore = [self panningLockedOnController:controller direction:direction];
	if (ignore) {
		destX = _panOriginX;
	} else {
		__block CGFloat minDiff = CGFLOAT_MAX;
		__block	CGFloat _destX = 0;
		void(^pop)(CGFloat x) = ^(CGFloat x) {
			CGFloat diff = ABS(x - destX);
			if (minDiff > diff) {
				minDiff = diff;
				_destX = x;
			}
		};
		[stops enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			CGFloat x = [obj floatValue];
			if (x < 0) {
				if (self.leftViewControllers) pop(x + width);
				if (self.rightViewControllers) pop(-(x + width));
			} else {
				pop(x);
			}
		}];
		destX = _destX;
	}
	if (destX == _panOriginX) {
		[self setTopViewController:controller];
	} else {
		[self setTopViewController:[self viewControllerAtIndex:_topIndex + direction]];
	}
	
	if (controller != _rootViewController) {
		[self moveViewControllersAccordingToTopIndexAnimated:YES except:controller completion:nil];
	}
	
	[self endAnimationOnViewController:controller destX:destX];
}

- (void)swipe:(RSSwipeGestureRecognizer *)gesture
{
	if (gesture.state == UIGestureRecognizerStateRecognized) {
		if (_topIndex < 0) {
			[self showViewController:[self oneViewControllerRight] animated:YES completion:nil];
		} else if (_topIndex > 0) {
			[self showViewController:[self oneViewControllerLeft] animated:YES completion:nil];
		}
	}
}

- (void)pan:(RSPanLeftRightGestureRecognizer *)gesture
{
	if (gesture.state == UIGestureRecognizerStateBegan) {
	} else if (gesture.state == UIGestureRecognizerStateChanged) {
		if (!_panning) {
			CGPoint loc = gesture.startPoint;
			if (CGRectContainsPoint(_currentFold.view.frame, loc)) {
				_panning = _currentFold;
			} else {
				_panning = _topViewController;
				[_topViewController.view endEditing:NO];
			}
			[_panning.view RS_showShadow:_foldedShadowRadius];
			RMLog(@"_top%s = %@ _currentFold = %@", _panning == _topViewController ? "(panning)" : "", _topViewController,  _currentFold);
			_panOriginX = _panning.view.frame.origin.x;
		}
		if (![self panEnabledOnPanningViewController]) {
			RMLog(@"pan disabled on controller %@", _panning);
			return;
		}
		_panning.view.userInteractionEnabled = NO;
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
				if ([self panningLockedOnController:_panning direction:RSMenuPanDirectionRight]) {
					if (showingLeftView) {
						destX = frame.origin.x + translation.x / _resistanceForce;
					} else {
						destX = _panOriginX;
					}
				}
			} else if (destX < _panOriginX) {
				if ([self panningLockedOnController:_panning direction:RSMenuPanDirectionLeft]) {
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
		if (_panning) {
			CGFloat velocity = [gesture velocityInView:self.view].x;
			__strong UIViewController *controller = _panning;
			_panning = nil;
			[self endPanningOnViewController:controller velocity:velocity];
		}
	} else {
		_topViewController.view.userInteractionEnabled = YES;
		_panning = nil;
	}
}

- (void)tap:(UITapGestureRecognizer *)gesture
{
	RMLog(@"tap to show currentFold %@", _currentFold);
	[self showViewController:_currentFold animated:YES];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)panEnabledOnPanningViewController
{
	return [self panEnabledOnViewController:_panning touch:nil];
}

- (BOOL)panEnabledOnViewController:(UIViewController *)vc touch:(UITouch *)touch
{
	BOOL panEnabled = YES;
	while ([vc isKindOfClass:[UINavigationController class]]) {
		if ([vc RS_panEnabled:&panEnabled touch:touch])
			return panEnabled;
		vc = [(UINavigationController *)vc topViewController];
	}
	[vc RS_panEnabled:&panEnabled touch:touch];
	return panEnabled;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
	CGPoint loc = [touch locationInView:self.view];
	if (gestureRecognizer == _pan) {
		if (CGRectContainsPoint(_currentFold.view.frame, loc)) {
			return [self panEnabledOnViewController:_currentFold touch:touch];
		} else {
			return [self panEnabledOnViewController:_topViewController touch:touch];
		}
	}
	BOOL inActiveFrame = CGRectContainsPoint(_activeFrame, loc);
	return (gestureRecognizer == _tap) ^ inActiveFrame;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	if (gestureRecognizer == _pan) {
		if (([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && [NSStringFromClass(otherGestureRecognizer.class) hasPrefix:@"UI"]) || [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
			if ([otherGestureRecognizer.view isDescendantOfView:_rootViewController.view]) {
				[otherGestureRecognizer requireGestureRecognizerToFail:_pan];
			} else {
				return NO;
			}
		}
		return YES;
	}
	return NO;
}

#pragma mark - UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	[self showViewController:_rootViewController animated:YES completion:nil];
	navigationController.delegate = _originalNavigationControllerDelegate;
}

@end
