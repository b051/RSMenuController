//
//  NAPanLeftRightGestureRecognizer.h   
//  version 1.0 beta1
//
//  Created by Rex Sheng on 11-7-20.
//  Copyright 2011 rexsheng.com. All rights reserved.
//

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface RSPanLeftRightGestureRecognizer : UIPanGestureRecognizer

- (void)reset;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

@property (nonatomic) NSUInteger directions;
@property (nonatomic) CGPoint startPoint;

@end