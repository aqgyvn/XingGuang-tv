# Mobile Glass Navigation

## Scope

The mobile home navigation was restyled as a floating transparent-glass surface. Existing destinations, menu items, view IDs, click listeners, and fragment routes remain unchanged.

## UI changes

- Added 40dp horizontal spacing and a 4dp bottom offset so the navigation reads as a smaller floating surface.
- Reduced the navigation to 56dp high while retaining a stable, unclipped viewport for each icon and Chinese label.
- Added a fully rounded dark semi-transparent capsule, a very subtle outline, and elevation to match the supplied navigation reference.
- Removed the separate selected indicator surface; the selected destination now uses gold icon and label color while inactive destinations use white.
- Reduced the icon to 18dp and the label to 10sp so the internal proportions match the compact container.
- Reduced the VOD hero height to 230dp so the content title remains clear of the floating navigation overlay.

## Compatibility

The glass treatment uses alpha colors, a gradient, an outline, and elevation. It does not require real-time background blur, so it remains compatible with the mobile module's Android 26 minimum SDK and avoids extra rendering cost. The navigation is rendered as an overlay so the page background and content continue behind the capsule. Scrollable screens provide bottom safety padding so the last actionable row can still be brought above the overlay.

## Verification

- Built `:app:assembleMobileArm64_v8aDebug` successfully.
- Installed the resulting `5.6.5 (565)` APK on MuMu device `127.0.0.1:16384` with `adb install -r`.
- Confirmed the home screen launches and the runtime navigation bounds are `[120,1740][960,1908]` on the 1080 x 1920 device.
- Confirmed the selected VOD label is fully visible within `[229,1833][291,1881]`.
- Confirmed the runtime hierarchy contains no active-indicator view, matching the reference's color-only selected state.
- Clicked `我的` and then `点播`; the setting destination selected state changed to true and returned to the VOD destination without changing navigation behavior.
- Visually inspected the final home and settings captures for transparency, label contrast, and absence of content overlap.

## Overlay correction (2026-08-08)

The earlier `layout_above` constraint on the home fragment container ended the page at the top of the capsule. Because the capsule has horizontal margins, the remaining full-width strip showed the window's dark background and looked like a black base behind the navigation. The constraint was removed so the fragment fills the home surface and the navigation draws above it.

The settings and player-settings scroll content now has 80dp bottom padding. The VOD floating actions use explicit 16dp side/top margins and a 76dp bottom margin, keeping them 16dp above the capsule after the container expands to the full height.

## Overlay verification

- Rebuilt `:app:assembleMobileArm64_v8aDebug` successfully after the overlay correction.
- Reinstalled `5.6.5 (565)` on MuMu `127.0.0.1:16384` with `adb install -r`.
- Confirmed the home container now spans `[0,72][1080,1920]` while the capsule remains `[120,1740][960,1908]`; the page is visible beneath the capsule instead of a reserved black strip.
- Confirmed the VOD top-action FAB moves to `[864,1524][1032,1692]`, above the capsule, when the list is collapsed.
- Confirmed the settings version row and the player-settings User-Agent row are fully visible after scrolling to the bottom.
- Confirmed tapping `鎴戠殑` and `鐐规挱` still switches destinations and labels remain complete.

## Rollback

Before committing, restore the overlay and margin hunks in `app/src/mobile/res/layout/activity_home.xml`, `app/src/mobile/res/layout/fragment_vod.xml`, `app/src/mobile/res/layout/fragment_setting.xml`, and `app/src/mobile/res/layout/fragment_setting_player.xml`, together with the earlier navigation/style/color hunks listed above. Do not restore the whole working tree because it contains unrelated existing changes.
