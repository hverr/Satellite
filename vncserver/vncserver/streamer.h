//
//  streamer.h
//  vncserver
//
//  Created by Henri Verroken on 14/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//

#ifndef VNCSERVER_STREAMER_H
#define VNCSERVER_STREAMER_H

#include <ApplicationServices/ApplicationServices.h>
#include <rfb/rfb.h>

typedef struct {
    struct {
        CGDirectDisplayID ID;
        CGSize size;
    } display;

    struct {
        CGDisplayStreamRef displayStream;
        rfbScreenInfoPtr screenInfo;
        size_t framebufferSize;
        CFAbsoluteTime lastFullStream;
    } streams;

    const char *lastError;
} Streamer;

/**
 * Initialize a streamer object
 *
 * @param displayID
 *  The ID of the display to stream
 *
 * @return
 *  Returns NULL when initialization failed. Use `StreamerCopyLastError` the get
 *  the latest available error.
 */
Streamer *StreamerInit(Streamer *streamer, CGDirectDisplayID displayID);

/**
 * Duplicate the latest error to a string buffer
 *
 * @return
 *  A copy of the latest error or null if no error message is available.
 *  The result should be free'd.
 */
char *StreamerCopyLastError(Streamer *streamer);


/**
 * Start streaming the display over VNC
 *
 * @return
 *  Returns 0 on success, -1 on failure
 */
int StreamerStartStreaming(Streamer *streamer);
#endif