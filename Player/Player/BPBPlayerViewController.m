//
//  BPBPlayerViewController.m
//  Player
//
//  Created by billy bray on 6/23/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import "BPBPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "BPBCapture.h"
#import "BPBReviewViewController.h"

#define RECORDING_START_TIME 0

@interface BPBPlayerViewController () <BPBCaptureDelegate>
@property (strong, nonatomic) IBOutlet UIView *controlsView;
@property (strong, nonatomic) MPMoviePlayerController *movieController;
@property (strong, nonatomic) NSTimer *playbackTimer;
@property BOOL playbackReady;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (strong, nonatomic) BPBCapture *capture;
@property (weak, nonatomic) IBOutlet UIView *progressValueBar;
@property (weak, nonatomic) IBOutlet UIView *progressValueHolderView;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UILabel *recordingStartingLabel;
@property (weak, nonatomic) IBOutlet UILabel *previewRecordingLabel;
@property (nonatomic) NSInteger recordingLength;
@property (nonatomic) NSInteger recordingTimeRemaining;
@property (nonatomic) int timeUntilRecordingStarts;
@property (weak, nonatomic) IBOutlet UILabel *recordingTimeRemainingLabel;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic) BOOL isRecording;
@end

@implementation BPBPlayerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // No custom initialiation needed
    }
    return self;
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.videoURL = [NSURL URLWithString:@"http://www.semanticdevlab.com/abc.mp4"];
    self.recordingLength = 5;
    [self prepareVideoPlayer:self.videoURL];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

-(void)prepareVideoPlayer: (NSURL*) theURL
{
    [self setupNotifications];
    [self prepareMovieController];
    [self prepareCapture];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector(videoFinishedPlayback:)
     name: MPMoviePlayerPlaybackDidFinishNotification
     object: self.movieController];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackIsReady)
     name:MPMovieDurationAvailableNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(setPlayBackViewBounds)
     name:MPMovieNaturalSizeAvailableNotification
     object:nil];
}

- (void)prepareMovieController {
    self.playbackReady = FALSE;
    self.movieController = [[MPMoviePlayerController alloc] init];
    self.movieController.shouldAutoplay = NO;
    self.movieController.scalingMode = MPMovieScalingModeAspectFit;
    self.movieController.controlStyle = MPMovieControlStyleNone;
    self.movieController.backgroundView.backgroundColor = [UIColor whiteColor];
    self.movieController.contentURL = self.videoURL;
    [self.movieController prepareToPlay];
}

-(void)prepareCapture
{
    self.capture = nil;
    //self.recordingView = nil;
    self.capture = [[BPBCapture alloc] init];
    self.capture.delegate = self;
    self.capture.player = self;
    self.capture.previewView = self.recordingView;
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self.capture setupAndStartCaptureSession];
    });
}

-(void)playbackIsReady {
    [self startPlaybackTimeMonitor];
}

-(void)updateProgressBarView {
    NSTimeInterval playTime = self.movieController.currentPlaybackTime;
    NSTimeInterval duration = self.movieController.duration;
    float progress;
    if (isnan(playTime) || isnan(duration) || duration == 0) {
        progress = 0.0;
    } else {
        progress = playTime/duration;
    }
    float outerViewWidth = self.progressValueHolderView.bounds.size.width;
    CGRect newProgressValue = CGRectMake(0, 0, progress*outerViewWidth, self.progressValueHolderView.frame.size.height);
    self.progressValueBar.frame = newProgressValue;
}

-(void)setPlayBackViewBounds
{
    [self.movieController.view setFrame: self.videoPlayBackView.bounds];
    [self.videoPlayBackView addSubview: self.movieController.view];
    [self.videoPlayBackView bringSubviewToFront:self.recordingView];
}

- (IBAction)record:(id)sender {
    
    if ([self.movieController playbackState]== MPMoviePlaybackStatePlaying) {
        [self setButtonsStoppedState];
        [self stopRecording:nil];
        return;
    }
    [self setButtonsRecordingState];
    [self prepareRecordingCountdownTimer];
    [self prepareCountdownTimeLabel];
}

- (IBAction)stopRecording:(id)sender {
    [self stopPlaybackTimeMonitor];
    [self.movieController pause];
    self.recordingTimeRemainingLabel.hidden = YES;
    [self.capture stopRecording];
    self.isRecording = FALSE;
    [self showRecordingDoneIndicator];
}

- (void)showRecordingDoneIndicator {
    self.indicator= [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.indicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    self.indicator.center = self.view.center;
    [self.view addSubview:self.indicator];
    [self.indicator bringSubviewToFront:self.view];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    [self.indicator startAnimating];
}

- (void)prepareRecordingCountdownTimer {
    NSTimer *timer;
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                             target:self
                                           selector:@selector(timerFireMethod:)
                                           userInfo:nil
                                            repeats:YES];
}

- (void)timerFireMethod:(NSTimer*)theTimer
{
    if (self.timeUntilRecordingStarts <= 0) {
        self.timerLabel.hidden = YES;
        self.recordingStartingLabel.hidden = YES;
        [self startRecording];
        [theTimer invalidate];
    }
    self.timerLabel.text = [NSString stringWithFormat:@"%i", self.timeUntilRecordingStarts];
    self.timeUntilRecordingStarts--;
}

