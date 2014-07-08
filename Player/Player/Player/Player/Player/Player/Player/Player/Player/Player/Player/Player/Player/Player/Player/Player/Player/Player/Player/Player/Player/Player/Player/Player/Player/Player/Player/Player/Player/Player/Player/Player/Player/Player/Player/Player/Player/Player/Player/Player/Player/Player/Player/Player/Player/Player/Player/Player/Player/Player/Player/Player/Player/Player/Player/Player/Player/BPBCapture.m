//
//  BPBCapture.m
//  Player
//
//  Created by billy bray on 6/24/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import "BPBCapture.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "VideoCompositor.h"

static void * RecordingContext = &RecordingContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface BPBCapture () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate> {
    BOOL readyToRecordAudio;
    BOOL readyToRecordVideo;
	BOOL recording;
	dispatch_queue_t assetWritingQueue;

}

@property (nonatomic) AVCaptureConnection *audioConnection;
@property (nonatomic) AVCaptureConnection *videoConnection;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic) AVCaptureVideoOrientation referenceOrientation;
@property (nonatomic) AVCaptureVideoOrientation videoOrientation;
@property NSURL *movieURL;
@property (nonatomic) BOOL readyToRecord;
@property BOOL muted;
@property BOOL videoCompositorReady;
@property (nonatomic) VideoCompositor *videoCompositor;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;

@end

@implementation BPBCapture

- (id) init
{
    if (self = [super init]) {
        self.referenceOrientation = UIDeviceOrientationPortrait;
        self.movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"MOVIE.MOV"]];
        _muted = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionStarted) name:AVCaptureSessionDidStartRunningNotification object:nil];
    }
    return self;
}

-(void)sessionStarted
{
    [self.delegate captureReady];
}

-(void)toggleMute
{
    self.muted = !self.muted;
}

- (void) startRecording
{
    [self checkDeviceAuthorizationStatus];
    
    dispatch_async(assetWritingQueue, ^{
        [self deleteFiles];
        [self startCompositor];
    });
}

-(void)deleteFiles
{
    [self deleteFilesWithCompletionHandler:^(BOOL finished) {
        if(finished){
            NSLog(@"Deleted all files");
        }
    }];
}

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted)
		{
			[self setDeviceAuthorized:YES];
		} else {
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
											message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
		}
	}];
}

-(void)startCompositor
{
    self.videoCompositor = [[VideoCompositor alloc] init];
    self.videoCompositor.capture = self;
    self.videoCompositor.videoOrientation = self.videoOrientation;
    self.videoCompositorReady = [self.videoCompositor setupAssetWriter:self.movieURL];
}

-(void) deleteFilesWithCompletionHandler:(deleteFiles) compblock{
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
    compblock(YES);
}



- (void) setupAndStartCaptureSession
{
    if ( !self.session )
		[self setupCaptureSession];
	
	if ( !self.session.isRunning )
		[self.session startRunning];
}

- (BOOL) setupCaptureSession
{
    
    assetWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);

    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    [self setupSessionAudio];
    [self setupSessionVideo];
    [self.session startRunning];
    [self setupSessionPreview];
	return YES;
}

- (void)setupSessionAudio
{
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if ([self.session canAddInput:audioIn])
        [self.session addInput:audioIn];
	AVCaptureAudioDataOutput *audioOut = [[AVCaptureAudioDataOutput alloc] init];
	dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
	[audioOut setSampleBufferDelegate:self queue:audioCaptureQueue];
	if ([self.session canAddOutput:audioOut])
		[self.session addOutput:audioOut];
	self.audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
}

- (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}

- (void)setupSessionVideo
{
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionFront] error:nil];
    if ([self.session canAddInput:videoIn])
        [self.session addInput:videoIn];
	AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
	[videoOut setAlwaysDiscardsLateVideoFrames:YES];
	[videoOut setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
	dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
	[videoOut setSampleBufferDelegate:self queue:videoCaptureQueue];
	if ([self.session canAddOutput:videoOut])
		[self.session addOutput:videoOut];
    
	self.videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
	self.videoOrientation = [self.videoConnection videoOrientation];
}

- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position)
            return device;
    
    return nil;
}

- (void)setupSessionPreview
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.frame = self.previewView.bounds;
        [self.previewView.layer addSublayer:self.previewLayer];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [[self.previewLayer connection] setVideoOrientation:(AVCaptureVideoOrientation)[self.player interfaceOrientation]];
        
        [self.player.videoPlayBackView bringSubviewToFront:self.player.recordingView];
    });
}

#pragma mark Capture
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
	CFRetain(sampleBuffer);
	CFRetain(formatDescription);
    
    dispatch_async(assetWritingQueue, ^{
        if (self.videoCompositor.assetWriter) {
            if (connection == self.videoConnection) {
                if (!readyToRecordVideo) {
                    readyToRecordVideo = [self.videoCompositor setupAssetWriterVideoInput:formatDescription];
                }
                if (readyToRecordVideo && readyToRecordAudio) {
                    [self.videoCompositor writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                }
            } else if (connection == self.audioConnection) {
                    if (!readyToRecordAudio) {
                        readyToRecordAudio = [self.videoCompositor setupAssetWriterAudioInput:formatDescription];
                    }
                    if (self.muted) {
                        CMBlockBufferRef buffRef = CMSampleBufferGetDataBuffer(sampleBuffer);
                        char fillByte = 0;
                        CMBlockBufferFillDataBytes(fillByte,buffRef,0,CMBlockBufferGetDataLength(buffRef));
                    }
                    if (readyToRecordAudio && readyToRecordVideo) {
                        [self.videoCompositor writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
                    }
            }
        }
        CFRelease(sampleBuffer);
        CFRelease(formatDescription);

	});
    
    
}

- (void)saveAndCloseSession
{
    readyToRecordVideo = NO;
    readyToRecordAudio = NO;
    [self saveFileThenSendURL:^{
        [self updateDelegateWithUrl:self.movieURL];
    }];
    self.videoCompositor = nil;
}

- (void) stopAndTearDownCaptureSession
{
	self.session = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (assetWritingQueue) {
		assetWritingQueue = NULL;
	}
}

- (void) stopRecording
{
    if ([self.session isRunning]) {
        [self.session stopRunning];
    }
    [self.videoCompositor completeWriting];
}

-(void)updateDelegateWithUrl:(NSURL *)url
{
    [self.delegate captureCompleteWithURL:url];
}

- (void)saveFileThenSendURL:(void (^)(void))completion;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSData *videoData = [NSData dataWithContentsOfURL:self.movieURL];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *tempPath = [documentsDirectory stringByAppendingFormat:@"/MOVIE.MOV"];
        
        [videoData writeToFile:tempPath atomically:NO];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });
    });
}

-(void) orientationChanged
{
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIInterfaceOrientationPortraitUpsideDown){
        [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
        self.referenceOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
        [self.videoCompositor updateRefOrientation:self.referenceOrientation];
    }
    else if (deviceOrientation == UIInterfaceOrientationPortrait){
        [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        self.referenceOrientation = AVCaptureVideoOrientationPortrait;
        [self.videoCompositor updateRefOrientation:self.referenceOrientation];
    }
    else if (deviceOrientation == UIInterfaceOrientationLandscapeLeft){
        [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
        self.referenceOrientation = AVCaptureVideoOrientationLandscapeLeft;
        [self.videoCompositor updateRefOrientation:self.referenceOrientation];
    }
    else{
        [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
        self.referenceOrientation = AVCaptureVideoOrientationLandscapeRight;
        [self.videoCompositor updateRefOrientation:self.referenceOrientation];
    }
}



@end
