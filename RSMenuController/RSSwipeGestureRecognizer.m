//
//  RSSwipeGestureRecognizer.m
//  version 1.0 beta1
//
//  Created by Rex Sheng on 7/23/12.
//  Copyright (c) 2012 lognllc.com. All rights reserved.
//

#import "RSSwipeGestureRecognizer.h"

@implementation RSSwipeGestureRecognizer
{
	CGPoint startPoint;
}
@synthesize minDistance, direction;

- (void)reset
{
	[super reset];
	startPoint = CGPointZero;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	self.state = UIGestureRecognizerStatePossible;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	if (self.state == UIGestureRecognizerStatePossible) {
		CGPoint curr = [[touches anyObject] locationInView:self.view];
		CGPoint prev = [[touches anyObject] previousLocationInView:self.view];
		CGFloat horizontalWin = ABS(curr.x - prev.x) - ABS(curr.y - prev.y);
		BOOL recognized = NO;
		switch (self.direction) {
			case UISwipeGestureRecognizerDirectionLeft:
			{
				recognized = horizontalWin > 0 && curr.x < prev.x;
				break;
			}
			case UISwipeGestureRecognizerDirectionRight:
			{
				recognized = horizontalWin > 0 && curr.x > prev.x;
				break;
			}
			case UISwipeGestureRecognizerDirectionUp:
			{
				recognized = horizontalWin < 0 && curr.y < prev.y;
				break;
			}
			case UISwipeGestureRecognizerDirectionDown:
			{
				recognized = horizontalWin < 0 && curr.y > prev.y;
				break;
			}
			default:
				break;
		}
		if (recognized) {
			self.state = UIGestureRecognizerStateBegan;
			startPoint = curr;
		} else {
			self.state = UIGestureRecognizerStateFailed;
		}
	} else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
		CGPoint curr = [[touches anyObject] locationInView:self.view];
		CGFloat distance = 0;
		switch (self.direction) {
			case UISwipeGestureRecognizerDirectionLeft:
			{
				distance = startPoint.x - curr.x;
				break;
			}
			case UISwipeGestureRecognizerDirectionDown:
			{
				distance = curr.y - startPoint.y;
				break;
			}
			case UISwipeGestureRecognizerDirectionUp:
			{
				distance = startPoint.y - curr.y;
				break;
			}
			case UISwipeGestureRecognizerDirectionRight:
			{
				distance = curr.x - startPoint.x;
				break;
			}
			default:
				break;
		}
		if (distance > minDistance) {
			self.state = UIGestureRecognizerStateRecognized;
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	self.state = UIGestureRecognizerStateCancelled;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event];
	self.state = UIGestureRecognizerStateCancelled;
}

@end
