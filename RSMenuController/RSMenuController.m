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
#import <objc/message.h>

@implementation UIView (RS)

- (void)showShadow:(BOOL)val
{
	self.layer.shadowOpacity = val ? 1 : 0;
	if (val) {
		self.layer.cornerRadius = 4.0f;
		self.layer.shadowOffset = CGSizeZero;
		self.layer.shadowRadius = 5.0f;
		self.layer.shadowColor = [UIColor blackColor].CGColor;
		self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
	}
}

@end

@implementation UIViewController (RSMenuController)

static char kRSMenuController;

- (RSMenuController *)menuController
{
	return objc_getAssociatedObject(self, &kRSMenuController);
}

- (void)setMenuController:(RSMenuController *)menuController
{
	if ([self respondsToSelector:@selector(viewControllers)]) {
		id viewControllers = objc_msgSend(self, @selector(viewControllers));
		[viewControllers setValue:menuController forKeyPath:@"menuController"];
	}
	objc_setAssociatedObject(self, &kRSMenuController, menuController, OBJC_ASSOCIATION_ASSIGN);
}

- (void)RS_hide
{
	if ([self.view superview]) {
		BOOL iOS4 = !self.childViewControllers;
		if (iOS4) [self viewWillDisappear:NO];
		[self.view removeFromSuperview];
		NSLog(@"hide vc %@", self);
		if (iOS4) [self viewDidDisappear:NO];
	}
}

- (void)RS_show
{
	if (![self.view superview]) {
		UIView *superview = [self menuController].view;
		CGRect rect = superview.bounds;
		BOOL iOS4 = !self.childViewControllers;
		if (iOS4) [self viewWillAppear:NO];
		self.view.frame = rect;
		NSLog(@"show vc %@", self);
		[superview insertSubview:self.view atIndex:0];
		if (iOS4) [self viewDidAppear:NO];
	}
}

@end


@implementation RSMenuController
{
	CGFloat _margin;
	NSInteger _topIndex;
	UITapGestureRecognizer *_tap;
	RSSwipeGestureRecognizer *_swipe;
	UIPanGestureRecognizer *_pan;
	UIViewController *_currentFold;
	UIViewController *_panning;
	CGFloat _panOriginX;
	
	CGRect activeFrame;
	BOOL reachLeftEnd;
	BOOL reachRightEnd;
	BOOL showingLeftView;
	BOOL showingRightView;
}

@synthesize topViewController=_top;
@synthesize rightViewControllers=_right, leftViewControllers=_left;
@synthesize rootViewController=_root;
@synthesize resistanceForce, swipeDuration, bounceDuration, keepSpeed;

- (id)initWithRootViewController:(UIViewController *)controller margin:(CGFloat)margin
{
	if (self = [super init]) {
		_margin = margin;
		_root = controller;
		resistanceForce = 15.0f;
		swipeDuration = .25f;
		bounceDuration = .2f;
		keepSpeed = YES;
		_currentFold = nil;
		_top = nil;
		_panning = nil;
	}
	return self;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)setLeftViewControllers:(NSArray *)leftViewControllers
{
	for (UIViewController *vc in leftViewControllers) {
		vc.menuController = self;
	}
	_left = leftViewControllers;
}

- (void)setRightViewControllers:(NSArray *)rightViewControllers
{
	for (UIViewController *vc in rightViewControllers) {
		vc.menuController = self;
	}
	_right = rightViewControllers;
}

