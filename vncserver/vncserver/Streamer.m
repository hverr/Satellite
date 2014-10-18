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
        size_t bytesPerRow;
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
        size_t count, i;
        const CGRect *dirtyRects;
        CGDisplayStreamUpdateRectType mode;
        CVPixelBufferRef pixelBuffer;
        void *base;
        CVReturn rv;

        if(status != kCGDisplayStreamFrameStatusFrameComplete) {
            return;
        }

        mode = kCGDisplayStreamUpdateDirtyRects;
        dirtyRects = CGDisplayStreamUpdateGetRects(updateRef, mode, &count);

        rv = CVPixelBufferCreateWithIOSurface(NULL, frameSurface,
                                              NULL, &pixelBuffer);
        if(rv != kCVReturnSuccess) {
            NSLog(@"%s could not create pixel buffer", __PRETTY_FUNCTION__);
        }


        CVPixelBufferLockBaseAddress(pixelBuffer, 0);

        base = CVPixelBufferGetBaseAddress(pixelBuffer);
        for(i = 0; i < count; i++) {
            int x1, y1, x2, y2;

            x1 = (int)dirtyRects[i].origin.x;
            y1 = (int)dirtyRects[i].origin.y;
            x2 = x1 + (int)dirtyRects[i].size.width;
            y2 = y1 + (int)dirtyRects[i].size.height;

            [self updateVNCFramebuffer:(char *)base dirty:dirtyRects[i]];
            rfbMarkRectAsModified(self.stream->server, x1, y1, x2, y2);
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        CFRelease(pixelBuffer);

        if(rfbIsActive(self.stream->server)) {
            rfbProcessEvents(self.stream->server,
                             self.stream->server->deferUpdateTime * 1000);
        }

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
                     [NSNumber numberWithFloat:1./60.],
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

    self.stream->framebuffer.bytesPerRow = (size_t)size.width * (size_t)4;

    rfbInitServer(self.stream->server);
}

- (void)destroyVNCServer {
    if(self.stream->server) {
        free(*self.stream->framebuffer.buffer);
        rfbScreenCleanup(self.stream->server);
    }

    memset(self.stream, 0, sizeof(*(self.stream)));
}

- (void)updateVNCFramebuffer:(char *)bgra32 dirty:(CGRect)rect {
    size_t row, minrow, maxrow, col, mincol, maxcol, i;
    size_t bpr;
    char *dest;

    dest = *self.stream->framebuffer.buffer;
    bpr = self.stream->framebuffer.bytesPerRow;

    minrow = (size_t)rect.origin.y;
    maxrow = (size_t)rect.origin.y + (size_t)rect.size.height;
    mincol = (size_t)rect.origin.x * (size_t)4;
    maxcol = mincol + (size_t)rect.size.width * (size_t)4;

    for(row = minrow, i = 0; row < maxrow; row++) {
        for(col = mincol; col < maxcol; col += 4, i += 4) {
            dest[row*bpr + col] = bgra32[row*bpr + col + 2];
            dest[row*bpr + col + 1] = bgra32[row*bpr + col + 1];
            dest[row*bpr + col + 2] = bgra32[row*bpr + col];
        }
    }
    /*
    for(i = 0; i < self.stream->framebuffer.size; i += (size_t)4) {
        dest[i] = bgra32[i+2];
        dest[i+1] = bgra32[i+1];
        dest[i+2] = bgra32[i];
        dest[i+3] = 255;
    }
     */
}
@end
