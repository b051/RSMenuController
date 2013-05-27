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
	label.userInteractionEnabled = YES;
	[self.view addSubview:_label = label];
	[label addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];
}

- (void)tap:(UITapGestureRecognizer *)tap
{
	[[[UIAlertView alloc] initWithTitle:@"tap" message:self.description delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil] show];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	_label.text = self.title;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"'%@'", self.title];
}

@end
