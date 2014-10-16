//
//  Streamer.m
//  vncserver
//
//  Created by Henri Verroken on 16/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//

#import "Streamer.h"

#import <CoreGraphics/CoreGraphics.h>
#import <rfb/rfb.h>

typedef struct {
    rfbScreenInfoPtr server;
    struct {
        char **buffer;
        size_t size;
    } framebuffer;
    struct {
        int counter;
        CFAbsoluteTime time;
    } fps;
} StreamerVNCStream;

#pragma mark -
@interface Streamer () <AVCaptureVideoDataOutputSampleBufferDelegate>
#pragma mark Properties
@property (nonatomic, assign) CGDirectDisplayID displayID;

#pragma mark Streaming
@property (nonatomic, assign) dispatch_queue_t captureQueue;
@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoDataOutput *captureOutput;
@property (nonatomic, assign) StreamerVNCStream *stream;
@end

#pragma mark -
@implementation Streamer
#pragma mark Init
- (id)initWithDisplayID:(CGDirectDisplayID)displayID {
    self = [super init];
    if(self != nil) {
        self.displayID = displayID;

        self.stream = malloc(sizeof(*(self.stream)));
        memset(self.stream, 0, sizeof(*(self.stream)));
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

    [self setupVNCServer];
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

- (void)setupVNCServer {
    CGSize size;
    int argc;

    [self destroyVNCServer];

    size = CGDisplayBounds(self.displayID).size;

    argc = 0;
    self.stream->server = rfbGetScreen(&argc, NULL,
                                       (int)size.width, (int)size.height,
                                       8, 3, 4);
    self.stream->framebuffer.buffer = &(self.stream->server->frameBuffer);
    self.stream->framebuffer.size = (size_t)size.width*(size_t)size.height*4;
    *self.stream->framebuffer.buffer = malloc(self.stream->framebuffer.size);

    rfbInitServer(self.stream->server);
}

- (void)destroyVNCServer {
    if(self.stream->server) {
        free(*self.stream->framebuffer.buffer);
        rfbScreenCleanup(self.stream->server);
    }

    memset(self.stream, 0, sizeof(*(self.stream)));
}

- (void)updateVNCFramebuffer:(char *)bgra32 {
    size_t i;
    char *dest;

    dest = *self.stream->framebuffer.buffer;

    for(i = 0; i < self.stream->framebuffer.size; i += (size_t)4) {
        dest[i] = bgra32[i+2];
        dest[i+1] = bgra32[i+1];
        dest[i+2] = bgra32[i];
        dest[i+3] = 255;
    }
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

    [self updateVNCFramebuffer:(char *)base];
    rfbMarkRectAsModified(self.stream->server, 0, 0, (int)width, (int)height);

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    /* FPS */
    CFAbsoluteTime now;
    self.stream->fps.counter++;
    if(self.stream->fps.counter == 9) {
        now = CFAbsoluteTimeGetCurrent();

        printf("fps: %f\n", 1./(now - self.stream->fps.time)*(double)self.stream->fps.counter);
        self.stream->fps.time = CFAbsoluteTimeGetCurrent();
        self.stream->fps.counter = 0;
    }


    if(rfbIsActive(self.stream->server)) {
        rfbProcessEvents(self.stream->server,
                         self.stream->server->deferUpdateTime * 1000);
    }

    /*
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
     */
}
@end
