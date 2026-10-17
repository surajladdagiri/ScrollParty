# Instagram Reels: Class & Method Mappings

Class and method mappings for observing and controlling the Instagram iOS Reels viewer: play/pause, playback speed, next/previous reel, opening/closing comments, and reading the reel list.

> **Tested on:** Instagram iOS **451.0.0** **Status:** Mappings are inferred from class dumps and **not yet verified**. Stage 1 of the [Roadmap](https://claude.ai/chat/0d650900-8293-4f22-b422-a75991e3aefb#roadmap) is testing which hooks work best. Selector names change between app versions. Re-check after updates.

* * *

## Background

- **Sundial** is Instagram's internal codename for Reels.
- The Reels viewer is built on IGListKit. A feed view controller owns a collection view, a data source supplies the list of items, and **each reel is its own section controller**.
- Neighbouring reels are prefetched, so several section controllers exist at once. Reach the on-screen reel through the feed VC's `currentSectionController`.

* * *

## Key classes

Abbrev.

Role

Runtime class name

**FVC**

Reels feed view controller

`IGSundialFeedViewController`

**SC**

Per-reel video section controller

`IGSundialVideoSC.IGSundialViewerVideoSectionController`

**ASM**

Active-section tracker

`IGSundialFeedViewController.IGSundialFeedViewControllerActiveSectionManager`

**DS**

Reels feed data source

`IGSundialFeed.IGSundialFeedDataSource` *(older)* or `IGSundialFeedDataSource.IGSundialFeedDataSource` *(newer)*

Main feed data source

`IGMainFeedListAdapterDataSource`

Organic reel model

`IGMedia`

Ad model

`IGAdItem`

Dotted names are Swift classes registered with the Objective-C runtime under `Module.ClassName`. The data source's module name has changed between versions, so check both.

**Object graph:**

```
IGSundialFeedViewController (FVC)
  ├─ currentSectionController          → SC (check class; ads/carousels/midcards use others)
  │    ├─ _videoCell                   → video cell
  │    ├─ commentThreadViewController  → comments VC (when open)
  │    ├─ fastReelsManager             → playback speed owner (not yet dumped)
  │    └─ currentPlayerForExternalOwnership → underlying player (not yet dumped)
  ├─ activeSectionManager              → ASM
  └─ dataSource                        → DS
       └─ objectsForListAdapter:       → NSArray of IGMedia / IGAdItem / other models, in feed order
```

**Type encodings used below:** `q` long long · `Q` unsigned long long · `B` BOOL · `d` double · `@` object

* * *

## Method mappings

Each table lists **Control** hooks (call to make something happen), **Detect** hooks (fire when it happens), and **Query**methods (read current state).

### Play / pause

Type

Class

Selector

Notes

Control

SC

`_forcePausePlaybackWithReason:` [q]

Reason enum unknown; start with `0`

Control

SC

`setExternalPlaybackPaused:reason:` [B, @]

Built for PiP/external ownership

Control

SC

`removePlaybackOverrides`

Should release forced pauses (resume)

Control

SC

`seekToTime:` [d]

Seconds

Control

FVC

`stopCurrentVideo:` [q]

Stop, not toggle

Query

SC

`isPausedByViewer`

Detect

SC

`tapToPauseOwnerDidActivate:`

Paused by tap. May be tied to the shopping/visual-discovery layer

Detect

SC

`tapToPauseOwnerDidDeactivate:`

Resumed

Detect

SC

`sundialViewerVideoCell:didUpdatePlaybackState:` [`{q,d,d}`]

Struct field meanings unverified (state, time, duration?)

Detect

SC

`sundialViewerVideoCellDidStartPlaying:`

Detect

SC

`sundialViewerVideoCellPlaybackWillStop:`

Detect

SC

`sundialViewerVideoCellDidSingleTap:gestureRecognizer:`

Raw tap on video

Detect

FVC

`videoStartedPlaying:`, `videoStopped:`

Feed-level

Detect

FVC

`sundialViewerVideoSectionController:didUpdatePlaybackState:`[`{q,d,d}`]

Feed-level mirror of SC state

SC has no plain `play`/`pause`. Direct control likely lives on the player from `currentPlayerForExternalOwnership` or `_videoCell`, which hasn't been dumped yet. Avoid `beginExternalPlayerOwnership` / `endExternalPlayerOwnershipReclaiming:`. They hand the player off for PiP and can break playback.

### Playback speed (2x)

Type

Class

Selector

Notes

Control

SC

`resetPlaybackSpeedWithCell:` [@]

Back to 1x; pass `_videoCell`

Control

?

*Not found yet*

Check `fastReelsManager`'s class for a set-speed method

Query

SC

`isLongPressGestureForFastReels:cell:` [@, @]

Whether a long press is the speed gesture

Detect

SC

`fastForwardController:didChangeSpeedFrom:to:isUserInitiated:`[@, d, d, B]

**Primary candidate**

Detect

SC

`fastForwardController:didReselectSpeed:` [@, d]

Detect

SC

`controlsOverlayControllerDidStartUFILongPress2xSpeed:`

Hold-for-2x began

Detect

SC

`controlsOverlayControllerDidStopUFILongPress2xSpeed:`

Hold-for-2x ended

Detect

SC

`handleFastReelsLockedActionWithShowToast:` [B]

Speed locked

Detect

SC

`handleFastReelsUnlockedActionWithTouchPoint:showToast:`

Speed unlocked

Detect

SC

`handleFastReelsExplicitlyUnlockedAction`

Detect

SC

`sundialViewerVideoCellDidLongPressBegin:` / `…Change:` / `…End:`

Raw long press

### Next / previous reel

Type

Class

Selector

Notes

Control

FVC

`ig_arrowDown`

Next, no args

Control

FVC

`ig_arrowUp`

Previous, no args

Control

FVC

`scrollToNextItemAnimated:` [B]

Next

Control

FVC

`advanceToNextItemWithNavigationAction:` [q]

Next; action enum unknown

Control

FVC

`rewindToPreviousItemWithNavigationAction:` [q]

Previous

Control

FVC

`advanceToItemIndex:withNavigationAction:` [Q, q]

Jump to index

Control

FVC

`scrollToMediaID:` [@]

**Jump to a specific reel; key for sync**

Control

SC

`advanceToNextReel`

Next, section level

Query

FVC

`activeSection`, `currentViewerIndex`

Query

SC

`mediaIndex`

Detect

ASM

`notifyActiveSectionListenersWithPrevActiveSection:newActiveSection:`[q, q]

**Primary candidate.**`new > prev` → next, `new < prev` → previous. Ignore the initial load

Detect

FVC

`setActiveSection:` [q]

Detect

FVC

`updateNavigationAlphaForScrollDirection:index:object:` [Q, q, @]

Carries a direction value

Detect

FVC

`scrollViewWillBeginDragging:`

User-initiated swipe began

Detect

FVC

`advanceToNextReelForAutoScroll`

Auto-scroll, not the user

Detect

SC

`didBecomeActive` / `didBecomeInactive`

Per reel

Detect

SC

`sectionWillAppear` / `sectionWillDisappear`, `handleScrollAway`

`sundialViewerVideoCellDidSwipeBegin/Change/End` appear to be the **horizontal** swipe-to-profile gesture, not vertical paging.

### Comments

Type

Class

Selector

Notes

Control

SC

`presentCommentsViewControllerWithPreviewCommentID:sortOrder:truncateCaption:shouldDisplayKeyboard:shouldDisplayNudgeBanner:commentThreadEntryPoint:`

Open. Try `nil, nil, NO, NO, NO, <0…n>`

Control

SC → VC

`commentThreadViewController` → `dismissViewControllerAnimated:completion:`

Close

Query

SC

`commentThreadViewController`

Non-nil while open (verify)

Detect

SC

`presentCommentsViewControllerWithPreviewCommentID:…`

**Primary candidate for open**; likely the common funnel

Detect

SC

`handleCommentButtonTapWith:previewCommentID:sortOrder:…`

Comment button path

Detect

SC

`sundialViewerVideoCell:didTapCommentForSundialVideoPk:withKeyboard:commentThreadEntryPoint:`

Comment button tap

Detect

SC

`sundialViewerVideoCell:didTapCommentPreviewForSundialVideoPk:commentId:`

Comment preview tap

Detect

SC

`sundialViewerVideoCell:didTapCommentPromptWithParentCommentId:commentThreadEntryPoint:`

Comment prompt tap

Detect

FVC

`sundialViewerBottomBarDidTapComment:`, `handleAddCommentMessageBarTap`

Bottom bar

Detect

FVC

`sundialViewerInteractionCoordinator:shouldPresentCommentPanelWithConfiguration:`

Feed-level funnel

Detect

SC

`commentThreadViewControllerDidDismiss:`

**Primary candidate for close**

Detect

SC / FVC

`partialModalSheet:willChangeState:` / `didChangeState:` / `partialModalSheetDidDismiss:`

Shared with other sheets; check the content VC class

Detect

SC / FVC

`partialModalSheet:didUpdateOffset:presentationProgress:`

Drag progress

### Reel list & identity

Type

Class

Selector

Notes

Query

DS

`objectsForListAdapter:` [@]

**Full feed in order:** `IGMedia`, `IGAdItem`, and other models

Query

FVC

`currentPlaybackMedia`

Media on screen

Query

FVC

`playbackMediaForPageIndex:` [q]

Media at an index

Query

FVC

`queuedMedias`, `sourceMediaPk`

Query

SC

`video`, `parentMPk`

Control

FVC

`scrollToMediaID:` [@]

Jump to a reel by ID

Control

FVC

`setQueuedMedias:` [@]

Possibly inject specific reels

Control

FVC

`setPendingScrollToMediaPkAfterRefresh:` [@]

Scroll target after a refresh

Detect

FVC

`sundialFeedNetworkSource:didInsertQueuedMedias:isFirstChunk:`

New reels added

Detect

FVC

`sundialFeedNetworkSourceDidUpdateObjects:`

Feed list changed

### Ad-related (affects indexes)

Ads take up positions in the feed list. If ads are filtered out on one device but not another, **section indexes won't match between devices**.

Class

Selector

Notes

DS

`objectsForListAdapter:`

Ads appear here as `IGAdItem`

FVC

`displayInstreamAdWithAdItem:showPopoverAnimation:completion:`, `preLoadInstreamAdWithAdItem:`

Ads played *inside* an organic reel, not in the list

FVC

`feedInjectionHandler:didInsertItems:`

Items injected into the feed

FVC

`sundialFeedNetworkSource:didReplaceAdsAtIndices:`

Index-based ad replacement

FVC

`adIdsInPool`, `nextAdItem`, `currentAdCell`

FVC

`mountDelaySkipFooterIfEligible`, `hideDelaySkipFooter`

Short Drama delay-skip ads

* * *

## Roadmap

### 1. Test detection and control hooks ⬜

- [ ] For each action (next, previous, pause, resume, 2x on/off, comments open/close), confirm which **Detect** hooks fire, and pick the most reliable one.
  - [ ] Check that each fires exactly once per action.
  - [ ] Check that each fires for every route: gestures, buttons, and programmatic calls.
  - [ ] Check that none fires for unrelated actions.
- [ ] For each action, confirm which **Control** method works cleanly with no visual glitches or broken state.
- [ ] Decode the `{q,d,d}` playback-state struct.
- [ ] Find valid values for the `reason`, `navigationAction`, and `commentThreadEntryPoint` enums.
- [ ] Dump the player class and the `fastReelsManager` class to find direct play/pause/set-speed methods.
- [ ] Find a way to tell user actions apart from programmatic ones, so replayed actions aren't re-detected.
- [ ] Mark each row above as ✅ verified or ❌ wrong.

### 2. Local control server ⬜

- [ ] Define the command set: `next`, `prev`, `pause`, `resume`, `speed <x>`, `comments open|close`, `goto <mediaId>`, `seek <seconds>`.
- [ ] Define the event set: `NEXT`, `PREV`, `PAUSE`, `RESUME`, `SPEED <x>`, `COMMENTS_OPEN`, `COMMENTS_CLOSE`, `REEL <mediaId>`.
- [ ] Map each command to its verified Control method and each event to its verified Detect hook.
- [ ] Ensure all UI calls run on the main thread.

### 3. Tandem scrolling (the other end) ⬜

- [ ] Build the peer that receives events from one device and replays them as commands on another.
- [ ] Sync by **reel ID**, not by relative moves. Each device's feed is personalized and ads shift positions, so next/previous replay will drift.
- [ ] Prevent loops, so an event replayed on device B isn't echoed back to device A.
- [ ] Handle latency and ordering: sequence numbers and a leader/follower role.
- [ ] Sync playback position after each jump.

### 4. Encoding / decoding reel objects ⬜

- [ ] Read the feed from DS `objectsForListAdapter:` and inspect `IGMedia` to find the field that identifies a reel portably (pk, media ID, or shortcode).
- [ ] Define a wire format, e.g. `{ "mediaId": …, "pk": …, "position": <seconds>, "speed": <x>, "paused": <bool> }`.
- [ ] Decode on the receiving side: jump with `scrollToMediaID:` when the reel is already in the feed.
- [ ] Handle reels missing from the receiver's feed: test `setQueuedMedias:` and `setPendingScrollToMediaPkAfterRefresh:`.

* * *

## Notes

- Everything here is from **451.0.0**. Swift module and class names change between versions; the data source has already moved modules once.
- Swift-only methods don't appear in Objective-C class dumps.
- Section controllers for neighbouring reels exist at the same time. Per-reel callbacks fire on the active one, but don't assume any given section controller instance is on screen.