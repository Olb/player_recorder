//
//  VideoCompositor.h
//  Player
//
//  Created by billy bray on 7/7/14.
//  Copyright (c) 2014 Spartan Systems Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BPBCapture.h"

@interface VideoCompositor : NSObject
@property (weak) BPBCapture *capture;
@property (nonatomic) AVCaptureVideoOrientation videoOrientation;
@property AVAssetWriter *assetWriter;
-(BOOL)setupAssetWriter:(NSURL*)url;
-(void)completeWriting;
- (BOOL) setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription;
- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription;
- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType;
-(void)updateRefOrientation:(AVCaptureVideoOrientation)newOrientation;
@end
