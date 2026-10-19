# ScrollParty

ScrollParty is an experimental iOS tweak for synchronizing Instagram Reels between two devices.

The project is currently focused on reverse-engineering Instagram's Reels implementation: detecting user actions, identifying the internal feed model, and determining whether a feed can be reconstructed on another device.

## Current status

Working:

- Detect next / previous Reel
- Detect play / pause
- Detect playback speed changes
- Detect comments open / close
- Detect Reels refresh
- Read the Reels feed from `objectsForListAdapter:`
- Inspect `IGMedia` identifiers
- Trace parts of `IGMediaMap` media construction

In progress:

- Reconstruct `IGMedia` from a media PK or serialized dictionary
- Replace the Reels feed with a fixed custom array
- Find internal methods for performing next / previous / play / pause / comments actions
- Synchronize carousel position
- Test cross-device feed reconstruction

Not started:

- WebSocket client
- Room server
- Room codes
- Cross-device state synchronization
- Reconnect / resync logic

---

## Goal

The final goal is a two-person Reels watch party.

A user creates a room, another user joins it from a modified Instagram client, and both devices stay synchronized while either person can:

- scroll to the next or previous Reel
- play or pause
- use 2x playback
- open or close comments
- move through carousel posts

The main problem is that two Instagram accounts normally have different personalized Reels feeds. ScrollParty therefore needs to synchronize both the current feed/media and the current UI/playback state.

---

## Reels feed

The Reels data source is:

```objc
IGSundialFeedDataSource.IGSundialFeedDataSource
```

The useful method is:

```objc
- (id)objectsForListAdapter:(id)adapter;
```

The returned objects have been confirmed to be `IGMedia` instances.

Current hook:

```objc
%group swiftHooks

%hook dataSource

- (id)objectsForListAdapter:(id)arg1
{
    NSArray *originalFeed = %orig;
    NSMutableArray *filteredFeed = [NSMutableArray array];

    for (id item in originalFeed) {
        if ([item isKindOfClass:%c(IGAdItem)]) {
            continue;
        }

        [filteredFeed addObject:item];
    }

    feed = [filteredFeed copy];

    return filteredFeed;
}

%end

%end
```

This proves the tweak can already read and modify the array used by the Reels list adapter.

The next test is to replace this array entirely with a fixed set of known `IGMedia` objects.

---

## Reel navigation detection

The first implementation tried to detect navigation from video playback callbacks. That worked for video-to-video transitions but failed when scrolling to photo Reels.

The reliable method is:

```objc
IGSundialUnconnectedFeedNetworkSource
- (void)activeSectionDidChangeFrom:(NSInteger)oldSection
                               to:(NSInteger)newSection;
```

Observed behavior:

```text
scroll down -> newSection = oldSection + 1
scroll up   -> newSection = oldSection - 1
```

This works across video, photo, and carousel content.

Current hook:

```objc
%hook IGSundialUnconnectedFeedNetworkSource

- (void)activeSectionDidChangeFrom:(NSInteger)oldSection
                               to:(NSInteger)newSection
{
    %orig;

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
```

---

## Playback

Relevant class:

```objc
IGSundialViewerVideoCell
```

Useful methods:

```objc
- playWithReason:
- pauseWithReason:
- stopWithReason:
- prepareForPlayback
- setPlaybackSpeed:
- isPlaying
- currentPlaybackTime
- sundialVideoPlaybackViewDidStartPlaying:
- videoViewDidPause:
- videoViewDidStop:
```

Observed normal play:

```text
playWithReason: 1
```

Observed manual tap-to-pause:

```text
pauseWithReason: 7
```

`pauseWithReason:3` is not specific to scrolling. It also appears during comments and some UI interruptions.

`-sundialVideoPlaybackViewDidStartPlaying:` can fire during normal playback, loops, and restarts, so it needs state-based deduplication.

---

## Playback speed

Playback speed is exposed through:

```objc
- setPlaybackSpeed:(float)speed;
```

Observed:

```text
long press start -> 2.0
release          -> 1.0
```

This is currently the best signal for 2x playback state.

