//
//  streamer.c
//  vncserver
//
//  Created by Henri Verroken on 14/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//

#include "streamer.h"

#include <IOSurface/IOSurface.h>
#include <OpenGL/OpenGL.h>
#include <OpenGl/gl.h>

#define BPP ((size_t)4)
#define BPR(ppr) (BPP * (size_t)ppr)

#define FULL_STREAM_INTERVAL ((CFAbsoluteTime)5.0)

void _StreamerDisplayStreamFrameAvailable(Streamer *streamer,
                                          CGDisplayStreamFrameStatus status,
                                          uint64_t displayTime,
                                          IOSurfaceRef frameSurface,
                                          CGDisplayStreamUpdateRef updateRef);
void _StreamerUpdateInternalFramebuffer(Streamer *streamer,
                                        CGRect rectangle,
                                        IOSurfaceRef frameSurface);
void _StreamerDebugWriteFramebuffer(Streamer *streamer);
void _StreamerPutBitmap(Streamer *streamer, CGRect srcRect,
                        char *gldata, size_t rowBytes, size_t height);

Streamer *StreamerInit(Streamer *streamer, CGDirectDisplayID displayID) {
    memset(streamer, 0, sizeof(*streamer));

    if(!CGDisplayIsActive(displayID)) {
        streamer->lastError = "display is not active";
        return NULL;
    }

    streamer->display.ID = displayID;
    streamer->display.size = CGDisplayBounds(displayID).size;

    return streamer;
}

char *StreamerCopyLastError(Streamer *streamer) {
    if(streamer->lastError == NULL) {
        return NULL;
    }
    return strdup(streamer->lastError);
}

int StreamerStartStreaming(Streamer *streamer) {
    CGDisplayStreamRef displayStream;
    CGDisplayStreamFrameAvailableHandler handler;
    CFRunLoopSourceRef streamSource;
    rfbScreenInfoPtr screenInfo;
    size_t height, width, framebufferSize;

    height = (size_t)streamer->display.size.height;
    width = (size_t)streamer->display.size.width;

    /* Open the display stream */
    handler = ^(CGDisplayStreamFrameStatus status,
                uint64_t displayTime,
                IOSurfaceRef frameSurface,
                CGDisplayStreamUpdateRef updateRef)
    {
        _StreamerDisplayStreamFrameAvailable(streamer,
                                             status,
                                             displayTime,
                                             frameSurface,
                                             updateRef);
    };

    displayStream = CGDisplayStreamCreate(streamer->display.ID,
                                          width,
                                          height,
                                          'BGRA',
                                          NULL,
                                          handler);
    if(displayStream == NULL) {
        return -1;
    }

    streamer->streams.displayStream = displayStream;

    /* Setup the VNC screen */
    screenInfo = rfbGetScreen(0, NULL, (int)width, (int)height, 8, 3, BPP);
    if(screenInfo == NULL) {
        CFRelease(displayStream);
        return -1;
    }
    
    framebufferSize = width * height * (size_t)4;
    screenInfo->frameBuffer = malloc(framebufferSize);
    memset(screenInfo->frameBuffer, 0, sizeof(*screenInfo->frameBuffer));

    streamer->streams.screenInfo = screenInfo;
    streamer->streams.framebufferSize = framebufferSize;

    /* Full first stream */
    streamer->streams.lastFullStream = 0.0;

    /* Start the VNC server */
    /* TODO: Prebind the socket to catch errors */
    rfbInitServer(screenInfo);


    /* Schedule the display stream in the runloop */
    streamSource = CGDisplayStreamGetRunLoopSource(displayStream);
    CFRunLoopAddSource(CFRunLoopGetMain(), streamSource, kCFRunLoopDefaultMode);
    CGDisplayStreamStart(displayStream);

    return 0;
}

