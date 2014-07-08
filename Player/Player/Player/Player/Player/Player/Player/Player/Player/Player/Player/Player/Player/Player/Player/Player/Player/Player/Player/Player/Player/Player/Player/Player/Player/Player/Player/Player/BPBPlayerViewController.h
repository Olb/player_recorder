//
//  BPBPlayerViewController.h
//  Player
//
//  Created by billy bray on 6/23/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BPBPlayerViewController : UIViewController
@property (strong, nonatomic) NSURL *videoURL;
@property (weak, nonatomic) IBOutlet UIView *recordingView;
@property (weak, nonatomic) IBOutlet UIView *videoPlayBackView;

-(void)acceptRecording:(NSURL *)url;
-(void)redoRecording;
@end
