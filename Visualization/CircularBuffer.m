//
//  CircularBuffer.m
//  Visualization
//
//  Created by Lucas Jenß on 06/03/14.
//  Copyright (c) 2014 Lucas Jenß. All rights reserved.
//

#import "CircularBuffer.h"

@implementation CircularBuffer

+ (CircularBuffer*)withCapacity:(NSUInteger)capacity {
    CircularBuffer *c = [[CircularBuffer alloc] initWithCapacity:capacity];
    return c;
}

- (CircularBuffer*)initWithCapacity:(NSUInteger)capacity {
    _capacity = capacity;
    enqueuePivot = 0;
    dequeuePivot = 0;
    data = [NSMutableArray arrayWithCapacity:self.capacity];
    for (int i=0; i<self.capacity; i++) {
        [data insertObject:@"" atIndex:i];
    }
    
    modifyCond = [[NSCondition alloc] init];

    full = FALSE;
    empty = TRUE;

    return self;
}

- (void)enqueue:(id)el {
    [modifyCond lock];

    while(full) {
        [modifyCond wait];
    }

    [data replaceObjectAtIndex:enqueuePivot withObject:el];
    enqueuePivot = (enqueuePivot + 1) % (self.capacity);

    full = enqueuePivot == dequeuePivot;
    empty = FALSE;

    [modifyCond signal];
    [modifyCond unlock];
}


- (id)dequeue {
    [modifyCond lock];

    while(empty) {
        [modifyCond wait];
    }

    id el = [data objectAtIndex:dequeuePivot];
    dequeuePivot = (dequeuePivot + 1) % (self.capacity);

    empty = enqueuePivot == dequeuePivot;
    full = FALSE;


    [modifyCond signal];
    [modifyCond unlock];

    return el;
}

- (id)tryDequeue {
    id el;
    [modifyCond lock];

    if(empty) {
        el = nil;
    } else {
        el = [data objectAtIndex:dequeuePivot];
        dequeuePivot = (dequeuePivot + 1) % (self.capacity);

        empty = enqueuePivot == dequeuePivot;
        full = FALSE;
    }

    [modifyCond signal];
    [modifyCond unlock];

    return el;
}

@end
