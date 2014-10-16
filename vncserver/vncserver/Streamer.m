//
//  Streamer.m
//  vncserver
//
//  Created by Henri Verroken on 16/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//

#import "Streamer.h"

#import <CoreGraphics/CoreGraphics.h>

#pragma mark -
@interface Streamer () <AVCaptureVideoDataOutputSampleBufferDelegate>
#pragma mark Properties
@property (nonatomic, assign) CGDirectDisplayID displayID;

#pragma mark Streaming
@property (nonatomic, assign) dispatch_queue_t captureQueue;
@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoDataOutput *captureOutput;
@end

#pragma mark -
@implementation Streamer
#pragma mark Init
- (id)initWithDisplayID:(CGDirectDisplayID)displayID {
    self = [super init];
    if(self != nil) {
        self.displayID = displayID;
    }
    return self;
}

#pragma mark Streaming
- (BOOL)startStreaming:(NSError **)error {
    AVCaptureSession *session;
    AVCaptureScreenInput *input;
    AVCaptureVideoDataOutput *output;

    if(error) {
        *error = nil;
    }

    session = [[AVCaptureSession alloc] init];
    [session setSessionPreset:AVCaptureSessionPresetHigh];

    input = [[AVCaptureScreenInput alloc] initWithDisplayID:self.displayID];
    if(!input || ![session canAddInput:input]) {
        return NO;
    }
    [session addInput:input];

    output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    output.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
                            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey,
                            nil];
    /*for(NSNumber *number in output.availableVideoCVPixelFormatTypes) {
        int c = [number intValue];
        NSLog(@"%c%c%c%c (%x)",
              (c >> 24) & 0xFF,
              (c >> 16) & 0xFF,
              (c >>  8) & 0xFF,
              (c >>  0) & 0xFF,
              c);
    }*/

    [self resetCaptureQueue];
    [output setSampleBufferDelegate:self queue:self.captureQueue];
    if(![session canAddOutput:output]) {
        return NO;
    }
    [session addOutput:output];

    self.captureSession = session;
    self.captureOutput = output;

    [session startRunning];

    return YES;
}

- (void)stopStreaming {
    [self.captureSession stopRunning];

    self.captureSession = nil;
    self.captureOutput = nil;
}

- (void)resetCaptureQueue {
    if(self.captureQueue) {
        dispatch_suspend(self.captureQueue);
        dispatch_release(self.captureQueue);
    }
    self.captureQueue = dispatch_queue_create("streamer.capture", NULL);
}

#pragma mark Output Delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connectioncapture
{
    CVImageBufferRef imageBuffer;
    void *base;
    size_t bpr, width, height;

    imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    bpr = CVPixelBufferGetBytesPerRow(imageBuffer);
    width = CVPixelBufferGetWidth(imageBuffer);
    height = CVPixelBufferGetHeight(imageBuffer);
    base = CVPixelBufferGetBaseAddress(imageBuffer);

    CGColorSpaceRef colorSpace;
    CGContextRef context;
    CGImageRef image;

    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate(base, width, height, 8, bpr, colorSpace,
                                    kCGBitmapByteOrder32Little |
                                    kCGImageAlphaNoneSkipFirst);
    image = CGBitmapContextCreateImage(context);

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    NSURL *output;
    CGImageDestinationRef dest;

    output = [NSURL fileURLWithPath:
              [NSString stringWithFormat:@"/tmp/screen-%f.png",
               CFAbsoluteTimeGetCurrent()]];
    dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)output,
                                           CFSTR("public.png"),
                                           1, NULL);
    CGImageDestinationAddImage(dest, image, NULL);
    CGImageDestinationFinalize(dest);
    CFRelease(dest);
}
@end
