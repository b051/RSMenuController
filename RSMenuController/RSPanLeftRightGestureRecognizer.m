//
//  NAPanLeftRightGestureRecognizer.m
//  version 1.0 beta1
//
//  Created by Rex Sheng on 11-7-20.
//  Copyright 2011 rexsheng.com. All rights reserved.
//

#import "RSPanLeftRightGestureRecognizer.h"

@implementation RSPanLeftRightGestureRecognizer

- (id) initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action])) {
		self.maximumNumberOfTouches = 1;
		self.directions = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
	}
	return self;
}

- (void)reset
{
	[super reset];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	_startPoint = [[touches anyObject] locationInView:self.view];
//	NSLog(@"b state %d", self.state);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	if (self.state < UIGestureRecognizerStateChanged) {
		CGPoint curr = [[touches anyObject] locationInView:self.view];
		CGPoint prev = [[touches anyObject] previousLocationInView:self.view];
		CGFloat horizontalWin = ABS(curr.x - prev.x) - ABS(curr.y - prev.y);
		if (horizontalWin < 0) {
			self.state = UIGestureRecognizerStateFailed;
		} else {
			self.state = UIGestureRecognizerStateBegan;
		}
	}
//	NSLog(@"m state %d", self.state);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	self.state = UIGestureRecognizerStateEnded;
//	NSLog(@"e state %d", self.state);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event];
	self.state = UIGestureRecognizerStateCancelled;
//	NSLog(@"c state %d", self.state);
}

@end