---

## Comments

Comments are represented by:

```objc
IGCommentThreadViewController
```

Reliable detection:

```objc
- viewDidAppear:
- viewDidDisappear:
```

Current behavior:

```text
viewDidAppear    -> comments opened
viewDidDisappear -> comments closed
```

The class also has:

```objc
- _didTapDismiss
```

which may be useful later for remote comment closing.

---

## Refresh detection

The current refresh signal comes from:

```objc
IGSundialUnconnectedFeedNetworkSource
- sundialFeedNetworkSource:
    willStartNewFeedSessionWithId:
    previousSessionId:
    prefetchType:
```

Observed values:

```text
manual refresh -> prefetchType = 0
app startup    -> prefetchType = 3
```

For now, `prefetchType == 0` is treated as a Reels refresh.

---

## Photo and carousel Reels

Instagram uses:

```objc
IGSundialViewerPhotoCell
```

for photo content in the Reels viewer.

The class exposes many of the same playback-style methods as the video cell:

```objc
- playWithReason:
- pauseWithReason:
- stopWithReason:
- prepareForPlayback
- setPlaybackSpeed:
```

There are also viewer callbacks for non-video sections and carousel changes:

```objc
sundialViewerViewControllerDidShowNonPlaybackSection:
sundialViewerViewController:didUpdateCarouselPostItemTo:
```

Vertical Reel navigation is already handled by `activeSectionDidChangeFrom:to:`.

Horizontal carousel position still needs separate synchronization logic.

---

## IGMedia identifiers

`IGMedia` exposes:

```objc
- saveId
- loggingMediaPk
- giftableContentId
```

`IGSundialViewerVideoCell` exposes:

```objc
- mediaPk
```

Observed example:

```text
saveId / cell mediaPk:
4010786467422345960_5816106424
```

The first component is the media PK:

```text
4010786467422345960
```

The second component is the owner/account ID:

```text
5816106424
```

`loggingMediaPk` and `giftableContentId` were observed to use the numeric media PK portion.

---

## IGMediaMap

The current focus is figuring out how Instagram constructs `IGMedia`.

Relevant class:

```objc
IGMediaMap
```

Interesting methods:

```objc
- getIGMediaWithFragment:error:
- mediaWithDict:
- constructInstanceWithPK:initialTree:
- objectWithPk:initialTree:
- updateInstance:withDictionary:
- objectWithDict:
- edgeObjectWithDict:
- objectFromConvertingFragmentTree:error:
- consolidateDeserializedObject:
- allObjects
- mediaMap
```

### Dynamic trace results

The following methods have been hooked:

```text
mediaWithDict:
objectWithDict:
objectWithPk:initialTree:
constructInstanceWithPK:initialTree:
getIGMediaWithFragment:error:
consolidateDeserializedObject:
```

During app startup, `consolidateDeserializedObject:` fires frequently with existing `IGMedia` objects. This appears to be related to restoring or canonicalizing cached media.

When opening Reels, Instagram first performs several calls like:

```text
objectWithPk:initialTree:
    initialTree = nil
    result = IGMedia
```

Fresh feed activity then includes calls like:

```text
constructInstanceWithPK:
    initialTree = nil
    result = IGMedia

mediaWithDict:
    NSDictionary / NSMutableDictionary
    result = IGMedia
```

During refresh, `mediaWithDict:` sometimes calls `constructInstanceWithPK:initialTree:` before returning an `IGMedia`.

Other `mediaWithDict:` calls return without a visible construction call, which suggests an existing object may already be present in the map.

`getIGMediaWithFragment:error:` did not fire in the captured startup trace.

### Current hypothesis

Current working model:

```text
mediaWithDict:
    |
    +-- extract media PK
    |
    +-- look up existing object in IGMediaMap
    |
    +-- if missing:
    |      constructInstanceWithPK:initialTree:nil
    |
    +-- populate/update object from dictionary
    |
    +-- return IGMedia
```

The next method to trace is:

```objc
- updateInstance:withDictionary:
```

The important test is whether the same object pointer flows through:

