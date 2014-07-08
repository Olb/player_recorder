//
//  BPBCapture.h
//  Player
//
//  Created by billy bray on 6/24/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "BPBPlayerViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

typedef void(^deleteFiles)(BOOL);

@protocol BPBCaptureDelegate <NSObject>
@optional
- (void)captureReady;
-(void)captureCompleteWithURL:(NSURL *)url;
@end

@interface BPBCapture : NSObject

@property (nonatomic) AVCaptureSession *session;
@property (nonatomic, weak) id <BPBCaptureDelegate> delegate;
@property (nonatomic, weak) UIView *previewView;
@property (nonatomic, weak) BPBPlayerViewController *player;
-(void)toggleMute;
-(BOOL)setupCaptureSession;
- (void) setupAndStartCaptureSession;
- (void) stopAndTearDownCaptureSession;
- (void) startRecording;
- (void) stopRecording;
- (void)saveAndCloseSession;

@end
