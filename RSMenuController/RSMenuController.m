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
		self.layer.shouldRasterize = YES;
		self.layer.rasterizationScale = [UIScreen mainScreen].scale;
	} else {
		self.layer.shadowRadius = 0;
	}
}

@end

@implementation UIViewController (RSMenuController)

static char kRSMenuController;

- (RSMenuController *)menuController
{
	RSMenuController *controller = objc_getAssociatedObject(self, &kRSMenuController);
	if (!controller) {
		controller = self.parentViewController.menuController;
	}
	return controller;
}

- (void)setMenuController:(RSMenuController *)menuController
{
	objc_setAssociatedObject(self, &kRSMenuController, menuController, OBJC_ASSOCIATION_ASSIGN);
}

- (void)RS_hide:(NSTimeInterval)delay
{
	if (self.parentViewController) {
		[self removeFromParentViewController];
		if ([self isViewLoaded]) {
			[NSObject cancelPreviousPerformRequestsWithTarget:self.view selector:@selector(removeFromSuperview) object:nil];
			[self.view performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:delay];
		}
		RMLog(@"hide vc %@", self);
	}
}

- (void)RS_show:(UIView *)below
{
	if (![self parentViewController]) {
		UIView *superview = self.menuController.view;
		CGRect rect = superview.bounds;
		self.view.frame = rect;
		[self.view RS_showShadow:self.menuController.foldedShadowRadius];
		RMLog(@"show vc %@", self);
		[superview insertSubview:self.view belowSubview:below];
		[NSObject cancelPreviousPerformRequestsWithTarget:self.view selector:@selector(removeFromSuperview) object:nil];
		[self.menuController addChildViewController:self];
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


static NSString *ViewFrameKey = @"view.frame";

@interface RSMenuController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) id<UINavigationControllerDelegate> originalNavigationControllerDelegate;
@property (nonatomic, weak) UIViewController *currentFold;
@property (nonatomic, weak) UIViewController *panning;
@property (nonatomic, strong, readwrite) UIViewController *topViewController;

@property (nonatomic) CGFloat panOriginX;
@property (nonatomic) CGRect activeFrame;
@property (nonatomic) NSInteger topIndex;

@end

@implementation RSMenuController
{
	__weak RSPanLeftRightGestureRecognizer *_pan;
	__weak RSSwipeGestureRecognizer *_swipe;
	NSArray *_stops;
	CGFloat _invisibleMargin;
}

- (id)initWithRootViewController:(UINavigationController *)controller margin:(CGFloat)margin
{
	if (self = [super init]) {
		self.margin = margin;
		_rootViewController = controller;
		_rootViewController.menuController = self;
		[_rootViewController addObserver:self forKeyPath:ViewFrameKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
		_resistanceForce = 15.0f;
		_swipeDuration = .25f;
		_bounceDuration = .2f;
		_foldedShadowRadius = 10.f;
		_keepSpeed = YES;
	}
	return self;
}

- (void)dealloc
{
	[_rootViewController removeObserver:self forKeyPath:ViewFrameKey];
}

- (void)setMargin:(CGFloat)margin
{
	_margin = margin;
	_invisibleMargin = margin * 2;
	[self addRootViewControllerAnimationStop:-margin];
}

- (void)addRootViewControllerAnimationStop:(CGFloat)stop
{
	if (!_stops) _stops = @[@0, @(stop)];
	else {
		NSMutableArray *stops = [_stops mutableCopy];
		[stops addObject:@(stop)];
		_stops = stops;
	}
}

- (void)setLeftViewControllers:(NSArray *)leftViewControllers
{
	for (UIViewController *vc in _leftViewControllers) {
		vc.menuController = nil;
		[vc removeObserver:self forKeyPath:ViewFrameKey];
	}
	_leftViewControllers = leftViewControllers;
	for (UIViewController *vc in _leftViewControllers) {
		vc.menuController = self;
		[vc addObserver:self forKeyPath:ViewFrameKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
	}
}

- (void)setRightViewControllers:(NSArray *)rightViewControllers
{
	for (UIViewController *vc in _rightViewControllers) {
		vc.menuController = nil;
		[vc removeObserver:self forKeyPath:ViewFrameKey];
	}
	_rightViewControllers = rightViewControllers;
	for (UIViewController *vc in _rightViewControllers) {
		vc.menuController = self;
		[vc addObserver:self forKeyPath:ViewFrameKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
	}
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

- (void)setTopIndex:(NSInteger)topIndex
{
	static NSString *key = @"topIndex";
	[self willChangeValueForKey:key];
	_topIndex = topIndex;
	[self didChangeValueForKey:key];
	CGRect frame = self.view.bounds;
	if (topIndex == 0) {
		_swipe.enabled = NO;
		_activeFrame = frame;
	} else {
		_swipe.enabled = YES;
		frame.size.width -= _margin;
		if (topIndex > 0) frame.origin.x = _margin;
		_activeFrame = frame;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(UIViewController *)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:ViewFrameKey]) {
		CGFloat x = [change[NSKeyValueChangeNewKey] CGRectValue].origin.x;
		BOOL mostVisible = fabsf(x) < _invisibleMargin;
		if (object.view.userInteractionEnabled != mostVisible) {
			object.view.userInteractionEnabled = mostVisible;
		}
		if (object == _topViewController) {
			if (_topIndex == 0) {
				if (x > 0 && _leftViewControllers.count > 0) {
					[_leftViewControllers[0] RS_show:_topViewController.view];
					if (_rightViewControllers.count) [_rightViewControllers[0] RS_hide:self.swipeDuration];
				}
				if (x < 0 && _rightViewControllers.count > 0) {
					[_rightViewControllers[0] RS_show:_topViewController.view];
					if (_leftViewControllers.count) [_leftViewControllers[0] RS_hide:self.swipeDuration];
				}
			} else if (_topIndex < 0 && _leftViewControllers.count > -_topIndex) {
				if (x > 0) [_leftViewControllers[-_topIndex] RS_show:_topViewController.view];
				else [_leftViewControllers[-_topIndex] RS_hide:self.swipeDuration];
			} else if (_topIndex > 0 && _rightViewControllers.count > _topIndex) {
				if (x < 0) [_rightViewControllers[_topIndex] RS_show:_topViewController.view];
				else [_rightViewControllers[_topIndex] RS_hide:self.swipeDuration];
			}
		}
	}
}

#pragma mark - View Lifecycle
- (void)viewDidLoad
{
	[super viewDidLoad];
	_rootViewController.view.frame = self.view.bounds;
	[_rootViewController.view RS_showShadow:_foldedShadowRadius];

	[self.view addSubview:_rootViewController.view];
	[self addChildViewController:_rootViewController];
	self.topViewController = _rootViewController;
	
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

- (void)moveViewControllersAccordingToTopIndex:(NSInteger)topIndex except:(UIViewController *)except animated:(BOOL)animated completion:(void(^)(BOOL))completion
{
	CGFloat width = self.view.bounds.size.width;
	NSInteger index = abs(topIndex);
	RSMenuPanDirection direction;
	NSMutableArray *controllers = [NSMutableArray arrayWithObject:_rootViewController];
	if (topIndex > 0) {
		direction = RSMenuPanDirectionRight;
		[controllers addObjectsFromArray:_rightViewControllers];
	} else if (topIndex < 0) {
		direction = RSMenuPanDirectionLeft;
		[controllers addObjectsFromArray:_leftViewControllers];
	} else {
		direction = RSMenuPanDirectionNone;
	}
	
	UIViewController *viewController;
	
	for (int i = 0; i < controllers.count; i++) {
		viewController = controllers[i];
		if (viewController == except) continue;
		if (i == index - 1) {
			[self moveViewController:viewController toX:(width - _margin) * direction animated:animated completion:completion];
		} else if (i == index - 2) {
			[self moveViewController:viewController toX:(width - _margin / 3) * direction animated:animated completion:nil];
		} else if (i < index - 2) {
			[self moveViewController:viewController toX:direction == width * direction animated:animated completion:^(BOOL complete) {
				[viewController RS_hide:complete ? 0 : self.swipeDuration];
			}];
		} else {
			[self moveViewController:viewController toX:0 animated:animated completion:nil];
		}
	}
}

- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated completion:(dispatch_block_t)block
{
	if (_topViewController != controller) {
		if (_topViewController.isViewLoaded) {
			[_topViewController.view endEditing:YES];
		}
		[self moveViewControllersAccordingToTopIndex:[self indexOfController:controller] except:nil animated:animated completion:^(BOOL success) {
			if (block) block();
		}];
		self.topViewController = controller;
	}
}

- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated
{
	[self showViewController:controller animated:animated completion:nil];
}

- (NSInteger)indexOfController:(UIViewController *)controller
{
	if (controller == _rootViewController) return 0;
	if (self.leftViewControllers) {
		NSUInteger index = [self.leftViewControllers indexOfObject:controller];
		if (index != NSNotFound) {
			return -index - 1;
		}
	}
	if (self.rightViewControllers) {
		NSUInteger index = [self.rightViewControllers indexOfObject:controller];
		if (index != NSNotFound) {
			return index + 1;
		}
	}
	return NSNotFound;
}

- (void)setTopViewController:(UIViewController *)controller
{
	_topViewController = controller;
	if (!controller) return;
	
	RMLog(@"new top %@", _topViewController);
	if (controller == _rootViewController) {
		self.topIndex = 0;
		_currentFold = nil;
		_pan.directions = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
		RMLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
		
		return;
	}
	
	if (self.leftViewControllers) {
		NSUInteger index = [self.leftViewControllers indexOfObject:controller];
		if (index != NSNotFound) {
			self.topIndex = -index - 1;
			_pan.directions = 0;
			_swipe.direction = UISwipeGestureRecognizerDirectionLeft;
			if (index == 0) {
				_currentFold = _rootViewController;
			} else {
				_currentFold = self.leftViewControllers[index - 1];
			}
			RMLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
			return;
		}
	}
	
	if (self.rightViewControllers) {
		NSUInteger index = [self.rightViewControllers indexOfObject:controller];
		if (index != NSNotFound) {
			self.topIndex = index + 1;
			_pan.directions = 0;
			_swipe.direction = UISwipeGestureRecognizerDirectionRight;
			if (index == 0) {
				_currentFold = _rootViewController;
			} else {
				_currentFold = self.rightViewControllers[index - 1];
			}
			RMLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
			return;
		}
	}
}

- (void)moveViewController:(UIViewController *)controller toX:(CGFloat)destX animated:(NSUInteger)animated completion:(void (^)(BOOL complete))block
{
	if (!controller || !controller.isViewLoaded) {
		if (block) block(NO);
		return;
	}
	CGRect frame = controller.view.frame;
	
	if (frame.origin.x == destX) {
		if (block) block(NO);
		return;
	}
	if (animated) {
		self.view.userInteractionEnabled = NO;
		
		CGFloat x = frame.origin.x;
		frame.origin.x = destX;
		CGFloat width = frame.size.width;
		CGFloat span = ABS(x - destX) / width;
		BOOL bounce = animated > 1 && _bounceDuration && span > .5;
		CGFloat duration = _keepSpeed ? MAX(.5f, span) * _swipeDuration : _swipeDuration;
		CALayer *layer = controller.view.layer;
		
		[CATransaction begin];
		[CATransaction setCompletionBlock:^{
			self.view.userInteractionEnabled = YES;
			if (block) block(YES);
		}];
		
		destX += (width / 2);
		CGPoint pos = layer.position;
		
		NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
		[values addObject:[NSValue valueWithCGPoint:pos]];
		if (bounce) {
			duration += _bounceDuration * span;
			[values addObject:[NSValue valueWithCGPoint:CGPointMake(destX + 10, pos.y)]];
		}
		[values addObject:[NSValue valueWithCGPoint:CGPointMake(destX, pos.y)]];
		
		layer.position = CGPointMake(destX, pos.y);
		CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
		animation.calculationMode = @"cubic";
		animation.values = values;
		animation.duration = duration;
		[layer addAnimation:animation forKey:nil];
		
		[CATransaction commit];
		controller.view.frame = frame;
	} else {
		controller.view.frame = frame;
		if (block) block(YES);
	}
}

- (void)moveViewController:(UIViewController *)viewController toX:(CGFloat)destX animated:(NSUInteger)animated
{
	[self moveViewController:viewController toX:destX animated:animated completion:nil];
}

#pragma mark - GestureRecognizers
- (BOOL)panningLockedOnController:(UIViewController *)controller direction:(RSMenuPanDirection)dir
{
	if (dir == RSMenuPanDirectionRight) {
		return _topIndex < 0 && (-_topIndex >= _leftViewControllers.count || controller == _currentFold);
	}
	if (dir == RSMenuPanDirectionLeft) {
		return _topIndex > 0 && (_topIndex >= _rightViewControllers.count || controller == _currentFold);
	}
	return YES;
}

- (CGFloat)closestDest:(CGFloat)destX inStops:(NSArray *)stops
{
	CGFloat width = self.view.frame.size.width;
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
	return _destX;
}

- (void)endPanningOnViewController:(UIViewController *)controller velocity:(CGFloat)velocity
{
	velocity = velocity * _swipeDuration;
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
		destX = [self closestDest:destX inStops:controller == _rootViewController ? _stops : @[@0, @(-_margin)]];
	}
	if (destX != _panOriginX) {
		self.topViewController = [self viewControllerAtIndex:_topIndex + direction];
	}
	
	[self moveViewControllersAccordingToTopIndex:_topIndex except:controller animated:YES completion:nil];
	[self moveViewController:controller toX:destX animated:2];
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
		if (![self panEnabledOnViewController:_panning touch:nil]) {
			RMLog(@"pan disabled on controller %@", _panning);
			return;
		}
		CGPoint translation = [gesture translationInView:self.view];
		CGRect frame = _panning.view.frame;
		[gesture setTranslation:CGPointZero inView:self.view];
		
		CGFloat destX = translation.x + frame.origin.x;
		if (_panOriginX > 0) destX = MAX(0, destX);
		if (_panOriginX < 0) destX = MIN(0, destX);
		
		if (_panning != _rootViewController) {
			if (destX > _panOriginX) {
				if ([self panningLockedOnController:_panning direction:RSMenuPanDirectionRight]) {
					if (_topIndex < 0) {
						destX = frame.origin.x + translation.x / _resistanceForce;
					} else {
						destX = _panOriginX;
					}
				}
			} else if (destX < _panOriginX) {
				if ([self panningLockedOnController:_panning direction:RSMenuPanDirectionLeft]) {
					if (_topIndex > 0) {
						destX = frame.origin.x + translation.x / _resistanceForce;
					} else {
						destX = _panOriginX;
					}
				}
			}
		}
		frame.origin.x = destX;
		_panning.view.frame = frame;
		
	} else if (gesture.state == UIGestureRecognizerStateEnded) {
		if (_panning) {
			CGFloat velocity = [gesture velocityInView:self.view].x;
			__strong UIViewController *controller = _panning;
			_panning = nil;
			[self endPanningOnViewController:controller velocity:velocity];
		}
		[self notifyPanEnded];
	} else {
		[self notifyPanEnded];
		_panning = nil;
	}
}

- (void)tap:(UITapGestureRecognizer *)gesture
{
	RMLog(@"tap to show currentFold %@", _currentFold);
	[self notifyPanEnded];
	[self showViewController:_currentFold animated:YES];
}

#pragma mark - UIGestureRecognizerDelegate
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

- (void)notifyPanEnded
{
	UIViewController *vc = [_rootViewController topViewController];
	if ([vc respondsToSelector:@selector(panEnded)]) [(id<RSMenuPanEnabledProtocol>)vc panEnded];
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

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	return YES;
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
	_originalNavigationControllerDelegate = nil;
}

@end


@implementation RSMenuController (Utils)

- (void)showRootController
{
	[self showViewController:_rootViewController animated:NO completion:nil];
}

- (UIViewController *)oneViewControllerLeft
{
	return [self viewControllerAtIndex:_topIndex - 1];
}

- (UIViewController *)oneViewControllerRight
{
	return [self viewControllerAtIndex:_topIndex + 1];
}

- (void)hideRootViewController:(BOOL)animated
{
	[self hideRootViewController:animated completion:nil];
}

- (void)hideRootViewController:(BOOL)animated completion:(dispatch_block_t)completion
{
	CGFloat width = self.view.bounds.size.width;
	[self moveViewController:self.rootViewController toX:width animated:animated completion:^(BOOL finished) {
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
	[self moveViewController:self.rootViewController toX:width - self.margin animated:animated completion:^(BOOL finished) {
		if (completion) completion();
	}];
}

@end
