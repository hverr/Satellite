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
@property (nonatomic, strong) dispatch_queue_t captureQueue;
@property (nonatomic, assign) CGDisplayStreamRef displayStream;
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
    CGSize size;
    NSDictionary *streamOptions;
    CFDictionaryRef cstreamOptions;
    CGDisplayStreamRef displayStream;
    CGDisplayStreamFrameAvailableHandler handler;

    size = CGDisplayBounds(self.displayID).size;

    handler = ^(CGDisplayStreamFrameStatus status,
                uint64_t displayTime,
                IOSurfaceRef frameSurface,
                CGDisplayStreamUpdateRef updateRef)
    {
        size_t count;
        const CGRect *dirtyRects;
        CGDisplayStreamUpdateRectType mode;
        CVPixelBufferRef pixelBuffer;
        CVReturn rv;

        if(status != kCGDisplayStreamFrameStatusFrameComplete) {
            return;
        }

        mode = kCGDisplayStreamUpdateReducedDirtyRects;
        dirtyRects = CGDisplayStreamUpdateGetRects(updateRef, mode, &count);

        rv = CVPixelBufferCreateWithIOSurface(NULL, frameSurface,
                                              NULL, &pixelBuffer);
        if(rv != kCVReturnSuccess) {
            NSLog(@"%s could not create pixel buffer", __PRETTY_FUNCTION__);
        }


        CVPixelBufferLockBaseAddress(pixelBuffer, 0);

        memcpy(*self.stream->framebuffer.buffer,
               CVPixelBufferGetBaseAddress(pixelBuffer),
               self.stream->framebuffer.size);

        rfbMarkRectAsModified(self.stream->server,
                              0, 0, (int)size.width, (int)size.height);

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);


        CFRelease(pixelBuffer);

        CFAbsoluteTime now;
        self.stream->fps.counter++;
        if(self.stream->fps.counter == 9) {
            now = CFAbsoluteTimeGetCurrent();

            printf("fps: %f\n", 1./(now - self.stream->fps.time)*(double)self.stream->fps.counter);
            self.stream->fps.time = CFAbsoluteTimeGetCurrent();
            self.stream->fps.counter = 0;
        }
    };


    /*displayStream = CGDisplayStreamCreate(self.displayID,
                                          (size_t)size.width,
                                          (size_t)size.height,
                                          'BGRA', NULL, handler);*/
    streamOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithFloat:1./30.],
                     kCGDisplayStreamMinimumFrameTime, nil];
    cstreamOptions = (__bridge CFDictionaryRef)streamOptions;
    displayStream = CGDisplayStreamCreateWithDispatchQueue(self.displayID,
                                                           (size_t)size.width,
                                                           (size_t)size.height,
                                                           'BGRA',
                                                           cstreamOptions,
                                                           self.captureQueue,
                                                           handler);

    [self setupVNCServer];

    //runLoopSource = CGDisplayStreamGetRunLoopSource(displayStream);
    /*CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       runLoopSource,
                       kCFRunLoopDefaultMode);*/
    CGDisplayStreamStart(displayStream);

    return YES;
}

- (void)stopStreaming {
    //CGDisplayStreamStop(self.displayStream);
    CFRelease(self.displayStream);
    self.displayStream = NULL;
}

- (void)resetCaptureQueue {
    if(self.captureQueue) {
        dispatch_suspend(self.captureQueue);
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
    rfbRunEventLoop(self.stream->server,
                    self.stream->server->deferUpdateTime*1000,
                    1);
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
@end
