//
//  BPBReviewViewController.m
//  Player
//
//  Created by billy bray on 6/25/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import "BPBReviewViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface BPBReviewViewController () <UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UIView *reviewPlaybackView;
@property (strong, nonatomic) MPMoviePlayerController *movieController;

@end

@implementation BPBReviewViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // No custom initialization needed
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self prepareMoviePlayer:self.videoUrl];
}

-(void)prepareMoviePlayer: (NSURL*) theURL {
    
    self.movieController = [[MPMoviePlayerController alloc] initWithContentURL: theURL];
    self.movieController.shouldAutoplay = YES;
    self.movieController.scalingMode = MPMovieScalingModeAspectFill;
    self.movieController.controlStyle = MPMovieControlStyleEmbedded;
    
    [self.movieController prepareToPlay];
    
    CGRect newBounds = CGRectMake(0, 0, self.reviewPlaybackView.bounds.size.width, self.reviewPlaybackView.bounds.size.height);
    [self.movieController.view setFrame: newBounds]; 
    [self.reviewPlaybackView addSubview: self.movieController.view];
    
    
    // Register for the playback finished notification
    [[NSNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector(videoFinishedPlayback:)
     name: MPMoviePlayerPlaybackDidFinishNotification
     object: self.movieController];
}

-(void) videoFinishedPlayback: (NSNotification*) aNotification
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Accept Recording"
                                                        message:@"Accept this recording?"
                                                       delegate:self
                                              cancelButtonTitle:@"No"
                                              otherButtonTitles:@"Yes", nil];
    
    [alertView show];
    
    [[NSNotificationCenter defaultCenter]
     removeObserver: self
     name: MPMoviePlayerPlaybackDidFinishNotification
     object: self.movieController];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        [self dismissViewControllerAnimated:YES completion:^{
            [self.player redoRecording];
        }];
    }
    else if(buttonIndex == 1)
    {
        [self dismissViewControllerAnimated:YES
                                 completion:^{
                                     [self.player acceptRecording:self.videoUrl];
                                 }];
    }
}



- (IBAction)stop:(id)sender {
    [self.movieController stop];
}
@end
