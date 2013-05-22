//
//  RSViewController.m
//  RSMenuController
//
//  Created by Rex Sheng on 5/22/13.
//  Copyright (c) 2013 Rex Sheng. All rights reserved.
//

#import "RSViewController.h"

@implementation RSViewController
{
	__weak UILabel *_label;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background"]];
	UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
	label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	label.textColor = [UIColor blueColor];
	label.textAlignment = UITextAlignmentCenter;
	label.font = [UIFont boldSystemFontOfSize:30];
	label.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_label = label];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	_label.text = self.title;
}

@end
