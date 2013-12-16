//
//  DrawingView.m
//  Visualization
//
//  Created by Lucas Jenß on 04/12/13.
//  Copyright (c) 2013 Lucas Jenß. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

#import "DrawingView.h"

static const NSInteger BUFFER_SIZE = 4096;

@implementation DrawingView {
    int sckt;
    long len, status;
    
    NSMutableString *currentFrame;
    
    struct sockaddr_un remote;
}

- (void)awakeFromNib
{
        sckt = socket(AF_UNIX, SOCK_STREAM, 0);
        if(sckt == -1) {
            perror("socket()");
            exit(1);
        }
        
        remote.sun_family = AF_UNIX;
        strcpy(remote.sun_path, "/Users/lucas/testsckt");
        len = strlen(remote.sun_path) + 1 + sizeof(remote.sun_family);
        
        status = connect(sckt, (struct sockaddr *) &remote, (socklen_t) len);
        if(status == -1) {
            perror("connect()");
            exit(1);
        }

    currentFrame = [NSMutableString stringWithCapacity:0];
    
    [NSThread detachNewThreadSelector:@selector(redrawClock:) toTarget:self withObject:self];
    
}

-(void)redrawClock:(id)param{
    while(TRUE)
    {
        [self setNeedsDisplay:TRUE];
        usleep(16000);
    }
}

- (NSString*)readFrame {

    char buffer[BUFFER_SIZE];
    
    while(TRUE) {
        status = recv(sckt, buffer, BUFFER_SIZE, 0);
        if(status < 1) {
            perror("recv");
            exit(1);
        }
        
        int endOfFrame = 0;
        for(int i = 1; i < BUFFER_SIZE; i++) {
            if(buffer[i-1] == '\n' && buffer[i] == '\n') {
                endOfFrame = i;
                break;
            }
        }
    }
    
    return NULL;
}

- (void)drawRect:(NSRect)dirtyRect
{
    
    
    

    if(endOfFrame == 0) {
        NSString *buf = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
        [currentFrame appendString:buf];
        
//        NSLog(@"Could not find frame delimiter in data read from socket");
//        exit(1);
        
    } else {
        NSString *next = [NSString stringWithCString:(buffer + endOfFrame) encoding:NSASCIIStringEncoding];
        [nextFrame appendString:next];
        
        buffer[endOfFrame+1] = '\0';
        NSString *current = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
        [currentFrame appendString:current];
        
        NSLog(@"full frame: \n %@", currentFrame);
    }
    
    
    // draw here
    NSString *current = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    
    
    [currentFrame setString:@""];
    NSMutableString *temp = currentFrame;
    currentFrame = nextFrame;
    nextFrame = temp;
    
    

    

    
    [super drawRect:dirtyRect];
    
    NSPoint x1 = NSMakePoint(50.0, 50.0);
    NSPoint x2 = NSMakePoint(1000.0, 1000.0);
    [self drawLineFrom:x1 to:x2];
    //[NSGraphicsContext restoreGraphicsState];
	
    // Drawing code here.
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW,
//                                            (int64_t)(0));
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
//        [self setNeedsDisplay: YES];
//    });
}

- (void)drawLineFrom:(NSPoint)x1 to:(NSPoint)x2
{
    NSBezierPath* thePath = [NSBezierPath bezierPath];
    
    [thePath moveToPoint:x1];
    [thePath lineToPoint:x2];
    
    [thePath stroke];
}

@end
