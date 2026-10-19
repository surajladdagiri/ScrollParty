#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>


#pragma mark - Global State

static BOOL gCommentsOpen = NO;
static BOOL gReelPlaying = NO;

static double gPlaybackSpeed = 1.0;

static NSInteger gCurrentReelIndex = NSNotFound;
static CGFloat gScrollStartY = 0.0;


#pragma mark - Logging

#define SPLOG(fmt, ...) \
    NSLog(@"[ScrollParty TRACE] " fmt, ##__VA_ARGS__)



#pragma mark ============================================================
#pragma mark IGSundialViewerVideoCell
#pragma mark ============================================================

%hook IGSundialViewerVideoCell


#pragma mark - Actual playback callbacks


// We already know this one works.
- (void)videoViewDidPause:(id)videoView
{
    %orig;

    gReelPlaying = NO;

    SPLOG(@"PLAYBACK -> PAUSED");
    SPLOG(@"    videoView=%@", videoView);
    SPLOG(@"    videoView class=%@",
          NSStringFromClass([videoView class]));
}


// This apparently does NOT fire in your current Instagram build,
// but we leave it here for comparison.
- (void)videoViewDidUnpause:(id)videoView
{
    %orig;

    gReelPlaying = YES;

    SPLOG(@"PLAYBACK -> videoViewDidUnpause:");
}


// This is a much stronger candidate for actual playback starting.
- (void)sundialVideoPlaybackViewDidStartPlaying:(id)playbackView
{
    %orig;

    gReelPlaying = YES;

    SPLOG(@"PLAYBACK -> STARTED PLAYING");
    SPLOG(@"    playbackView=%@", playbackView);
    SPLOG(@"    playbackView class=%@",
          NSStringFromClass([playbackView class]));
}


- (void)videoViewDidStop:(id)videoView
{
    %orig;

    gReelPlaying = NO;

    SPLOG(@"PLAYBACK -> STOPPED");
}


- (void)videoViewDidStall:(id)videoView
{
    %orig;

    SPLOG(@"PLAYBACK -> STALLED");
}


- (void)videoViewDidUnstall:(id)videoView
{
    %orig;

    SPLOG(@"PLAYBACK -> UNSTALLED");
}


- (void)videoViewDidPlayThroughToCompletion:(id)videoView
{
    %orig;

    SPLOG(@"PLAYBACK -> COMPLETED");
}


- (void)videoViewItemTimeFullyLoaded:(id)videoView
{
    %orig;

    SPLOG(@"PLAYBACK -> ITEM FULLY LOADED");
}


- (void)sundialVideoPlaybackViewDidLoadVideo:(id)playbackView
{
    %orig;

    SPLOG(@"PLAYBACK -> VIDEO LOADED");
}


- (void)sundialVideoPlaybackViewDidAdoptPreconfiguredPlayer:(id)playbackView
{
    %orig;

    SPLOG(@"PLAYBACK -> ADOPTED PRECONFIGURED PLAYER");
}



#pragma mark - Playback commands


- (void)prepareForPlayback
{
    SPLOG(@"COMMAND -> prepareForPlayback");

    %orig;
}


- (void)playWithReason:(NSInteger)reason
{
    SPLOG(@"COMMAND -> playWithReason: %ld",
          (long)reason);

    %orig;
}


- (void)pauseWithReason:(NSInteger)reason
{
    SPLOG(@"COMMAND -> pauseWithReason: %ld",
          (long)reason);

    %orig;
}


- (void)stopWithReason:(NSInteger)reason
{
    SPLOG(@"COMMAND -> stopWithReason: %ld",
          (long)reason);

    %orig;
}



#pragma mark - Playback speed


- (void)setPlaybackSpeed:(float)speed
{
    SPLOG(@"SPEED -> setPlaybackSpeed: %.3fx", speed);

    %orig;

    gPlaybackSpeed = speed;

    SPLOG(@"STATE -> playbackSpeed = %.3fx",
          gPlaybackSpeed);
}


// Instagram's explicit long-press 2x callbacks.
- (void)controlsOverlayControllerDidStartUFILongPress2xSpeed:(id)controller
{
    SPLOG(@"SPEED -> START UFI LONG PRESS 2X");

    %orig;
}


- (void)controlsOverlayControllerDidStopUFILongPress2xSpeed:(id)controller
{
    SPLOG(@"SPEED -> STOP UFI LONG PRESS 2X");

    %orig;
}



#pragma mark - Gestures


- (void)gestureController:(id)controller
      didObserveSingleTap:(id)gesture
{
    SPLOG(@"GESTURE -> SINGLE TAP");

    %orig;
}


- (void)gestureController:(id)controller
      didObserveDoubleTap:(id)gesture
{
    SPLOG(@"GESTURE -> DOUBLE TAP");

    %orig;
}


- (void)gestureController:(id)controller
 didObserveLongPressBegin:(id)gesture
{
    SPLOG(@"GESTURE -> LONG PRESS BEGIN");

    %orig;
}


- (void)gestureController:(id)controller
didObserveLongPressChange:(id)gesture
{
    // Potentially noisy.
    SPLOG(@"GESTURE -> LONG PRESS CHANGE");

    %orig;
}


- (void)gestureController:(id)controller
   didObserveLongPressEnd:(id)gesture
{
    SPLOG(@"GESTURE -> LONG PRESS END");

    %orig;
}


- (void)gestureController:(id)controller
     didObserveSwipeBegin:(id)arg
    withGestureRecognizer:(id)recognizer
{
    SPLOG(@"GESTURE -> SWIPE BEGIN");

    %orig;
}


- (void)gestureController:(id)controller
       didObserveSwipeEnd:(id)arg
    withGestureRecognizer:(id)recognizer
{
    SPLOG(@"GESTURE -> SWIPE END");

    %orig;
}



#pragma mark - Comment entry points


- (void)controlsOverlayControllerDidTapCommentButton:(id)controller
                                       withKeyboard:(BOOL)withKeyboard
                           commentThreadEntryPoint:(NSInteger)entryPoint
                                   targetCommentId:(id)targetCommentId
{
    SPLOG(@"COMMENTS -> COMMENT BUTTON CALLBACK");
    SPLOG(@"    keyboard=%d", withKeyboard);
    SPLOG(@"    entryPoint=%ld", (long)entryPoint);
    SPLOG(@"    targetCommentId=%@", targetCommentId);

    %orig;
}


- (void)controlsOverlayControllerDidTapCommentPromptButton:(id)controller
                                  commentThreadEntryPoint:(NSInteger)entryPoint
{
    SPLOG(@"COMMENTS -> COMMENT PROMPT CALLBACK");
    SPLOG(@"    entryPoint=%ld", (long)entryPoint);

    %orig;
}


%end



#pragma mark ============================================================
#pragma mark IGSundialFeedViewController
#pragma mark ============================================================

%hook IGSundialFeedViewController


#pragma mark - Feed scrolling


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    gScrollStartY = scrollView.contentOffset.y;

    SPLOG(@"FEED -> BEGIN DRAG");
    SPLOG(@"    y=%.2f", gScrollStartY);

    %orig;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    /*
     * Uncomment ONLY while debugging.
     * This can produce huge amounts of logging.
     */

    /*
    SPLOG(@"FEED -> SCROLL y=%.2f",
          scrollView.contentOffset.y);
    */

    %orig;
}


- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
{
    SPLOG(@"FEED -> END DRAG");
    SPLOG(@"    y=%.2f",
          scrollView.contentOffset.y);

    %orig;
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGFloat endY = scrollView.contentOffset.y;
    CGFloat difference = endY - gScrollStartY;

    SPLOG(@"FEED -> END DECELERATION");
    SPLOG(@"    startY=%.2f", gScrollStartY);
    SPLOG(@"    endY=%.2f", endY);
    SPLOG(@"    delta=%.2f", difference);

    if (difference > 10.0) {

        SPLOG(@"FEED -> POSSIBLE NEXT REEL");

    } else if (difference < -10.0) {

        SPLOG(@"FEED -> POSSIBLE PREVIOUS REEL");
    }

    %orig;
}


- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    SPLOG(@"FEED -> END SCROLLING ANIMATION");
    SPLOG(@"    y=%.2f",
          scrollView.contentOffset.y);

    %orig;
}


- (void)scrollViewDidEndScrolling:(UIScrollView *)scrollView
{
    SPLOG(@"FEED -> END SCROLLING");
    SPLOG(@"    y=%.2f",
          scrollView.contentOffset.y);

    %orig;
}



#pragma mark - Explicit Reel navigation


- (void)advanceToNextItemWithNavigationAction:(NSInteger)action
{
    SPLOG(@"NAVIGATION -> advanceToNextItemWithNavigationAction: %ld",
          (long)action);

    %orig;
}


