//
//  main.c
//  vncserver
//
//  Created by Henri Verroken on 14/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "Streamer.h"

int main(int argc, const char **argv) {
    @autoreleasepool {
        Streamer *streamer;

        streamer = [[Streamer alloc] initWithDisplayID:kCGDirectMainDisplay];

        [streamer startStreaming:NULL];

        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}