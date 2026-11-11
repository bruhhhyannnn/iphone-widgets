# Glassboard

Free home-screen widgets for iPhone, built in SwiftUI with iOS 26 Liquid Glass. No paywalls, no subscriptions.

| Widget | Sizes | What it shows |
|---|---|---|
| **Daylight** | Small, Medium | Next golden hour / blue hour / sunrise / sunset, a sky that follows the time of day, day length |
| **Agenda** | Small, Medium | Your next event in big type, with side buttons to switch to **Week** and **Sky** (weather) views |
| **Gazette** | Large | Your day printed as a newspaper: lead event, other events, reminders, headlines, tomorrow's forecast, sun times |
| **Month** | Small, Medium | One or two months; tap the arrows to flip months, tap the title to jump back |
| **Flip Clock** | Small, Medium | A split-flap clock |
| **Launcher** | Small, Medium, Large | Drawers of app icons with scenes (gradients or your own photo) and four icon styles |

Every widget has light, dark and **glass** looks. When you set your Home Screen to *Clear* or *Tinted*
(touch and hold the Home Screen › Edit › Customize), the widgets switch to Liquid Glass automatically.

Weather comes from [Open-Meteo](https://open-meteo.com) (free, no account). Sun and moon times are calculated on the phone.

---

## Install it on your iPhone from a Windows PC

You don't need a Mac. GitHub builds the app on its own Macs every time the code changes, and you install the result with a sideloading tool.

### 1. Download the app

Download **`Glassboard.ipa`** from the [latest release](https://github.com/bruhhhyannnn/iphone-widgets/releases/tag/latest).

### 2. Install it with Sideloadly

1. Install **iTunes** and **iCloud** for Windows from Apple's website (the direct-download versions, *not* the Microsoft Store versions).
2. Install [Sideloadly](https://sideloadly.io) and open it.
3. Plug your iPhone in with a cable, unlock it, and tap **Trust** on the phone if asked.
4. Drag `Glassboard.ipa` into Sideloadly, type your Apple ID email, and click **Start**. Enter your Apple ID password when asked.
   A free Apple ID is fine.
   In *Advanced options*, leave app extensions in place. The widgets are an app extension.
5. On the iPhone:
   - **Settings › General › VPN & Device Management**: tap your Apple ID and choose **Trust**.
   - **Settings › Privacy & Security › Developer Mode**: turn it on and restart. This only appears after the first sideload attempt.

*AltStore (with AltServer for Windows) works too, if you prefer it.*

### 3. Every 7 days

Apps installed with a free Apple ID stop opening after 7 days. Re-install the same way, or turn on Sideloadly's automatic refresh, or use AltStore's background refresh.
Your settings are kept when you reinstall over the top.
With the paid Apple Developer Program ($99/year) this limit goes away, and the build could be sent through TestFlight instead.

### 4. First launch

1. **Settings tab › Location**: use your current location or search for your city.
2. Allow **Calendar** and **Reminders** access for Agenda and Gazette.
3. **Launcher tab**: add apps to a drawer and pick a scene and style.
4. Add widgets: touch and hold the Home Screen › **Edit** › **Add Widget** › search for **Glassboard**.
   To pick which drawer a Launcher widget shows, touch and hold it › **Edit Widget**.

**Check:** *Settings › Diagnostics › Shared with widgets* should say **Yes**. If it says **No**, the sideloading tool dropped the App Group, and the widgets can't see your settings. Reinstall and keep app groups/extensions enabled.

---

## Troubleshooting

- **A Launcher icon doesn't open its app.** That app may use a different link. Edit the icon and change its link, or point it at a Shortcut that opens the app.
  You can also turn on *Settings › Open apps through Glassboard*.
- **Weather or headlines are missing.** They load when the widget refreshes. Open the app once and pull down to refresh.
- **The widget looks stale.** iOS limits how often widgets refresh. Opening Glassboard refreshes all of them.

---

## How it's built

```
project.yml          XcodeGen spec (app + widget extension, shared App Group)
App/                 The app: widget gallery, launcher editor, settings
WidgetExtension/     WidgetKit timeline providers and widget definitions
Shared/              Code used by both: models, storage, sun/weather/news/calendar, widget views, App Intents
.github/workflows/   Builds an unsigned .ipa on a macOS runner and publishes it as the "latest" release
```

- The app and the widgets share settings through an App Group. At runtime the group ID is read from the embedded provisioning profile, so it still works if a sideloading tool renames it.
- Widget views live in `Shared/`, so the app previews are the same code as the real widgets.
- Interactive pieces (Month arrows, Agenda view buttons, small Launcher icons) are App Intents.

### Building on a Mac (optional)

```bash
brew install xcodegen
xcodegen generate
open Glassboard.xcodeproj
```

Set your team under *Signing & Capabilities* for both targets and change `BUNDLE_ID_PREFIX` in `project.yml` to something unique.
Requires Xcode 26 and iOS 26.