- (void)rewindToPreviousItemWithNavigationAction:(NSInteger)action
{
    SPLOG(@"NAVIGATION -> rewindToPreviousItemWithNavigationAction: %ld",
          (long)action);

    %orig;
}


- (void)advanceToItemIndex:(NSInteger)index
      withNavigationAction:(NSInteger)action
{
    SPLOG(@"NAVIGATION -> advanceToItemIndex: %ld action=%ld",
          (long)index,
          (long)action);

    %orig;
}


%end



#pragma mark ============================================================
#pragma mark IGCommentThreadViewController
#pragma mark ============================================================

%hook IGCommentThreadViewController


- (void)viewWillAppear:(BOOL)animated
{
    SPLOG(@"COMMENTS VC -> viewWillAppear:");

    %orig;
}


- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    gCommentsOpen = YES;

    SPLOG(@"COMMENTS VC -> viewDidAppear:");
    SPLOG(@"STATE -> commentsOpen = YES");
}


- (void)viewWillDisappear:(BOOL)animated
{
    SPLOG(@"COMMENTS VC -> viewWillDisappear:");

    %orig;
}


- (void)viewDidDisappear:(BOOL)animated
{
    %orig;

    gCommentsOpen = NO;

    SPLOG(@"COMMENTS VC -> viewDidDisappear:");
    SPLOG(@"STATE -> commentsOpen = NO");
}


- (void)_didTapDismiss
{
    SPLOG(@"COMMENTS VC -> _didTapDismiss");

    %orig;
}


- (void)presentationDidCompleteForPresenter:(id)presenter
{
    SPLOG(@"COMMENTS VC -> presentationDidCompleteForPresenter:");

    %orig;
}


- (void)presentationDidDismissForPresenter:(id)presenter
{
    SPLOG(@"COMMENTS VC -> presentationDidDismissForPresenter:");

    %orig;
}


- (void)partialModalSheetDidDismiss:(id)sheet
{
    SPLOG(@"COMMENTS VC -> partialModalSheetDidDismiss:");

    %orig;
}


- (void)partialModalSheet:(id)sheet
           didChangeState:(NSUInteger)state
{
    SPLOG(@"COMMENTS VC -> partialModalSheet state=%lu",
          (unsigned long)state);

    %orig;
}


%end



#pragma mark ============================================================
#pragma mark Swift classes
#pragma mark ============================================================

/*
 *
 * IMPORTANT:
 *
 * Both Swift classes are placed inside ONE group.
 *
 * Logos aliases:
 *
 *   IGSundialViewerVideoSectionController
 *        ->
 *   IGSundialVideoSC.IGSundialViewerVideoSectionController
 *
 *
 *   IGSundialATNChainObserver
 *        ->
 *   IGSundialFeedViewController.IGSundialATNChainObserver
 *
 */




#pragma mark - IGSundialViewerVideoSectionController

%hook IGSundialViewerVideoSectionController


- (void)fastForwardController:(id)controller
           didChangeSpeedFrom:(double)fromSpeed
                           to:(double)toSpeed
              isUserInitiated:(BOOL)isUserInitiated
{
    SPLOG(@"SWIFT VIDEO SECTION -> SPEED CHANGE");
    SPLOG(@"    from=%.2f", fromSpeed);
    SPLOG(@"    to=%.2f", toSpeed);
    SPLOG(@"    userInitiated=%d", isUserInitiated);

    %orig;

    gPlaybackSpeed = toSpeed;
}


- (void)commentThreadViewControllerDidDismiss:(id)controller
{
    SPLOG(@"SWIFT VIDEO SECTION -> COMMENT THREAD DISMISSED");

    %orig;
}


- (void)presentCommentsViewControllerWithPreviewCommentID:(id)previewCommentID
                                                sortOrder:(id)sortOrder
                                         truncateCaption:(BOOL)truncateCaption
                                   shouldDisplayKeyboard:(BOOL)shouldDisplayKeyboard
                                shouldDisplayNudgeBanner:(BOOL)shouldDisplayNudgeBanner
                                 commentThreadEntryPoint:(NSInteger)entryPoint
{
    SPLOG(@"SWIFT VIDEO SECTION -> PRESENT COMMENTS");

    %orig;
}