```text
constructInstanceWithPK:
        ↓
updateInstance:withDictionary:
        ↓
mediaWithDict: return value
```

---

## Feed reconstruction plan

The current plan is to avoid serializing live `IGMedia` objects directly.

Preferred flow:

```text
Device A

IGMedia / feed response
        ↓
portable media representation
        ↓
server
        ↓

Device B

portable media representation
        ↓
IGMediaMap
        ↓
local IGMedia objects
        ↓
objectsForListAdapter:
```

Best case, only media IDs are needed.

If PK alone is not enough, the fallback is to send the dictionary used by:

```objc
mediaWithDict:
```

If that dictionary survives JSON serialization and can reconstruct a full `IGMedia` on another device, it is probably the right network representation.

---

## IGMedia reconstruction tests

### Cached media

Try to resolve a PK for a Reel already viewed in the current session.

Success only proves that `IGMediaMap` can return cached objects.

### Cold launch

1. Save a PK.
2. Kill Instagram.
3. Relaunch.
4. Do not open that Reel.
5. Try to resolve the PK.

### Never-seen media

Use a PK collected from another device that the receiving phone has never loaded.

This is the most important PK-only test.

### Dictionary round trip

Capture an actual dictionary passed into:

```objc
mediaWithDict:
```

Then test:

```text
NSDictionary
    ↓
JSON
    ↓
deserialize
    ↓
NSDictionary
    ↓
mediaWithDict:
    ↓
IGMedia
```

### Fixed feed

Build a five-item feed containing a mix of video, photo, and carousel posts.

Force `objectsForListAdapter:` to always return it.

Verify:

- correct order
- forward / backward scrolling
- video playback
- image rendering
- carousel rendering
- comments
- repeated scrolling
- no crashes

### Second device

Transfer the same media payload from Device A to Device B manually.

No server yet.

Device B should reconstruct the media and show the same feed order.

---

## Static analysis targets

Static decompilation is useful now, but only for methods already confirmed to be relevant.

Priority:

```objc
IGMediaMap - mediaWithDict:
IGMediaMap - updateInstance:withDictionary:
IGMediaMap - constructInstanceWithPK:initialTree:
IGMediaMap - objectWithPk:initialTree:
```

Questions to answer:

- How does `mediaWithDict:` extract the PK?
- Does it check the map first?
- What does `constructInstanceWithPK:` initialize?
- What is `initialTree` used for?
- Does `mediaWithDict:` call `updateInstance:withDictionary:`?
- Which dictionary keys are required?
- How are nested users / carousel items handled?
- Does a JSON-deserialized dictionary work?
- Does any of this trigger a network request?

There is also:

```objc
IGMedia + valueWithJSONDictionary:objectMaps:error:
```

which may be worth comparing with `IGMediaMap - mediaWithDict:` later.

---

## Command-side work

The observer side is mostly mapped. The next major area is finding the methods that actually perform actions.

Desired helpers:

```text
SPNext()
SPPrevious()
SPPlay()
SPPause()
SPSetPlaybackSpeed()
SPOpenComments()
SPCloseComments()
SPSetCarouselIndex()
SPRefresh()
SPNavigateToMedia()
```

Likely easy:

```objc
IGSundialViewerVideoCell
- playWithReason:
- pauseWithReason:
- setPlaybackSpeed:
```

Still unknown:

- next Reel
- previous Reel
- open comments
- carousel movement
- direct navigation to a media PK

`activeSectionDidChangeFrom:to:` should not be called to navigate. It reports a navigation change; it does not cause one.

---

## Synchronization architecture

The first network version should use a WebSocket relay server.

Each client:

```text
observe local state
        ↓
send normalized event
        ↓
server assigns revision
        ↓
other client receives event
        ↓
perform matching local action
```

Media files themselves should not pass through the ScrollParty server. Each client should still load video and images from Instagram.

A future room state could look like:

```json
{
  "revision": 42,
  "feedIndex": 12,
  "mediaPk": "4010786467422345960",
  "saveId": "4010786467422345960_5816106424",
  "carouselIndex": 0,
  "playing": true,
  "speed": 1.0,
  "commentsOpen": false
}
```

