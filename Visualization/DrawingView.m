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

static const NSInteger BUFFER_SIZE = 512;

@implementation DrawingView {
    int sckt;
    long len, status;
    
    int frameCount;
    
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
    frameCount = 0;
    
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
    
    char packetBuffer[BUFFER_SIZE];
    char packetLengthBuffer[4];
    NSMutableString *frameBuffer = [NSMutableString stringWithCapacity:0];
    
    // Assume socket to be packet-aligned, that is the first
    // three bytes will be the next packet length.
    // End of frame is reached on a packet of length 1
    while(TRUE) {

        status = recv(sckt, packetLengthBuffer, 3, 0);
        if(status < 1) {
            perror("recv");
            exit(1);
        }
        
        packetLengthBuffer[3] = '\0';
        int packetLength = atoi(packetLengthBuffer);
        
        status = recv(sckt, packetBuffer, packetLength, 0);
        if(status < 1) {
            perror("recv");
            exit(1);
        }
        packetBuffer[packetLength] = '\0';
        
        frameCount++;
        
        // One-byte packet ends the frame
        if(packetLength == 1) {
            break;
        }
        
        NSString *packet = [NSString stringWithCString:packetBuffer encoding:NSASCIIStringEncoding];
        [frameBuffer appendFormat:@"%@,", packet];
    }
    
    return [NSString stringWithFormat:@"[ %@ {} ]", frameBuffer];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSString *current = [self readFrame];

    
    NSError *error = nil;
    NSArray* object = [NSJSONSerialization
                 JSONObjectWithData:[current dataUsingEncoding:NSUTF8StringEncoding]
                 options:0
                 error:&error];
    
    if(error) {
        NSLog(@"Malformed JSON string");
        exit(1);
    }
    
    //[super drawRect:dirtyRect];
    //[[NSColor clearColor] setFill];
    //NSRectFill(dirtyRect);
    
    for(NSDictionary* dict in object) {
        if(dict[@"x1"] == NULL) {
            continue;
        }
        
        NSPoint p1 = NSMakePoint([dict[@"x1"] floatValue], [dict[@"y1"] floatValue]);
        NSPoint p2 = NSMakePoint([dict[@"x2"] floatValue], [dict[@"y2"] floatValue]);

        [self drawLineFrom:p1 to:p2];
    }
}

- (void)drawLineFrom:(NSPoint)x1 to:(NSPoint)x2
{
    NSBezierPath* thePath = [NSBezierPath bezierPath];
    
    [thePath moveToPoint:x1];
    [thePath lineToPoint:x2];
    
    [thePath stroke];
}

@end
