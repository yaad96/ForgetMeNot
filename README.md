# PlanPilot

PlanPilot is an iOS app that turns photos, voice notes, calendar items, and manual input into actionable event plans with tasks and reminders.

Note: Some source paths and folders still use `ForgetMeNot`, which was the app's original development name.

![PlanPilot app preview](ForgetMeNot/Common/Assets.xcassets/appstore.imageset/appstore.png)

## App Store

- Download: https://apps.apple.com/us/app/planpilot/id6751422511

## Highlights

- Photo-to-plan from posters, flyers, and screenshots
- Speech-to-plan with record, transcribe, review, and generate flow
- Calendar/reminder-to-plan from upcoming items
- Manual plan creation
- Auto-generate task lists and reminder timing with AI
- Add recurring reminders with bounded reminder windows
- Add per-task reminders
- Attach reference images to tasks
- Use iOS subject lift to isolate important parts of a photo
- Complete tasks and mark plans as done
- Local persistence via SwiftData

## Tech Stack

- SwiftUI
- SwiftData
- EventKit (Calendar + Reminders)
- UserNotifications
- VisionKit (image subject lift / analysis interaction)
- OpenAI APIs
- `whisper-1` for speech transcription
- `gpt-4o-mini` for plan generation from text/image
- `gpt-3.5-turbo` for calendar-based plan suggestions

## Project Structure

- `ForgetMeNot/App` app entry and model container setup
- `ForgetMeNot/Root` home screen and walkthrough
- `ForgetMeNot/Features/EventPlan` create/edit/detail plan flow
- `ForgetMeNot/Features/SpeechToText` voice recording and transcription flow
- `ForgetMeNot/Features/ImageToEvent` photo-to-plan generation flow
- `ForgetMeNot/Features/CalendarProcessing` calendar/reminder ingestion and AI suggestions
- `ForgetMeNot/Features/ImageProcessing` image picking, subject lift, and task attachments
- `ForgetMeNot/Common` shared helpers (notifications, API key loading, utils)

## Requirements

- macOS with Xcode 15+
- iOS deployment target: 17.6 (app target)
- OpenAI API key

## Getting Started

1. Clone the repository and open `ForgetMeNot.xcodeproj` in Xcode.
2. Create `ForgetMeNot/Root/Secrets.plist` with your API key:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>OPENAI_API_KEY</key>
  <string>YOUR_OPENAI_API_KEY</string>
</dict>
</plist>
```

3. Ensure `ForgetMeNot/Root/Secrets.plist` is excluded from git.
4. Select an iOS simulator/device and run the app.

If an API key was ever committed to a remote repo, rotate it immediately in your OpenAI dashboard.

## Permissions Used

- Camera: capture event photos
- Photo Library: choose existing images
- Microphone: voice-to-plan and voice-to-task
- Calendars: read upcoming events
- Reminders: read upcoming reminders
- Notifications: plan and task reminders

## Privacy Notes

- Plans, tasks, reminders, and attachment metadata are stored locally using SwiftData.
- Content you explicitly provide for AI features (voice transcript, selected image, calendar/reminder text) is sent to OpenAI APIs for processing.
- Audio recordings are temporary and removed after transcription in current flows.

## Testing

- Includes starter unit and UI test targets
- `ForgetMeNotTests`
- `ForgetMeNotUITests`

## License

No license file is currently included in this repository.
