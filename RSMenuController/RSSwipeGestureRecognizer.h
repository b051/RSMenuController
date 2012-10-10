//
//  RSSwipeGestureRecognizer.h
//  version 1.0 beta1
//
//  Created by Rex Sheng on 7/23/12.
//  Copyright (c) 2012 lognllc.com. All rights reserved.
//

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface RSSwipeGestureRecognizer : UIGestureRecognizer

- (void)reset;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

@property (nonatomic, assign) CGFloat minDistance;
@property (nonatomic, assign) UISwipeGestureRecognizerDirection direction;

@end
