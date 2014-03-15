//
//  CircularBuffer.h
//  Visualization
//
//  Created by Lucas Jenß on 06/03/14.
//  Copyright (c) 2014 Lucas Jenß. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CircularBuffer : NSObject  {
    NSUInteger enqueuePivot;
    NSUInteger dequeuePivot;
    NSMutableArray *data;

    NSCondition *modifyCond;

    BOOL empty;
    BOOL full;
}

@property (readonly) NSUInteger capacity;

+ (CircularBuffer*)withCapacity:(NSUInteger)capacity;

- (void)enqueue:(id)el;
- (id)dequeue;
- (id)tryDequeue;

@end
