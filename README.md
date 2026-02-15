# Calodoro

Calodoro is a fast, menu‑bar Pomodoro for macOS that turns focused work into clean calendar truth.

Stay in flow, start sessions in seconds, and let your Google Calendar reflect what actually happened.

## Screenshots
![Timer tab](docs/images/timer_preview.png)
![Settings tab](docs/images/settings_preview.png)

## Highlights
- Menu‑bar first, distraction‑free
- Pomodoro + Timer modes
- Automatic breaks with optional break‑end reminders
- Google Calendar sync for real‑world time tracking
- Create all‑day tasks instantly from the menu

## How it works
1. Click the menu bar icon
2. Start a session or create an all‑day task
3. Focus while Calodoro tracks time
4. Stop when you’re done — your calendar updates with actual work time

## How to use
1) Open the menu bar icon
2) Choose **Pomodoro** or **Timer** mode
3) Start a session or create a new all‑day event
4) (Optional) Select an existing all‑day event to work on
5) Press **Stop** to sync actual time to Google Calendar
6) Adjust work/break presets and notifications in **Settings**

## Made for macOS
- Native SwiftUI menu bar experience
- Lightweight, no dock clutter
- Built for Ventura and newer (macOS 14+)

## Privacy
Your data stays on your Mac. OAuth tokens are stored locally and are never shipped with the app.

---

## Developer Setup
If you want to build from source:

1) Install xcodegen
```bash
brew install xcodegen
```

2) Generate the project
```bash
xcodegen generate
```

3) Open `Calodoro.xcodeproj`

### Google OAuth (PKCE)
Set these keys in `Calodoro/Info.plist`:
- `GOOGLE_CLIENT_ID`
- `GOOGLE_REDIRECT_SCHEME`
- `CFBundleURLSchemes` (must match redirect scheme)

Required scopes:
- `https://www.googleapis.com/auth/calendar.readonly`
- `https://www.googleapis.com/auth/calendar.events`

---

## Roadmap
- Public distribution (signed + notarized)
- Verified OAuth consent flow
