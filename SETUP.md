# Mini-Games Hub — Setup Guide

## 1. Create the Flutter project shell

```bash
flutter create --org com.yourcompany minigames_hub
cd minigames_hub
```

Then copy `pubspec.yaml` and the entire `lib/` folder from this delivery
into the generated project (overwrite the generated `lib/main.dart` and
`pubspec.yaml`).

```bash
flutter pub get
```

## 2. Android setup (`android/app/src/main/AndroidManifest.xml`)

Open the **generated** manifest (not the standalone `android/AndroidManifest.xml`
included in this delivery, which is a reference snippet) and merge in:

1. Inside `<manifest>`, above `<application>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
   <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
   ```
2. Inside `<application>`, add the AdMob App ID meta-data tag:
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-3940256099942544~3347511713" />
   <meta-data
       android:name="com.google.android.gms.ads.DELAY_APP_MEASUREMENT_INIT"
       android:value="true" />
   ```
3. Inside `<manifest>`, after `</application>`, add the package-visibility
   `<queries>` block (required on Android 11+ for reliable ad fill):
   ```xml
   <queries>
       <intent>
           <action android:name="android.intent.action.VIEW" />
           <category android:name="android.intent.category.BROWSABLE" />
           <data android:scheme="https" />
       </intent>
   </queries>
   ```

Set `minSdkVersion` to **21** or higher in `android/app/build.gradle`
(required by both `google_mobile_ads` and `webview_flutter`):

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

## 3. iOS setup (`ios/Runner/Info.plist`)

Merge these keys into the **generated** `ios/Runner/Info.plist` (the
`ios/Info.plist` in this delivery is a reference snippet, not a
drop-in replacement):

- `GADApplicationIdentifier` — the AdMob App ID (test value provided).
- `NSUserTrackingUsageDescription` — required if you call the App
  Tracking Transparency prompt (recommended via the
  `app_tracking_transparency` package before requesting personalized ads).
- `SKAdNetworkItems` — the array of SKAdNetwork IDs.
- `NSAppTransportSecurity` — only needed if any game uses a `remoteUrl`;
  scope `NSExceptionDomains` to your actual game-hosting domain(s).

Set the iOS deployment target to **13.0** or higher in
`ios/Podfile` and in Xcode's Runner target build settings:

```ruby
platform :ios, '13.0'
```

Then:

```bash
cd ios && pod install && cd ..
```

## 4. Bundling local HTML5 games (instant load)

Each game is a self-contained folder under `assets/games/<game_id>/`
with its own `index.html` plus any `js/`, `css/`, `img/` it needs:

```
assets/
  games/
    puzzle_blocks/
      index.html
      style.css
      game.js
    space_shooter/
      index.html
      ...
    soccer_kicks/
      index.html
      ...
    arcade_runner/
      index.html
      ...
  thumbnails/
    puzzle_blocks.png
    space_shooter.png
    soccer_kicks.png
    arcade_runner.png
    daily_challenge.png
```

Every folder must be declared in `pubspec.yaml` under `flutter: assets:`
(already done for the four bundled games in the provided `pubspec.yaml`).
`GameScreen` loads these with `WebViewController.loadFlutterAsset(...)`,
which reads directly from the app bundle — no network round trip, so the
game renders in the same frame budget as any other local asset.

To add a new local game:
1. Drop its folder into `assets/games/<new_id>/`.
2. Add the folder path to `pubspec.yaml` under `flutter: assets:`.
3. Add a matching `Game(...)` entry to `GameCatalog.games` in
   `lib/models/game.dart` with `localAssetPath:
   'assets/games/<new_id>/index.html'`.

## 5. Swapping test ad units for production

Every ad unit ID lives in one place: `lib/services/ad_service.dart`
(the four `static const String ..._AdUnitId` constants) plus the two
platform App IDs in the manifest/plist. Replace all six with your real
AdMob values from the AdMob console before submitting to either store.
Shipping with test IDs will not earn revenue and Google will flag policy
violations if test ads reach production traffic.

## 6. Optional: request consent / ATT before ads (recommended)

For GDPR/CCPA/ATT compliance, integrate the User Messaging Platform
(UMP) SDK (`google_mobile_ads` ships UMP support) and, on iOS, the
`app_tracking_transparency` package, and gate `AdService.instance
.initialize()` behind the consent/ATT flow completing. This delivery
initializes ads immediately on startup for simplicity/performance —
add the consent gate as a thin wrapper around that single call site.
