#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSObject (ScrollPartyMediaMapDebug)
- (id)saveId;
@end

%hook IGMediaMap

- (id)mediaWithDict:(id)dict {
    NSLog(@"[ScrollParty TRACE] IGMediaMap mediaWithDict:");
    NSLog(@"[ScrollParty TRACE]     dict class = %@", [dict class]);

    if ([dict respondsToSelector:@selector(allKeys)]) {
        NSLog(@"[ScrollParty TRACE]     keys = %@", [dict allKeys]);
    }

    id result = %orig;

    NSLog(@"[ScrollParty TRACE]     result class = %@", [result class]);

    if ([result respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     result saveId = %@", [result saveId]);
    }

    return result;
}

- (id)objectWithDict:(id)dict {
    NSLog(@"[ScrollParty TRACE] IGMediaMap objectWithDict:");
    NSLog(@"[ScrollParty TRACE]     dict class = %@", [dict class]);

    if ([dict respondsToSelector:@selector(allKeys)]) {
        NSLog(@"[ScrollParty TRACE]     keys = %@", [dict allKeys]);
    }

    id result = %orig;

    NSLog(@"[ScrollParty TRACE]     result class = %@", [result class]);

    if ([result respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     result saveId = %@", [result saveId]);
    }

    return result;
}

- (id)objectWithPk:(id)pk initialTree:(id)tree {
    NSLog(@"[ScrollParty TRACE] IGMediaMap objectWithPk:initialTree:");
    NSLog(@"[ScrollParty TRACE]     pk = %@", pk);
    NSLog(@"[ScrollParty TRACE]     tree class = %@", [tree class]);

    id result = %orig;

    NSLog(@"[ScrollParty TRACE]     result class = %@", [result class]);

    if ([result respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     result saveId = %@", [result saveId]);
    }

    return result;
}

- (id)constructInstanceWithPK:(id)pk initialTree:(id)tree {
    NSLog(@"[ScrollParty TRACE] IGMediaMap constructInstanceWithPK:initialTree:");
    NSLog(@"[ScrollParty TRACE]     pk = %@", pk);
    NSLog(@"[ScrollParty TRACE]     tree class = %@", [tree class]);

    id result = %orig;

    NSLog(@"[ScrollParty TRACE]     result class = %@", [result class]);

    if ([result respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     result saveId = %@", [result saveId]);
    }

    return result;
}

- (id)getIGMediaWithFragment:(id)fragment error:(id *)error {
    NSLog(@"[ScrollParty TRACE] IGMediaMap getIGMediaWithFragment:error:");
    NSLog(@"[ScrollParty TRACE]     fragment class = %@", [fragment class]);

    id result = %orig;

    NSLog(@"[ScrollParty TRACE]     result class = %@", [result class]);

    if ([result respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     result saveId = %@", [result saveId]);
    }

    if (error && *error) {
        NSLog(@"[ScrollParty TRACE]     error = %@", *error);
    }

    return result;
}

- (id)consolidateDeserializedObject:(id)obj {
    NSLog(@"[ScrollParty TRACE] IGMediaMap consolidateDeserializedObject:");
    NSLog(@"[ScrollParty TRACE]     input class = %@", [obj class]);

    if ([obj respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     input saveId = %@", [obj saveId]);
    }

    id result = %orig;

    NSLog(@"[ScrollParty TRACE]     result class = %@", [result class]);

    if ([result respondsToSelector:@selector(saveId)]) {
        NSLog(@"[ScrollParty TRACE]     result saveId = %@", [result saveId]);
    }

    return result;
}

%end

%ctor {
    %init;
}