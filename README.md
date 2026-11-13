# KStep

Girl group choreography video lessons in a native SwiftUI iPhone app. Eight-count drills with song section, speed, mirrored practice and run results.

Open `KStep.xcodeproj` and select the shared `KStep` scheme. The minimum deployment target is iOS 17. The Duo layout paths use the iOS 27.1 SDK, which is available in Xcode 27.1.

## Test configuration

- API host `devapi.io-jp.com` and `getV2.name` `KStep`.
- KStep uses `com.kstepstudio.eightcount` as its Bundle ID in `Config/KStep.xcconfig`. Guest login `source` and business `packageName` derive from that setting.
- Google iOS demo App ID, app-open and rewarded units. Membership requests `coins_1.99` monthly (USD 9.99) and `conis_4.99` yearly (USD 99.99) in Apple Sandbox. The app displays the prices returned by StoreKit.
- Website, terms and privacy point to HTTPS placeholders.

For playback integration, enter the Clipo test short code from the Toolkit on Home. Verify that the search result opens in the full-screen player. Use a new or authorized test account when verifying Apple purchases and restores.

## Production transition

After test acceptance, configure the API domain, AdMob, official links and membership mapping for production. Verify backend registration and signing for `com.kstepstudio.eightcount`, receipt routing and the `KStep` release configuration name against the effective build settings.

## Verification

Source, project settings and asset references were reviewed. Builds, live backend calls, playback, ad impressions, Apple transactions and iPhone Duo device behavior remain to be verified.
