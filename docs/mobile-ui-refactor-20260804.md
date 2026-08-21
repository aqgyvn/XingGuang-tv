# Android Mobile UI Structure Refactor

## Scope

This change implements the mobile-only structure from the August 4, 2026 "Plan APP UI structure refactor" draft. It does not restore the removed Android TV Leanback surface.

The refactor keeps the current Android behavior and ViewBinding contracts:

- VOD, live playback, search, favorites, history, source configuration, playback settings, backup, and restore keep their existing handlers.
- VOD and live playback continue to use their existing activities, player controls, gesture handling, and intent fields.
- The existing live tab still opens the live player directly. Its group, channel, and programme drawer remains available within that player.

## Implemented Structure

- The mobile theme now uses the draft's dark cinema hierarchy: a dark base, layered surfaces, blue selection state, high-contrast primary text, and subdued supporting text.
- The main navigation now shows labeled VOD, live, and profile destinations. The existing settings destination is presented as the profile surface so its original fragment and back behavior remain intact.
- The profile surface groups favorites and viewing history with content sources, playback settings, preferences, and data management. Existing source, history, cache, backup, restore, and player-setting actions keep their original bindings.
- The VOD and live controls retain every existing action but now use a distinct top bar, centered transport controls, progress layer, and horizontal cinematic function strip. The live channel drawer uses an opaque framed surface for readability over video.

## Homepage Correction

- The VOD homepage now uses a compact top toolbar, underline category tabs, horizontal trending poster rail, one-line continue-watching entry, then the existing category content pager.
- The top toolbar keeps the existing source, search, favorites, and history routes. Category paging, filters, floating actions, and the compact continue-watching entry retain their existing handlers.
- The trending rail is fed from the current home result. Its item click and long-click routes use the same action, folder, indexed-source search, and video playback behavior as the existing category content.
- The default VOD grid no longer uses the former paper-card container, so content below the home flow remains poster-led rather than reading as a second stack of cards.
- The duplicate full-width continue-playing hero was removed on August 10, 2026. The category bar and all content below it move upward, while the compact continue-watching row remains the single playback-resume entry.
- The homepage artwork now extends behind the transparent status bar. Status icons use the light appearance with a short fading contrast scrim, while the toolbar controls retain a status-bar-safe top inset so system and application controls do not overlap.
- The compact homepage spacing keeps a dynamic portrait card and its title above the fixed bottom navigation. Homepage floating actions remain hidden until the AppBar has fully collapsed.
- The category tabs now sit immediately above the category pager they control. Site recommendations and continue-watching remain earlier homepage sections, so switching a category no longer changes content across an unrelated fixed middle block.
- Continue-watching now appears before site recommendations, and the recommendation rail uses compact `96dp` by `144dp` posters with tighter spacing so it does not dominate the first viewport.
- The site recommendation rail owns the homepage list returned by the active source. The synthetic recommendation tab was removed, so the category row now contains only real source categories and no longer repeats the same homepage movies.
- Continue-watching now binds the latest history record: its poster, title, and episode remark are populated from the saved playback entry, and the section hides when no history exists.
- The labeled bottom navigation uses an `80dp` height so its icon and Chinese label have a complete text viewport. The existing content container continues to reserve this space through `layout_above`.

## Fullscreen Readability Correction

- VOD and live fullscreen headers and function strips now sit on stable dark overlay surfaces, so titles, timing, and controls remain readable over bright video frames.
- Player-engine, track, parse, and live-drawer selections use a dark active fill, blue outline, and white text instead of relying on a text-color change alone.
- Player-engine, track, and parse choices now recognize the state used by their existing adapters and use the same visible selected treatment.
- The live group, channel, and programme drawer uses an opaque dark item surface with white text and a blue selected outline.
- The track-selection dialog title now follows the dialog surface color, keeping its contrast when the dialog surface changes.
- No playback, source, channel, track, parser, or gesture code was changed.

## Dialog Contrast Correction

- Material 3 dialog containers now use the existing dark panel surface instead of the light-mode default container color.
- Source names, search icons, refresh icons, standard dialog text, and the existing blue selected state remain readable on the same dark surface without changing their handlers.

## Episode Selection Surface Correction

- Episode items in the side-sheet list and paged episode grid now use a dedicated translucent charcoal surface instead of the shared solid blue accent button, and both episode containers use the dark panel surface rather than the Material default light container.
- The current episode keeps a restrained blue-grey fill and low-opacity blue outline, while unselected episodes use a neutral translucent fill and soft light border.
- Episode labels remain white in every state, so the active outline provides the selection cue without a second bright-blue text treatment.
- Other accent buttons, player-engine choices, track choices, parse choices, and live-channel controls keep their existing styles and behavior.

## Fullscreen Player Engine Sheet Inset Correction

- The player-engine bottom sheet now keeps the fullscreen player's immersive system-bar state while it is visible.
- The sheet no longer waits for a later navigation-bar inset before settling, so its top edge remains stable from the first frame and the black gesture-navigation strip no longer appears below it.
- The same player-engine sheet opened from the settings screen keeps the normal system-bar behavior.

