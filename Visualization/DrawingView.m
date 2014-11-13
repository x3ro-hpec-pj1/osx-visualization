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
#import "CircularBuffer.h"

static const NSInteger BUFFER_SIZE = 65536;

@implementation DrawingView {
    int sckt;
    long len, status;
    
    int frameCount;
    
    NSMutableString *currentFrame;
    
    struct sockaddr_un remote;

    CircularBuffer *buffer;

}

- (void)awakeFromNib
{
    buffer = [CircularBuffer withCapacity:1000];

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
    [NSThread detachNewThreadSelector:@selector(receiveThread:) toTarget:self withObject:self];
}

-(void)redrawClock:(id)param{
    while(TRUE)
    {
        [self setNeedsDisplay:TRUE];
        usleep(16000);
    }
}

-(void)receiveThread:(id)param{
    while(TRUE) {
        [buffer enqueue:[self readFrame]];
    }
}



- (NSString*)readFrame {
    
    char packetBuffer[BUFFER_SIZE];
    char packetLengthBuffer[6];
    //NSMutableString *frameBuffer = [NSMutableString stringWithCapacity:0];
    NSString *packet;
    
    // Assume socket to be packet-aligned, that is the first
    // three bytes will be the next packet length.
    // End of frame is reached on a packet of length 1
    //while(TRUE) {
        status = recv(sckt, packetLengthBuffer, 5, 0);
        if(status < 1) {
            perror("recv1");
            exit(1);
        }
        
        packetLengthBuffer[5] = '\0';
        int packetLength = atoi(packetLengthBuffer);
        int bytesRead = 0;

        while(bytesRead < packetLength) {
            status = recv(sckt, packetBuffer+bytesRead, packetLength-bytesRead, 0);
            bytesRead += status;
            if(status < 1) {
                perror("recv2");
                exit(1);
            }
        }
        packetBuffer[packetLength] = '\0';

        packet = [NSString stringWithCString:packetBuffer encoding:NSASCIIStringEncoding];
        //[frameBuffer appendFormat:@"%@,", packet];
        //[self processDrawCommand:packet];
    //}

    return packet;
    //return [NSString stringWithFormat:@"[ %@ {} ]", frameBuffer];
}

- (void)processDrawCommand:(NSString*)cmd {
    NSError *error = nil;
    NSArray* array = [NSJSONSerialization
                       JSONObjectWithData:[cmd dataUsingEncoding:NSUTF8StringEncoding]
                       options:0
                       error:&error];

    if(error) {
        NSLog(@"Malformed JSON string");
        exit(1);
    }

    for(NSDictionary *dict in array) {
        if([dict[@"type"] isEqual: @"line"]) {
            NSPoint p1 = NSMakePoint([dict[@"x1"] floatValue], [dict[@"y1"] floatValue]);
            NSPoint p2 = NSMakePoint([dict[@"x2"] floatValue], [dict[@"y2"] floatValue]);
            [self drawLineFrom:p1 to:p2];
        } else if ([dict[@"type"] isEqual: @"text"]) {

            NSMutableParagraphStyle *textStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
            NSFont *textFont = [NSFont systemFontOfSize:16];
            NSDictionary *dictionary = @{ NSFontAttributeName: textFont,
                                          NSParagraphStyleAttributeName: textStyle,
                                          NSForegroundColorAttributeName: [NSColor redColor]};

            [dict[@"text"] drawAtPoint:NSMakePoint([dict[@"x"] floatValue], [dict[@"y"] floatValue]) withAttributes:dictionary];
            [[NSColor blackColor] set];
        }
    }
}



- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSString *current;
    int max_draws = 1;
    while(max_draws > 0 && (current = [buffer dequeue]) != nil) {

        [[NSColor whiteColor] set];
        NSRectFill(dirtyRect);

        [[NSColor blackColor] set];
        [self processDrawCommand:current];
        max_draws--;
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
