//
//  BPBReviewViewController.h
//  Player
//
//  Created by billy bray on 6/25/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BPBPlayerViewController.h"

@interface BPBReviewViewController : UIViewController
@property (nonatomic, weak) NSURL *videoUrl;
@property (nonatomic, weak) BPBPlayerViewController *player;
@end