## Light Sheet Option Surface Correction

- Player-engine options and audio/video/subtitle track options now use a dedicated light translucent selector for the light bottom-sheet surface.
- Unselected items use a restrained gray-blue glass fill, while selected items use a lighter blue-gray fill and a thin blue outline; labels use dark text for contrast on the light sheet.
- Fullscreen dark-surface controls and parser choices keep their existing dark selector.

## Fullscreen Action Strip Layout Correction

- VOD and live fullscreen action strips now fill the available width and divide their existing actions into left and right groups with a flexible center gap.
- Fullscreen action-strip labels use transparent surfaces without a persistent selected-state frame; the underlying toggle values and handlers remain unchanged.
- The action labels use a compact `12sp` size, a stable `40dp` touch height, and `10dp` spacing so the complete action set fits on a 1920 x 1080 fullscreen surface without clipping.
- Existing action order, view IDs, click listeners, long-click listeners, gestures, playback behavior, and settings behavior remain unchanged.

## Fullscreen Action State Display Correction

- Removed the persistent blue fill and outline from the fullscreen function strip so actions such as `跨类` and `换源` read as ordinary text instead of abrupt status cards.
- Kept the state values and click behavior for `跨类` and `换源`; only their background drawable no longer changes for an activated state.
- Player-engine, track, parse, and live channel selection surfaces retain their separate selected treatments where a choice needs to remain visible.

## VOD Transport Button Correction

- The VOD back, previous, play/pause, and next controls use transparent borderless touch feedback instead of persistent blue circular containers.
- The visible icons use compact internal padding and `78%` opacity while retaining their existing touch bounds; the play control spacing is slightly tighter.
- Click handlers, playback state changes, and the separate buffering indicator remain unchanged.

## VOD Action Strip Overlay Correction

- The VOD action strip no longer draws a second near-opaque background over the bottom controller.
- It inherits the existing soft bottom-controller overlay, keeping action labels readable without appearing as a separate black bar.
- Action order, state values, click handlers, scrolling, and the live-player layout remain unchanged.
- The action strip uses compact `2dp` vertical padding and a `4dp` controller bottom inset, moving its upper edge downward while retaining the existing `40dp` action touch height.
- The complete VOD bottom controller is further compacted to approximately `60dp`: the seek row is constrained to `24dp`, its fullscreen control uses `28dp`, VOD-only actions use a `32dp` height, and redundant vertical controller insets are removed. Live controls retain the shared `40dp` action style.
- The VOD top and bottom controller containers are transparent, so controls float directly over the video without full-width translucent black bands. Live controls remain unchanged.

## Verification

