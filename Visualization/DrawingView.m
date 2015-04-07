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
#include <arpa/inet.h>
#include <sys/socket.h>

#import "DrawingView.h"
#import "CircularBuffer.h"

#define PORT 6871

static const NSInteger BUFFER_SIZE = 65536;


@implementation DrawingView {
    int sckt;
    long len, status;
    
    int frameCount;
    
//    NSMutableString *currentFrame;
    
    struct sockaddr_un remote;
    struct sockaddr_in si_me, si_other;
    int slen;

    CircularBuffer *buffer;

}

- (void)awakeFromNib
{
    stopped = NO;
    buffer = [CircularBuffer withCapacity:1000];

//       sckt = socket(AF_UNIX, SOCK_STREAM, 0);
//        if(sckt == -1) {
//            perror("socket()");
//            exit(1);
//        }
//        
//        remote.sun_family = AF_UNIX;
//        strcpy(remote.sun_path, "/Users/lucas/testsckt");
//        len = strlen(remote.sun_path) + 1 + sizeof(remote.sun_family);
//        
//        status = connect(sckt, (struct sockaddr *) &remote, (socklen_t) len);
//        if(status == -1) {
//            perror("connect()");
//            exit(1);
//        }

    slen = sizeof(si_other);




    //create a UDP socket
    if ((sckt=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1)
    {
        perror("socket()");
        exit(1);
    }

    // zero out the structure
    memset((char *) &si_me, 0, sizeof(si_me));

    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(PORT);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);

    //bind socket to port
    if( bind(sckt, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1)
    {
        perror("bind()");
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

    int recv_len;
    
    // Assume socket to be packet-aligned, that is the first
    // three bytes will be the next packet length.
    // End of frame is reached on a packet of length 1
    //while(TRUE) {
//        status = recv(sckt, packetLengthBuffer, 5, 0);
//        if(status < 1) {
//            perror("recv1");
//            exit(1);
//        }
//

    // Assume socket to be packet-aligned, that is the first
    // three bytes will be the next packet length.
    // End of frame is reached on a packet of length 1

    if ((recv_len = recvfrom(sckt, packetLengthBuffer, 5, 0, (struct sockaddr *) &si_other, &slen)) == -1) {
        perror("recvfrom()");
        exit(1);
    }
    NSLog(@"received: %d", recv_len);
        packetLengthBuffer[5] = '\0';
        int packetLength = atoi(packetLengthBuffer);
        int bytesRead = 0;

        while(bytesRead < packetLength) {
//            status = recv(sckt, packetBuffer+bytesRead, packetLength-bytesRead, 0);
            if ((recv_len = recvfrom(sckt, packetBuffer+bytesRead, packetLength-bytesRead, 0, (struct sockaddr *) &si_other, &slen)) == -1) {
                perror("recvfrom()");
                exit(1);
            }
            bytesRead += recv_len;
            NSLog(@"Bytesread: %d", bytesRead);
//            if(status < 1) {
//                perror("recv2");
//                exit(1);
//            }
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

    int max_coordinate = 5600;
    float ratio = self.frame.size.width / max_coordinate;
    float half_height = self.frame.size.height / 2.0;
    if(zoom > 0) {
        ratio = ratio + (zoom/10.0);
    } else {
        zoom = 0;
    }


    for(NSDictionary *dict in array) {
        if([dict[@"type"] isEqual: @"line"]) {
            NSPoint p1 = NSMakePoint([dict[@"x1"] floatValue] * ratio, [dict[@"y1"] floatValue] * ratio + half_height);
            NSPoint p2 = NSMakePoint([dict[@"x2"] floatValue] * ratio, [dict[@"y2"] floatValue] * ratio + half_height);

            NSInteger color = [dict[@"color"] integerValue];

            float r = ((color >> 24) & 0xFF) / 255.0;
            float g = ((color >> 16) & 0xFF) / 255.0;
            float b = ((color >> 8) & 0xFF) / 255.0;
            float a = ((color) & 0xFF) / 255.0;

            [[NSColor colorWithCalibratedRed:r green:g blue:b alpha:a] set];

            [self drawLineFrom:p1 to:p2];
            [[NSColor blackColor] set];
        } else if ([dict[@"type"] isEqual: @"text"]) {

            NSMutableParagraphStyle *textStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
            NSFont *textFont = [NSFont systemFontOfSize:16];
            NSDictionary *dictionary = @{ NSFontAttributeName: textFont,
                                          NSParagraphStyleAttributeName: textStyle,
                                          NSForegroundColorAttributeName: [NSColor redColor]};

            [dict[@"text"] drawAtPoint:NSMakePoint([dict[@"x"] floatValue] * ratio, [dict[@"y"] floatValue] * ratio + half_height) withAttributes:dictionary];
            [[NSColor blackColor] set];
        }
    }
}



- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    int max_draws = 1;
    while(max_draws > 0) {
        if(!stopped) {
            currentFrame = [buffer dequeue];
            if(currentFrame == nil) {
                break;
            }
        }

        [[NSColor whiteColor] set];
        NSRectFill(dirtyRect);

        [[NSColor blackColor] set];
        [self processDrawCommand:currentFrame];
        max_draws--;
    }
}

- (void)scrollWheel:(NSEvent *)theEvent {
    zoom += [theEvent deltaY];
}

- (void)mouseUp:(NSEvent *)theEvent {
    stopped = !stopped;
}

- (void)drawLineFrom:(NSPoint)x1 to:(NSPoint)x2
{
    NSBezierPath* thePath = [NSBezierPath bezierPath];
    
    [thePath moveToPoint:x1];
    [thePath lineToPoint:x2];
    
    [thePath stroke];
}

@end