- (void)prepareCountdownTimeLabel {
    self.timeUntilRecordingStarts = RECORDING_START_TIME;
    self.timerLabel.text = @"";
    self.recordingStartingLabel.hidden = NO;
    self.timerLabel.hidden = NO;
}

-(void)startRecording
{
    self.previewRecordingLabel.hidden = NO;
    [self.recordingView bringSubviewToFront:self.previewRecordingLabel];
    self.isRecording = TRUE;
    [self.movieController play];
    [self startPlaybackTimeMonitor];
    [self setupRecordingTimeRemaining];
    [self.capture startRecording];
}

-(void)setupRecordingTimeRemaining
{
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                     selector:@selector(endRecordingAfterTimeRemainingExpired:)
                                     userInfo:nil
                                     repeats:YES];
    self.recordingTimeRemaining = self.recordingLength + self.movieController.duration;
    [self.view bringSubviewToFront:self.recordingTimeRemainingLabel];
    self.recordingTimeRemainingLabel.text = [NSString stringWithFormat:@"Time Remaining: %ld seconds", (long)self.recordingTimeRemaining];
    self.recordingTimeRemainingLabel.hidden = NO;
}

- (void)endRecordingAfterTimeRemainingExpired:(NSTimer*)theTimer
{
    if (self.recordingTimeRemaining <= 0) {
        [theTimer invalidate];
        if (self.isRecording) {
            [self stopRecording:nil];
        }
        return;
    }
    self.recordingTimeRemaining--;
    self.recordingTimeRemainingLabel.text = [NSString stringWithFormat:@"Time Remaining: %ld seconds", (long)self.recordingTimeRemaining];
}

- (IBAction)playMovie:(id)sender {
    if (self.playbackReady && [self.movieController playbackState]!= MPMoviePlaybackStatePlaying) {
        [self startPlaybackTimeMonitor];
        [self setButtonsPlayingState];
        [self.movieController play];
    } else if ([self.movieController playbackState]== MPMoviePlaybackStatePlaying && [self.movieController playbackState] != MPMoviePlaybackStatePaused ) {
        [self setButtonsStoppedState];
        [self.movieController stop];
        [self.movieController prepareToPlay];
    }
}

-(void)setButtonsPlayingState
{
    self.recordButton.enabled = NO;
    self.recordButton.alpha = 0.5f;
    [self.playButton setTitle:@"Stop" forState:UIControlStateNormal];
}

-(void)setButtonsStoppedState
{
    self.playButton.enabled = YES;
    self.recordButton.enabled = YES;
    self.recordButton.alpha = 1.0f;
    self.playButton.alpha = 1.0f;
    [self.playButton setTitle:@"Play" forState:UIControlStateNormal];
    [self.recordButton setTitle:@"Record" forState:UIControlStateNormal];
}

-(void)setButtonsRecordingState
{
    self.playButton.enabled = NO;
    self.playButton.alpha = 0.5f;
    [self.recordButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
}

- (IBAction)mute:(id)sender {
    [self.capture toggleMute];
    if ([((UIButton*)sender).titleLabel.text isEqualToString:@"Mute"]) {
        ((UIButton*)sender).titleLabel.text = @"Unmute";
    } else {
        ((UIButton*)sender).titleLabel.text = @"Mute";
    }
}

-(void) stopPlaybackTimeMonitor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.playbackTimer invalidate];
        self.playbackTimer = nil;
    });
}

- (void) startPlaybackTimeMonitor
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playbackTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                                      interval:0.1
                                                        target:self
                                                      selector:@selector(updateProgressBarView) userInfo:nil
                                                       repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.playbackTimer forMode:NSDefaultRunLoopMode];
    });
}

-(void) videoFinishedPlayback: (NSNotification*) aNotification
{
    [self stopPlaybackTimeMonitor];
    [self.movieController prepareToPlay];
    [self setButtonsStoppedState];
}

- (void)captureReady
{
    self.playbackReady = TRUE;
}

-(void)captureCompleteWithURL:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        self.capture = nil;
    });
    self.movieController.view.hidden = YES;
    self.previewRecordingLabel.hidden = YES;
    [self presentReviewViewController:url];
}

- (void)presentReviewViewController:(NSURL *)url
{
    BPBReviewViewController *reviewController;
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        reviewController = [[BPBReviewViewController alloc] initWithNibName:@"BPBReviewViewController" bundle:[NSBundle mainBundle]];
    } else {
        reviewController = [[BPBReviewViewController alloc] initWithNibName:@"BPBReviewViewControlleriPhone" bundle:[NSBundle mainBundle]];
    }
    reviewController.videoUrl = url;
    reviewController.player = self;
    reviewController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.indicator stopAnimating];
    [self presentViewController:reviewController animated:YES completion:nil];
}

-(void)acceptRecording:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter]
     removeObserver: self
     name: MPMoviePlayerPlaybackDidFinishNotification
     object: self.movieController];
    
    //[self.plugin capturedVideoWithPath:[url absoluteString]];
    
}

-(void)redoRecording
{
    self.movieController.view.hidden = NO;
    [self.movieController play];
    [self.movieController pause];
    [self setPlayBackViewBounds];
    [self prepareCapture];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self setPlayBackViewBounds];
}

-(void)refreshPlayBackViewBounds {
    [self.movieController.view setFrame: self.videoPlayBackView.bounds];
    [self.videoPlayBackView bringSubviewToFront:self.recordingView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation ==UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}
@end
