#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>



static BOOL commentsOpen = NO;
static BOOL reelPlaying = YES;
static double playbackSpeed = 1.0;
static __unsafe_unretained id currentReelCell = nil;
static NSArray *feed = nil;
static NSString *currentMediaPk = nil;
static NSInteger lastPauseReason = -1;


@interface NSObject (ScrollPartyMediaIdentifiers)
- (NSString *)mediaPk;
- (NSString *)saveId;
@end



static NSInteger getIndexOfMediaPk(id mediaPk) {
    if (!mediaPk || !feed) {
        return NSNotFound;
    }

    for (NSInteger i = 0; i < (NSInteger)feed.count; i++) {
        id item = feed[i];
        if ([[item saveId] isEqual:mediaPk]) {
            return i;
        }
    }
    return NSNotFound;
}


/*
Helper method to detect direction of reel change (next or previous) based on the current and next mediaPk. 
Returns 1 for next, -1 for previous, and 0 for unknown.
*/
static NSInteger detectReelDirection(id oldMediaPk, id newMediaPk) {
    if (!oldMediaPk || !newMediaPk || !feed) {
        return 0; // Unknown direction
    }
    
    
    NSInteger currentIndex = getIndexOfMediaPk(oldMediaPk);
    if (currentIndex == NSNotFound) {
        return 0; // Unknown direction
    }

    if (currentIndex + 1 < (NSInteger)feed.count) {
        id nextItem = feed[currentIndex + 1];
        if ([[nextItem saveId] isEqual:newMediaPk]) {
            return 1; // Next
        }
    }

    if (currentIndex > 0) {
        id previousItem = feed[currentIndex - 1];
        if ([[previousItem saveId] isEqual:newMediaPk]) {
            return -1; // Previous
        }
    }
    return 0; // Unknown direction    

}


%hook IGSundialViewerVideoCell

// Method to detect if the reel is paused due to a transition
- (void)pauseWithReason:(NSInteger)reason {
    lastPauseReason = reason;
    %orig;
}



// Method to detect when the reel is paused
- (void)videoViewDidPause:(id)videoView
{
    %orig;

    if (lastPauseReason == 3) {
        return; // Ignore pause due to transition
    } 

    if (reelPlaying) {
        reelPlaying = NO;
        NSLog(@"[ScrollParty Detection] Reel paused");
    }
}


// Method to detect reel stoppage
- (void)videoViewDidStop:(id)videoView
{
    %orig;
    //reelPlaying = NO;
    //NSLog(@"[ScrollParty Detection] XXXXXXXXXXXX");
}

// Method to detect when the reel is played or changed
- (void)sundialVideoPlaybackViewDidStartPlaying:(id)playbackView {
    %orig;

    NSString *nextMediaPk = [(id)self mediaPk];

    if (currentReelCell != self) {

        if (currentReelCell == nil) {
            NSLog(@"[ScrollParty Detection] Reels opened");
        }

        if (currentMediaPk != nil){
            NSInteger direction = detectReelDirection(currentMediaPk, nextMediaPk);
            if (direction == 1) {
                //NSLog(@"[ScrollParty Detection] Next Reel played");
            } else if (direction == -1) {
                //NSLog(@"[ScrollParty Detection] Previous Reel played");
            } else {
                //NSLog(@"[ScrollParty Detection] Reel changed to unknown");
            }
        } 
    }else {
        if (!reelPlaying) {
            NSLog(@"[ScrollParty Detection] Reel played");
        }
    }

    currentReelCell = self;
    currentMediaPk = nextMediaPk;

    reelPlaying = YES;
}


// Method to detect when speed is changed
- (void)setPlaybackSpeed:(float)speed {
    %orig;

    if (fabs(speed - playbackSpeed) < 0.01f) {
        return;
    }

    playbackSpeed = speed;

    NSLog(@"[ScrollParty Detection] Playback speed = %.2fx", speed);
}
%end



%hook IGCommentThreadViewController

// Method to detect when comments are opened
- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!commentsOpen) {
        commentsOpen = YES;

        NSLog(@"[ScrollParty Detection] Comments opened");
    }
}

// Method to detect when comments are closed
- (void)viewDidDisappear:(BOOL)animated {
    %orig;

    if (commentsOpen) {
        commentsOpen = NO;

        NSLog(@"[ScrollParty Detection] Comments closed");
    }
}

%end





%group swiftHooks

%hook dataSource

- (id)objectsForListAdapter:(id)arg1 {
    NSArray *original_feed = %orig;
    NSMutableArray *filtered_feed = [NSMutableArray array];
    for (id item in original_feed) {
        if ([item isKindOfClass:%c(IGAdItem)]) {
            continue;
        }
        [filtered_feed addObject:item];
    }

    feed = [filtered_feed copy];
    return filtered_feed;
}

%end


%end


%hook IGSundialUnconnectedFeedNetworkSource

// Method to detect when reels are refreshed
- (void)sundialFeedNetworkSource:(id)source
willStartNewFeedSessionWithId:(id)newSessionId
               previousSessionId:(id)previousSessionId
                    prefetchType:(NSInteger)prefetchType {

    
    feed = nil;
    commentsOpen = NO;
    reelPlaying = YES;
    playbackSpeed = 1.0;
    currentReelCell = nil;
    currentMediaPk = nil;
    lastPauseReason = -1;
    %orig;

    if (prefetchType == 0) {
        NSLog(@"[ScrollParty Detection] Reels refreshed");
    }
}


%end



%hook IGSundialUnconnectedFeedNetworkSource

- (void)activeSectionDidChangeFrom:(NSInteger)oldSection
                               to:(NSInteger)newSection
{
    %orig;
    if (oldSection < 0 || newSection < 0) {
        return; // App boot
    }

    if (newSection == oldSection + 1) {
        NSLog(@"[ScrollParty Detection] Next Reel played");
    }
    else if (newSection == oldSection - 1) {
        NSLog(@"[ScrollParty Detection] Previous Reel played");
    }
    else if (newSection != oldSection) {
        NSLog(@"[ScrollParty Detection] Reel changed to unknown");
    }
}

%end

%ctor {

    %init;
    NSLog(@"[ScrollParty] Tweak loaded");
    


    Class dataSourceClass = objc_getClass("IGSundialFeedDataSource.IGSundialFeedDataSource");


    if (dataSourceClass) {
        %init(swiftHooks, dataSource = dataSourceClass);
        NSLog(@"[ScrollParty] IGSundialFeedDataSource hooked");
    }else {
        NSLog(@"[ScrollParty] Failed to hook IGSundialFeedDataSource");
    }

}