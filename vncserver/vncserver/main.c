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
    uint32_t displaysCount;
    CGDirectDisplayID *displayIDs;

    if(CGGetActiveDisplayList(0, NULL, &displaysCount) != kCGErrorSuccess) {
        fprintf(stderr, "error: CGGetActiveDisplayList: can't get count\n");
        exit(1);
    }

    displayIDs = malloc(sizeof(*displayIDs) * displaysCount);
    if(CGGetActiveDisplayList(displaysCount, displayIDs, &displaysCount)) {
        fprintf(stderr, "error: CGGetActiveDisplayList: can't get IDs\n");
        exit(1);
    }

    for(int i = 0; i < displaysCount; i++) {
        printf("id: %d\n", (int)displayIDs[i]);

        CFDictionaryRef info, localizedNames;
        io_service_t ioPort;

        ioPort = CGDisplayIOServicePort(displayIDs[i]);
        info = IODisplayCreateInfoDictionary(ioPort,
                                             kIODisplayOnlyPreferredName);
        localizedNames = CFDictionaryGetValue(info, CFSTR(kDisplayProductName));
        if(CFDictionaryGetCount(localizedNames) > 0) {
            CFStringRef name;

            CFDictionaryGetKeysAndValues(localizedNames, NULL, &name);
            printf("%d: %s\n", (int)displayIDs[i],
                   CFStringGetCStringPtr(name, kCFStringEncodingUTF8));

        } else {
            printf("%d: unknown\n", (int)displayIDs[i]);
        }

    }

    printf("Using: %d\n", (int)displayIDs[displaysCount - 1]);
    if(!StreamerInit(&streamer, displayIDs[displaysCount - 1])) {
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

    return 0;
}