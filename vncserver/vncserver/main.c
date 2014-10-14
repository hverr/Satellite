//
//  main.c
//  vncserver
//
//  Created by Henri Verroken on 14/10/14.
//  Copyright (c) 2014 hverr. All rights reserved.
//

#include <stdio.h>
#include <rfb/rfb.h>

int main(int argc, const char **argv) {
    rfbScreenInfoPtr server=rfbGetScreen(&argc, (char **)argv,400,300,8,3,4);
    server->frameBuffer=malloc(400*300*4);
    memset(server->frameBuffer, 200, 400*300*4);
    rfbInitServer(server);
    rfbRunEventLoop(server,-1,FALSE);
    return(0);
}

