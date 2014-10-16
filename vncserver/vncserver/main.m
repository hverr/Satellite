//
//  main.c
//  vncserver
//
//  Created by Henri Verroken on 14/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

#import "Streamer.h"

CGDirectDisplayID ChooseDisplayID(void);

int main(int argc, const char **argv) {
    @autoreleasepool {
        Streamer *streamer;

        streamer = [[Streamer alloc] initWithDisplayID:ChooseDisplayID()];

        [streamer startStreaming:NULL];

        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}

CGDirectDisplayID ChooseDisplayID(void) {
    CGDirectDisplayID retVal;

    while(1) {
        CGDirectDisplayID *displayIDs;
        uint32_t count, i;
        int choice;

        CGGetActiveDisplayList(0, NULL, &count);

        displayIDs = malloc(sizeof(*displayIDs) * count);
        CGGetActiveDisplayList(count, displayIDs, &count);

        printf("Connected displays:\n");
        for(i = 0; i < count; i++) {
            CFDictionaryRef cinfo;
            io_service_t port;
            NSString *name = nil;

            port = CGDisplayIOServicePort(displayIDs[i]);

            cinfo = IODisplayCreateInfoDictionary(port, kIODisplayOnlyPreferredName);
            if(cinfo) {
                CFDictionaryRef cnames;

                cnames = CFDictionaryGetValue(cinfo,
                                              CFSTR(kDisplayProductName));
                if(cnames) {
                    const CFStringRef cname = NULL;
                    CFDictionaryGetKeysAndValues(cnames, NULL,
                                                 (const void **)&cname);
                    name = [NSString stringWithString:
                            (__bridge NSString *)cname];
                }
                CFRelease(cinfo);
            }

            printf("\t%i - %s (%d)\n", i, [name  UTF8String],
                   (int)displayIDs[i]);
        }

        printf("Choose a display: ");
        if(scanf("%d", &choice) == 1) {
            if(choice < (int)count) {
                retVal = displayIDs[choice];
                free(displayIDs);
                break;
            }
        }

        free(displayIDs);
    }
    return retVal;
}