- (void)advanceToNextReel
{
    SPLOG(@"SWIFT VIDEO SECTION -> advanceToNextReel");

    %orig;
}


%end



#pragma mark - IGSundialATNChainObserver

%hook IGSundialATNChainObserver


- (void)sundialViewerViewController:(id)viewController
               didUpdateActiveVideo:(id)video
                            atIndex:(NSInteger)index
{
    SPLOG(@"ATN -> ACTIVE VIDEO CALLBACK");
    SPLOG(@"    index=%ld", (long)index);
    SPLOG(@"    video=%@", video);
    SPLOG(@"    videoClass=%@",
          NSStringFromClass([video class]));
    SPLOG(@"    viewerClass=%@",
          NSStringFromClass([viewController class]));

    %orig;


    if (gCurrentReelIndex == NSNotFound) {

        gCurrentReelIndex = index;

        SPLOG(@"STATE -> initialReelIndex=%ld",
              (long)index);

        return;
    }


    if (index != gCurrentReelIndex) {

        NSInteger previousIndex =
            gCurrentReelIndex;

        gCurrentReelIndex =
            index;

        SPLOG(@"STATE -> Reel changed: %ld -> %ld",
              (long)previousIndex,
              (long)index);


        if (index > previousIndex) {

            SPLOG(@"STATE -> NEXT REEL");

        } else {

            SPLOG(@"STATE -> PREVIOUS REEL");
        }
    }
}


- (void)sundialViewerViewControllerDidRefresh
{
    SPLOG(@"ATN -> FEED REFRESH");

    %orig;

    gCurrentReelIndex =
        NSNotFound;
}


- (void)sundialViewerViewControllerDidInsertQueuedMedias
{
    SPLOG(@"ATN -> INSERTED QUEUED MEDIAS");

    %orig;
}


- (void)sundialViewerViewControllerDidEndShowingActiveVideo:(id)viewController
{
    SPLOG(@"ATN -> END SHOWING ACTIVE VIDEO");

    %orig;
}


%end





#pragma mark ============================================================
#pragma mark Constructor
#pragma mark ============================================================

%ctor
{
    @autoreleasepool {

        NSLog(@"[ScrollParty Detection] ========================================");
        NSLog(@"[ScrollParty Detection] Diagnostic tweak loading");
        NSLog(@"[ScrollParty Detection] ========================================");


        Class videoCell =
            objc_getClass("IGSundialViewerVideoCell");

        Class feedController =
            objc_getClass("IGSundialFeedViewController");

        Class commentController =
            objc_getClass("IGCommentThreadViewController");

        Class videoSectionController =
            objc_getClass(
                "IGSundialVideoSC.IGSundialViewerVideoSectionController"
            );

        Class atnObserver =
            objc_getClass(
                "IGSundialFeedViewController.IGSundialATNChainObserver"
            );


        if (videoCell) {
    NSLog(@"[ScrollParty Detection] VideoCell = %@", videoCell);
} else {
    NSLog(@"[ScrollParty Detection] VideoCell = NOT FOUND");
}

if (feedController) {
    NSLog(@"[ScrollParty Detection] FeedController = %@", feedController);
} else {
    NSLog(@"[ScrollParty Detection] FeedController = NOT FOUND");
}

if (commentController) {
    NSLog(@"[ScrollParty Detection] CommentController = %@", commentController);
} else {
    NSLog(@"[ScrollParty Detection] CommentController = NOT FOUND");
}

if (videoSectionController) {
    NSLog(@"[ScrollParty Detection] VideoSectionController = %@", videoSectionController);
} else {
    NSLog(@"[ScrollParty Detection] VideoSectionController = NOT FOUND");
}

if (atnObserver) {
    NSLog(@"[ScrollParty Detection] ATNObserver = %@", atnObserver);
} else {
    NSLog(@"[ScrollParty Detection] ATNObserver = NOT FOUND");
}


        /*
         * Everything now belongs to the DEFAULT Logos group.
         *
         * The normal Objective-C hooks are resolved normally.
         *
         * These two aliases tell Logos what runtime classes the
         * fake Swift-friendly class names actually refer to.
         */

        %init(
            IGSundialViewerVideoSectionController =
                videoSectionController,

            IGSundialATNChainObserver =
                atnObserver
        );


        NSLog(@"[ScrollParty Detection] Hooks initialized");
        NSLog(@"[ScrollParty Detection] ========================================");
    }
}