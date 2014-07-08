//
//  VideoCompositor.m
//  Player
//
//  Created by billy bray on 7/7/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import "VideoCompositor.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>


@interface VideoCompositor ()

@property AVAssetWriterInput *assetWriterAudioIn;
@property AVAssetWriterInput *assetWriterVideoIn;
@property (nonatomic) AVCaptureVideoOrientation referenceOrientation;

@end

@implementation VideoCompositor

-(BOOL)setupAssetWriter:(NSURL*)url
{
    self.referenceOrientation = UIDeviceOrientationPortrait;

    NSError *error;
    
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:url fileType:(NSString *)kUTTypeQuickTimeMovie error:&error];
    if (error) {
        return NO;
    }
    return YES;
}

-(void)completeWriting
{
    [self.assetWriter finishWritingWithCompletionHandler:^(){
        [self.capture saveAndCloseSession];
        [self.capture stopAndTearDownCaptureSession];
    }];
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
	if ( self.assetWriter.status == AVAssetWriterStatusUnknown ) {
        if ([self.assetWriter startWriting]) {
			[self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
            NSLog(@"Problem starting sample buffer writing");
            NSLog(@"Error:%@",[self.assetWriter error]);
		}
	}
	if ( self.assetWriter.status == AVAssetWriterStatusWriting ) {
		if (mediaType == AVMediaTypeVideo) {
			if (self.assetWriterVideoIn.readyForMoreMediaData) {
				if (![self.assetWriterVideoIn appendSampleBuffer:sampleBuffer] ) {
                    NSLog(@"Problem writing video sample buffer");
                    NSLog(@"Error:%@",[self.assetWriter error]);
				} else {
                    NSLog(@"Written Video");
                }
			}
		} else if (mediaType == AVMediaTypeAudio) {
			if (self.assetWriterAudioIn.readyForMoreMediaData) {
                if (![self.assetWriterAudioIn appendSampleBuffer:sampleBuffer] ) {
                    NSLog(@"Problem writing audio sample buffer");
				} else {
                    NSLog(@"Written Audio");
                }
			}
		}
	}
}

- (BOOL) setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription
{
	const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
	size_t aclSize = 0;
	const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
	NSData *currentChannelLayoutData = nil;
	// AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
	if ( currentChannelLayout && aclSize > 0 ) {
		currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
    } else {
		currentChannelLayoutData = [NSData data];
    }
	NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
											  [NSNumber numberWithFloat:currentASBD->mSampleRate], AVSampleRateKey,
											  [NSNumber numberWithInt:64000], AVEncoderBitRatePerChannelKey,
											  [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
											  currentChannelLayoutData, AVChannelLayoutKey,
											  nil];
	if ([self.assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
		self.assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
		self.assetWriterAudioIn.expectsMediaDataInRealTime = YES;
		if ([self.assetWriter canAddInput:self.assetWriterAudioIn])
			[self.assetWriter addInput:self.assetWriterAudioIn];
		else {
			NSLog(@"Couldn't add asset writer audio input.");
            return NO;
		}
	} else {
		NSLog(@"Couldn't apply audio output settings.");
        return NO;
	}
    return YES;
}

- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription
{
	float bitsPerPixel;
	CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
	int numPixels = dimensions.width * dimensions.height;
	int bitsPerSecond;
	// Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
	if ( numPixels < (640 * 480) ) {
		bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
    } else {
		bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
    }
	bitsPerSecond = numPixels * bitsPerPixel;
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:dimensions.width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:dimensions.height], AVVideoHeightKey,
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([self.assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		self.assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		self.assetWriterVideoIn.expectsMediaDataInRealTime = YES;
		self.assetWriterVideoIn.transform = [self transformFromCurrentVideoOrientationToOrientation:self.referenceOrientation];
		if ([self.assetWriter canAddInput:self.assetWriterVideoIn])
			[self.assetWriter addInput:self.assetWriterVideoIn];
		else {
			NSLog(@"Couldn't add asset writer video input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply video output settings.");
        return NO;
	}
    return YES;
}

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGAffineTransform transform = CGAffineTransformIdentity;
	CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
	CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoOrientation];
    CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation(angleOffset);
	return transform;
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGFloat angle = 0.0;
	switch (orientation) {
		case AVCaptureVideoOrientationPortrait:
			angle = M_PI;
			break;
		case AVCaptureVideoOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = -M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = M_PI_2;
			break;
		default:
			break;
	}
	return angle;
}

-(void)updateRefOrientation:(AVCaptureVideoOrientation)newOrientation
{
    self.referenceOrientation = newOrientation;
}


@end