Relative commands such as `NEXT` are not enough on their own because a missed event would leave the clients out of sync.

The server should keep an authoritative state snapshot so a reconnecting client can resync immediately.

---

## Event echo prevention

Remote actions will trigger the same hooks as local actions.

Example:

```text
A pauses
  ↓
server sends PAUSE to B
  ↓
B calls pauseWithReason:
  ↓
B's pause hook fires
  ↓
B sends PAUSE back
```

The first implementation can use a local flag such as:

```text
applyingRemoteAction
```

A better implementation should use:

```text
event ID
source client ID
server revision
```

---

## Media availability

The second account may not be able to view every Reel from the first account.

Possible reasons include:

- private account
- blocked account
- deleted Reel
- region restriction
- age restriction
- other account-specific access restrictions

The protocol will eventually need a way to report:

```text
MEDIA_UNAVAILABLE
```

and skip or resynchronize cleanly.

---

## Debugging notes

### Unified logging redaction

`NSLog` currently shows values such as:

```text
<private>
```

for PKs, save IDs, and dictionary keys.

Use `fprintf(stderr, ...)` or a local debug file for reverse-engineering traces where literal values are needed.

### Duplicate Console logs

At one point macOS Console displayed every tweak log twice even though the process and addresses were identical.

Restarting Console fixed it.

This was not duplicate tweak injection.

---

## Roadmap

### Feed / model research

- [x] Read `objectsForListAdapter:`
- [x] Confirm feed objects are `IGMedia`
- [x] Modify the returned feed
- [x] Identify `IGMediaMap`
- [x] Trace `mediaWithDict:`
- [x] Trace `constructInstanceWithPK:initialTree:`
- [x] Trace `objectWithPk:initialTree:`
- [x] Trace `objectWithDict:`
- [x] Trace `consolidateDeserializedObject:`
- [ ] Trace `updateInstance:withDictionary:`
- [ ] Log non-redacted PK / saveId values
- [ ] Correlate object pointers through construction
- [ ] Decompile `mediaWithDict:`
- [ ] Decompile `updateInstance:withDictionary:`
- [ ] Determine minimum reconstruction payload
- [ ] Reconstruct media after cold launch
- [ ] Reconstruct media on another device
- [ ] Replace feed with a fixed custom array

### Detection

- [x] Next Reel
- [x] Previous Reel
- [x] Play
- [x] Pause
- [x] Playback speed
- [x] Comments open
- [x] Comments close
- [x] Refresh
- [ ] Carousel index
- [ ] Better explicit-play vs loop/restart distinction
- [ ] Better pause classification

### Control

- [ ] Play
- [ ] Pause
- [ ] 1x / 2x
- [ ] Next Reel
- [ ] Previous Reel
- [ ] Open comments
- [ ] Close comments
- [ ] Carousel navigation
- [ ] Refresh
- [ ] Navigate directly to media PK

### Networking

- [ ] WebSocket client
- [ ] Relay server
- [ ] Room creation
- [ ] Room codes
- [ ] Presence
- [ ] Event relay
- [ ] Server revisions
- [ ] State snapshots
- [ ] Reconnect / resync
- [ ] Feed payload transfer
- [ ] Media-unavailable handling

### Final synchronization

- [ ] Same feed
- [ ] Same Reel
- [ ] Same carousel item
- [ ] Same play / pause state
- [ ] Same playback speed
- [ ] Same comments state
- [ ] Conflict handling
- [ ] Drift detection
- [ ] Automatic recovery

---

## Next step

Immediate work:

```text
1. Hook updateInstance:withDictionary:
2. Log non-redacted PK / saveId values
3. Log object pointers
4. Confirm the IGMediaMap construction path
5. Decompile mediaWithDict: and updateInstance:withDictionary:
6. Attempt a controlled IGMedia reconstruction
```

Networking should wait until feed reconstruction works locally.

## Notes

Instagram class names and selectors used here are private implementation details and may change between app versions.

All behavior in this README is based on runtime testing against the currently tested Instagram build.