- git diff --check -- app/src/mobile completed without whitespace errors.
- .\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --no-parallel --max-workers=1 --stacktrace completed successfully on August 4, 2026.
- The same Android build completed successfully again after the homepage correction on August 4, 2026.
- Runtime verification passed on the 1080 x 1920 MuMu Android 15 instance after a data-preserving APK replacement on August 14, 2026. The category row stayed at the same bounds while taps on recommendation, enhanced-visual, and doll-movie categories moved the selected underline and replaced only the movie pager content directly below it; trending and continue-watching remained above the category-content pair.
- Runtime verification passed again after placing continue-watching first and compacting trending. Three full trending posters plus part of a fourth fit across the viewport, horizontal scrolling loaded later items, the category row moved upward from `y=1353` to `y=1170`, category switching still replaced the correct pager content, and continue-watching still opened `VideoActivity` and returned to the homepage.
- Runtime verification passed after replacing the duplicate trending label with site recommendations on August 14, 2026. The homepage shows `站点推荐`, the synthetic `推荐` tab is absent, the first category is the real source category `臻彩视觉`, and tapping `玩偶电影` loads its own movie set below the tabs.
- Runtime verification passed after binding continue-watching to history on August 14, 2026. The MuMu homepage rendered poster `俩祖三爹争着宠娃` with title `俩祖三爹争着宠娃` and episode remark `1` in the continue section; the activity remained on `HomeActivity`.
- The Android build completed successfully after the expanded-home first-row clipping correction on August 4, 2026.
- Runtime verification passed on the 1080 x 1920 MuMu instance after a data-preserving APK replacement: the expanded homepage shows the complete first-row portrait cards, their remarks, and their titles above the navigation; a subsequent content scroll preserves normal grid browsing and the existing return-to-top control.
- Runtime verification passed again after the final bottom-navigation correction: the navigation occupies `y=1680` through `y=1920`, while the selected Chinese label receives a `48px` text viewport and renders completely in both expanded and scrolled homepage states.
- The Android build completed successfully after the fullscreen readability correction on August 4, 2026.
- Runtime verification passed after a data-preserving APK replacement on the 1080 x 1920 MuMu instance: VOD fullscreen headers and action labels remain readable over changing video frames; the selected player engine and audio-track choices show a dark active surface, blue outline, and white label; and the track dialog heading is readable on its light sheet.
- The live channel-drawer capture confirms selected group and channel items keep a dark active surface, blue outline, and white text. A later live-stream check reached a connection timeout, so playback availability was not used as evidence for the UI correction.
- The Android build completed successfully after the fullscreen action-strip layout correction on August 6, 2026, and the rebuilt APK was installed on the existing MuMu instance without clearing application data.
- Runtime VOD verification confirms the complete left group (`EXO`, decode, speed, scale, refresh, loop) and right group (subtitle, audio, video, intro, outro, episodes) remain visible with a clear center gap; the activated loop state remains readable.
- Runtime live verification confirms the complete left group (configuration, refresh, player, decode, scale) and right group (audio, video, invert, cross-category, source change) fit within the 1920 x 1080 viewport. The runtime hierarchy reports every visible action as clickable and keeps the action bounds between `x=48` and `x=1842`.
- The live source returned a connection timeout during this verification. This affected stream availability only; the fullscreen control layer and its action hierarchy were still available for layout verification.
- The Android build completed successfully after removing the fullscreen action-strip state frame on August 7, 2026, and the rebuilt APK was installed on MuMu without clearing application data.
- Runtime live verification confirms `跨类` and `换源` remain visible and clickable as plain text with no persistent blue frame.
- Runtime VOD verification on August 14, 2026 confirms the back, previous, play, and next controls render as plain white icons without persistent blue circular fills. The blue buffering arc remains separate and visible at `0 KB/s`, and the back control still returns to `HomeActivity`.
- Runtime VOD verification on August 14, 2026 confirms the same four controls render with smaller visible icons at `78%` opacity while preserving their touch bounds. Playback remained active, and the compact back control returned to `HomeActivity`.
- Runtime fullscreen VOD verification on August 14, 2026 confirms the action strip shares the soft controller overlay instead of drawing a separate near-black band. Video remains visible beneath the complete action row, and tapping `EXO` still opens the player-core selector.
- Runtime fullscreen VOD verification on August 14, 2026 confirms the action row's total bottom allocation is reduced from approximately `64dp` to `48dp`, moving its upper edge downward while retaining `40dp` action targets. The current stream URL failed during this check, but the complete row remained visible and `EXO` still opened the player-core selector.
- Runtime fullscreen VOD verification on August 14, 2026 confirms the complete bottom controller is approximately `60dp` high and starts around `y=900` on the 1920 x 1080 viewport. The active video remains visible behind both compact rows, all labels render completely, the `28dp` fullscreen control enters fullscreen, and the `32dp` `EXO` action still opens the player-core selector.
- Runtime fullscreen VOD verification on August 14, 2026 confirms the full-width top and bottom dark overlays are absent. Video pixels remain continuous behind the title, progress, and action controls; the title and controls stay readable on the tested mixed-brightness frame, and fullscreen, `EXO`, and back interactions remain functional.

- The Android build completed successfully after the dialog contrast correction on August 11, 2026, and APK `5.6.9 (569)` was installed on MuMu without clearing application data.
- Runtime source-dialog verification confirms six source labels, six search controls, and six refresh controls remain present and clickable on the dark `#181B20` container. White text reaches `17.26:1`, light icons reach `15.83:1`, and the blue selected text reaches `4.6:1` contrast.
- Runtime standard-dialog verification confirms the image-size title, all four choices, the selected radio state, and the cancel action remain readable on the same dark container; the profile version row displays `5.6.9`.
- The mobile ARM64 build completed successfully after the episode selection surface correction on August 18, 2026. Runtime screenshot verification remains pending because both MuMu ADB transports reported `offline` after the emulator started.
- ADB-only runtime verification later completed on August 18, 2026 after the MuMu transport returned `device`: the rebuilt APK opened the VOD detail, entered fullscreen through ADB gesture input, opened the right-side episode sheet, and rendered the dark panel with translucent charcoal episode items, white labels, and a restrained blue active outline.
- ADB-only runtime verification completed on August 21, 2026 for the fullscreen player-engine sheet. Its bounds were `[438,907][2342,1264]` immediately after opening and remained identical four seconds later; the sheet reached the bottom of the 2780 x 1264 display without a separate navigation-bar strip. The immediate and delayed UI hierarchy dumps had the same SHA-256 `A94EEEBDC5A2138F897B64DC6B98130F0E5788DA003C5A4322DF28903D0DB6CF`.
- ADB-only runtime verification completed on August 21, 2026 for the light player-engine options in APK `5.7.3 (573)`: EXO rendered with a light blue-gray selected fill and blue outline, while IJK and MPV rendered with light gray translucent fills and dark labels. The track-row layout is bound to the same light selector and passed resource compilation; the active test stream exposed no selectable video track, so a matching runtime track-sheet capture was not available.
- APK `5.7.4 (574)` moves the fullscreen immersive-window handling from the player-engine sheet into the shared player bottom-sheet base. Audio, subtitle, video-track, subtitle-control, and danmaku sheets now keep the same stable bottom edge and height after opening, while non-fullscreen settings sheets retain their normal system-bar behavior.

## Rollback

Before commit, restore the Android mobile files listed in the matching progress.md entry and remove this document. After a dedicated commit, revert that commit with git revert <commit>.
