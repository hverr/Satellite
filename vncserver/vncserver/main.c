//
//  main.c
//  vncserver
//
//  Created by Henri Verroken on 14/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//


#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <rfb/rfb.h>

#include "streamer.h"

int main(int argc, const char **argv) {
    Streamer streamer;

    if(!StreamerInit(&streamer, CGMainDisplayID())) {
        fprintf(stderr, "error: StreamerInit: %s\n",
                StreamerCopyLastError(&streamer));
        exit(1);
    }

    if(StreamerStartStreaming(&streamer) != 0) {
        fprintf(stderr, "error StreamerStartStreaming: %s\n",
                StreamerCopyLastError(&streamer));
        exit(1);
    }

    CFRunLoopRun();
}