#pragma mark - View Lifecycle
- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor clearColor];
	BOOL iOS4 = !self.childViewControllers;
	if (iOS4) [_root viewWillAppear:NO];
	_root.view.frame = self.view.bounds;
	[self.view addSubview:_root.view];
	if (iOS4) [_root viewWillAppear:NO];
	
	[self showViewController:_root animated:NO];
	if (!_tap) {
		_tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
		_tap.delegate = self;
		[self.view addGestureRecognizer:_tap];
	}
	if (!_swipe) {
		_swipe = [[RSSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipe:)];
		_swipe.delegate = self;
		_swipe.minDistance = (self.view.bounds.size.width - _margin) * .3f;
		//_swipe.delaysTouchesBegan = YES;
		[self.view addGestureRecognizer:_swipe];
	}
	if (!_pan) {
		_pan = [[RSPanLeftRightGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
		_pan.delegate = self;
		[self.view addGestureRecognizer:_pan];
	}
	[_pan requireGestureRecognizerToFail:_swipe];
	[_tap requireGestureRecognizerToFail:_pan];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	_tap = nil;
	_pan = nil;
	_swipe = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -
- (UIViewController *)viewControllerAtIndex:(NSInteger)index
{
	if (index == 0) return _root;
	else if (index > 0) {
		index--;
		if (self.rightViewControllers.count > index) {
			return [self.rightViewControllers objectAtIndex:index];
		} else {
			return nil;
		}
	} else {
		index = -index - 1;
		if (self.leftViewControllers.count > index) {
			return [self.leftViewControllers objectAtIndex:index];
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
		if (_root != except) {
			[self moveViewController:_root toX:0 animated:animated];
		}
	}
}

- (void)showViewController:(UIViewController *)controller animated:(BOOL)animated
{
	if (_top != controller) {
		NSLog(@"setTop in showViewController:animated:");
		[self setTopViewController:controller];
		[self moveViewControllersAccordingToTopIndexAnimated:animated except:_top];
		[self moveViewController:_top toX:0 animated:animated completion:^(BOOL finished) {
			[self reloadViewControllersIfNecessary];
		}];
	}
}

- (void)setTopViewController:(UIViewController *)controller
{
	if (!controller) return;
	_top = controller;
	_top.view.userInteractionEnabled = YES;
	_top.menuController = self;
	NSLog(@"new top %@", _top);
	if (_top == _root) {
		_topIndex = 0;
		
		reachLeftEnd = self.leftViewControllers.count == 0;
		reachRightEnd = self.rightViewControllers.count == 0;
		_currentFold = nil;
		_swipe.enabled = NO;
		activeFrame = self.view.bounds;
		NSLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
		
		return;
	}
	
	if (self.leftViewControllers) {
		NSUInteger index = [self.leftViewControllers indexOfObject:_top];
		if (index != NSNotFound) {
			reachLeftEnd = index == self.leftViewControllers.count - 1;
			reachRightEnd = NO;
			_topIndex = -index - 1;
			_swipe.enabled = YES;
			_swipe.direction = UISwipeGestureRecognizerDirectionLeft;
			CGRect frame = self.view.bounds;
			activeFrame = CGRectMake(0, 0, frame.size.width - _margin, frame.size.height);
			if (index == 0) {
				_currentFold = _root;
			} else {
				_currentFold = [self.leftViewControllers objectAtIndex:index - 1];
			}
			_currentFold.view.userInteractionEnabled = NO;
			NSLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
			return;
		}
	}
	
	if (self.rightViewControllers) {
		NSUInteger index = [self.rightViewControllers indexOfObject:_top];
		if (index != NSNotFound) {
			reachLeftEnd = NO;
			reachRightEnd = index == self.rightViewControllers.count - 1;
			_topIndex = index + 1;
			_swipe.enabled = YES;
			_swipe.direction = UISwipeGestureRecognizerDirectionRight;
			CGRect frame = self.view.bounds;
			activeFrame = CGRectMake(_margin, 0, frame.size.width - _margin, frame.size.height);
			if (index == 0) {
				_currentFold = _root;
			} else {
				_currentFold = [self.rightViewControllers objectAtIndex:index - 1];
			}
			_currentFold.view.userInteractionEnabled = NO;
			NSLog(@"new topIndex %d currentFold %@", _topIndex, _currentFold);
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
    [self showViewController:_root animated:NO];
}

- (void)hideCurrentFold:(BOOL)hide
{
	CGRect frame = self.view.bounds;
    [self moveViewController:_currentFold toX:hide ? frame.size.width : frame.size.width - _margin animated:YES];
}

- (void)_toggleViewControllersFromCurrentPosition:(NSArray *)array
{
	BOOL start = NO;
	for (UIViewController *vc in array) {
		if (vc != _top) {
			if (start) {
				NSLog(@"hide vc %@", vc);
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
		for (UIViewController *vc in self.rightViewControllers) [vc RS_hide];
//		[self _toggleViewControllersFromCurrentPosition:self.leftViewControllers];
		for (UIViewController *vc in self.leftViewControllers) [vc RS_show];
	} else if (dir == RSMenuPanDirectionRight) {
		for (UIViewController *vc in self.leftViewControllers) [vc RS_hide];
//		[self _toggleViewControllersFromCurrentPosition:self.rightViewControllers];
		for (UIViewController *vc in self.rightViewControllers) [vc RS_show];
	} else {
		for (UIViewController *vc in self.leftViewControllers) [vc RS_hide];
		for (UIViewController *vc in self.rightViewControllers) [vc RS_hide];
	}
}

- (void)reloadViewControllersIfNecessary
{
	CGFloat x = _root.view.frame.origin.x;
	if (x > 0.0f) {
		[self toggleViewControllersDirection:RSMenuPanDirectionLeft];
	} else if (x < 0.0f) {
		[self toggleViewControllersDirection:RSMenuPanDirectionRight];
	} else {
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
		[viewController.view showShadow:NO];
	} else {
		[viewController.view showShadow:YES];
	}
	
	CGRect frame = viewController.view.frame;
	if (viewController == _top && ((destX > 0.0f && reachLeftEnd) || (destX < 0.0f && reachRightEnd))) {
		if (frame.origin.x == 0.0f) return;
		frame.origin.x = 0.0f;
	} else {
		if (frame.origin.x == destX) return;
		frame.origin.x = destX;
	}
	if (animated) {
		self.view.userInteractionEnabled = NO;
		[UIView animateWithDuration:swipeDuration animations:^{
			viewController.view.frame = frame;
		} completion:^(BOOL finished) {
			self.view.userInteractionEnabled = YES;
			_top.view.userInteractionEnabled = YES;
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
			if (_panning == _top) {
				return YES;
			}
		}
	} else {
		if (showingRightView) {
			if (reachRightEnd) return YES;
			NSLog(@"_panning %@, _currentFold %@", _panning, _currentFold);
			if (_panning == _currentFold) {
				return YES;
			}
		} else if (showingLeftView) {
			if (_panning == _top) {
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
	NSLog(@"finalX = %f", finalX);
	
	CGFloat width = _panning.view.frame.size.width;
	CGFloat destX;
	CGFloat limit = _panning == _top ? .45f : .12f;
	
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
				NSLog(@"setTop in finishAnimation:");
				[self setTopViewController:_currentFold];
			} else {
				NSLog(@"setTop in finishAnimation:");
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
				NSLog(@"setTop in finishAnimation:");
				[self setTopViewController:_currentFold];
			} else {
				NSLog(@"setTop in finishAnimation:");
				[self setTopViewController:[self oneViewControllerRight]];
			}
			destX = showingRightView ? (_margin - width) : 0;
		}
	} else {
		[self reloadViewControllersIfNecessary];
		self.view.userInteractionEnabled = YES;
		return;
	}
	
	if (_panning != _root) {
		[self moveViewControllersAccordingToTopIndexAnimated:YES except:_panning];
	}
	
	CGFloat span = ABS(finalX - destX);
	
	CGFloat duration = keepSpeed ? (span / width) * swipeDuration : swipeDuration;
	if (bounce) {
		duration = MIN(duration, span / absVelocity); // bouncing we'll use the current velocity to determine
	}
	//NSLog(@"%f => %f, destX = %f, duration = %f", _panOriginX, finalX, destX, duration);
	
	CALayer *layer = _panning.view.layer;
	[CATransaction begin];
	[CATransaction setCompletionBlock:^{
		[self reloadViewControllersIfNecessary];
		[layer removeAllAnimations];
		self.view.userInteractionEnabled = YES;
	}];
	
	destX += (width / 2);
	CGPoint pos = layer.position;
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	
	NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
	[values addObject:[NSValue valueWithCGPoint:pos]];
	if (bounce) {
		duration += bounceDuration;
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
	//	NSLog(@"swipe %d", gesture.state);
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
			_panning = _top;
			[_top.view endEditing:NO];
		}
		[_panning.view showShadow:YES];
		NSLog(@"_top%s = %@ _currentFold = %@", _panning == _top ? "(panning)" : "", _top,  _currentFold);
		_panOriginX = _panning.view.frame.origin.x;
	} else if (gesture.state == UIGestureRecognizerStateChanged) {
		CGPoint translation = [gesture translationInView:self.view];
		CGRect frame = _panning.view.frame;
		[gesture setTranslation:CGPointZero inView:self.view];
		
		CGFloat destX = translation.x + frame.origin.x;
		if (_panOriginX > 0) destX = MAX(0, destX);
		if (_panOriginX < 0) destX = MIN(0, destX);
		
		if (_panning == _root) {
			[self moveViewController:_root toX:destX animated:NO];
			[self reloadViewControllersIfNecessary];
		} else {
			if (destX > _panOriginX) {
				if ([self panningLocked:RSMenuPanDirectionRight]) {
					if (showingLeftView) {
						destX = frame.origin.x + translation.x / resistanceForce;
					} else {
						destX = _panOriginX;
					}
				}
			} else if (destX < _panOriginX) {
				if ([self panningLocked:RSMenuPanDirectionLeft]) {
					if (showingRightView) {
						destX = frame.origin.x + translation.x / resistanceForce;
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
		NSLog(@"pan canceled");
	}
}

- (void)tap:(UITapGestureRecognizer *)gesture
{
	NSLog(@"tap to show currentFold %@", _currentFold);
	[self showViewController:_currentFold animated:YES];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	if (gestureRecognizer == _tap) {
        // if the _currentFold is hidden on the right, do nothing
        if (_currentFold.view.frame.origin.x > _currentFold.view.bounds.size.width - _margin) {
            return NO;
        }
		if (!_currentFold) return NO;
		return !CGRectContainsPoint(activeFrame, [_tap locationInView:self.view]);
	} else if (gestureRecognizer == _pan) {
		CGPoint loc = [_pan locationInView:self.view];
		if (CGRectContainsPoint(activeFrame, loc)) {
			UIViewController *vc = _top;
			while ([vc isKindOfClass:[UINavigationController class]]) {
				if (vc.presentedViewController) return NO;
				if ([vc respondsToSelector:@selector(panEnabled)]) {
					return ((BOOL (*)(id, SEL))objc_msgSend)(vc, @selector(panEnabled));
				}
				vc = [(UINavigationController *)vc topViewController];
			}
			if (vc.presentedViewController) return NO;
			if ([vc respondsToSelector:@selector(panEnabled)]) {
				return ((BOOL (*)(id, SEL))objc_msgSend)(vc, @selector(panEnabled));
			}
		}
		return YES;
	} else if (gestureRecognizer == _swipe) {
		CGPoint loc = [_swipe locationInView:self.view];
		if (CGRectContainsPoint(activeFrame, loc)) {
			return YES;
		}
		return NO;
	}
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	if (gestureRecognizer == _tap) {
		return YES;
	}
	return NO;
}

@end