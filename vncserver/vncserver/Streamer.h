//
//  Streamer.h
//  vncserver
//
//  Created by Henri Verroken on 16/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>

#import <rfb/rfb.h>

@interface Streamer : NSObject
#pragma mark Init
- (id)initWithDisplayID:(CGDirectDisplayID)displayID;

#pragma mark Properties
@property (nonatomic, assign, readonly) CGDirectDisplayID displayID;

#pragma mark Streaming
- (BOOL)startStreaming:(NSError **)error;
- (void)stopStreaming;
@end