void _StreamerDisplayStreamFrameAvailable(Streamer *streamer,
                                          CGDisplayStreamFrameStatus status,
                                          uint64_t displayTime,
                                          IOSurfaceRef frameSurface,
                                          CGDisplayStreamUpdateRef updateRef)
{
    CGDisplayStreamUpdateRectType mode = kCGDisplayStreamUpdateReducedDirtyRects;
    const CGRect *rectangles;
    size_t numRectangles, i;

    if(status != kCGDisplayStreamFrameStatusFrameComplete) {
        return;
    }

    rectangles = CGDisplayStreamUpdateGetRects(updateRef, mode, &numRectangles);
    for(i = 0; i < numRectangles; i++) {
        _StreamerUpdateInternalFramebuffer(streamer,
                                           rectangles[i],
                                           frameSurface);
        break;
    }

    if(rfbIsActive(streamer->streams.screenInfo)) {
        rfbProcessEvents(streamer->streams.screenInfo,
                         streamer->streams.screenInfo->deferUpdateTime*1000);
    }

    /* We always do a full sync => cpu load */
    usleep(0.1*1.e6);
}

void _StreamerUpdateInternalFramebuffer(Streamer *streamer,
                                        CGRect srcRect,
                                        IOSurfaceRef frameSurface)
{
    CGImageRef image;
    CGColorSpaceRef colorSpace;
    CGContextRef rgbContext;
    size_t height, bpr;
    char *bitmap;
    CGRect imageFrame;
    CFAbsoluteTime now;

    /* Full stream if necessar */
    now = CFAbsoluteTimeGetCurrent();
    if(now - streamer->streams.lastFullStream > FULL_STREAM_INTERVAL ||
       1 /* Always full sync */)
    {
        srcRect.origin = CGPointZero;
        srcRect.size = streamer->display.size;

        streamer->streams.lastFullStream = now;
    }

    image = CGDisplayCreateImageForRect(streamer->display.ID, srcRect);

    /* Create an RGB context */
    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

    bpr = BPR(srcRect.size.width);
    height = (size_t)srcRect.size.height;
    bitmap = malloc(bpr * height);

    rgbContext = CGBitmapContextCreate(bitmap,
                                       (size_t)srcRect.size.width,
                                       (size_t)srcRect.size.height,
                                       8, bpr,
                                       colorSpace,
                                       kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(colorSpace);

    /* Draw the image */
    imageFrame.origin = CGPointZero;
    imageFrame.size.width = CGImageGetWidth(image);
    imageFrame.size.height = CGImageGetHeight(image);
    CGContextDrawImage(rgbContext, imageFrame, image);

    /* Update VNC buffer */
    _StreamerPutBitmap(streamer, srcRect, bitmap, bpr, height);

    /* Clean up */
    free(bitmap);
    CGContextRelease(rgbContext);
    CGImageRelease(image);

    /* Mark dirty */
    rfbMarkRectAsModified(streamer->streams.screenInfo,
                          (int)srcRect.origin.x,
                          (int)srcRect.origin.y,
                          (int)srcRect.origin.x + (int)srcRect.size.width,
                          (int)srcRect.origin.y + (int)srcRect.size.height);
}

void _StreamerPutBitmap(Streamer *streamer, CGRect srcRect,
                        char *gldata, size_t rowBytes, size_t height)
{
    size_t bpr = BPR(srcRect.size.width);

    size_t vncStartRow, vncEndRow, vncRow;
    size_t vncColumn;
    size_t srcRow;
    char *framebuffer;

    framebuffer = streamer->streams.screenInfo->frameBuffer;

    vncStartRow = (size_t)srcRect.origin.y;
    vncEndRow = vncStartRow + (size_t)srcRect.size.height;

    vncColumn = (size_t)srcRect.origin.x * BPP;

    for(vncRow = vncStartRow, srcRow = 0;
        vncRow < vncEndRow;
        vncRow++, srcRow++)
    {
        memcpy(&(framebuffer[vncRow*bpr + vncColumn]),
               &(gldata[srcRow * rowBytes]),
               rowBytes);
    }
}

void _StreamerDebugWriteFramebuffer(Streamer *streamer) {
    char *filename = malloc(50);
    snprintf(filename, 50, "/tmp/raw-%f.rgba", CFAbsoluteTimeGetCurrent());

    FILE *fh = fopen(filename, "w");
    if(fh != NULL) {
        fwrite(streamer->streams.screenInfo->frameBuffer,
               streamer->streams.framebufferSize, 1, fh);
    }
    fclose(fh);
    free(filename);
}