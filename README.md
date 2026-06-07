# MyAIChat

A skeleton SwiftUI iOS app for an AI chat application (ChatGPT-like UI), structured with **MVVM** and **no external dependencies**.

> ⚠️ This is a **project skeleton only**. Files contain compilable placeholders (`// TODO`) — the full UI and logic are intentionally not implemented yet.

## Requirements

- Xcode 15+ (iOS 16.0 minimum deployment target)
- No third-party dependencies (pure SwiftUI + Foundation)

## Project structure

```
MyAIChat/
├── MyAIChat.xcodeproj/          # Xcode project (+ shared scheme for CI)
├── MyAIChat/
│   ├── App/                     # App entry point (@main)
│   ├── Models/                  # Data models (ChatMessage, Conversation)
│   ├── ViewModels/              # ObservableObject view models (MVVM)
│   ├── Views/                   # SwiftUI views
│   ├── Services/                # AI + persistence abstractions
│   ├── Utilities/               # Shared helpers / extensions
│   ├── Resources/               # Assets.xcassets
│   └── Info.plist
├── codemagic.yaml               # Codemagic CI build config
├── .gitignore
└── README.md
```

## Architecture (MVVM)

- **Models** — plain `Codable` value types describing chat data.
- **ViewModels** — `@MainActor` `ObservableObject`s that own state and expose intent methods to the views.
- **Views** — pure SwiftUI, observe view models, contain no business logic.
- **Services** — protocol-based abstractions (`AIService`, `PersistenceService`) so concrete implementations can be swapped/mocked.

## Configuration

| Setting               | Value                   |
| --------------------- | ----------------------- |
| Bundle identifier     | `com.example.MyAIChat`  |
| Deployment target     | iOS 16.0                |
| Swift version         | 5.0                     |
| Device family         | iPhone + iPad           |

## Build locally

```bash
open MyAIChat.xcodeproj
# then Run (⌘R) in Xcode
```

Or from the command line (simulator, no signing):

```bash
xcodebuild \
  -project MyAIChat.xcodeproj \
  -scheme MyAIChat \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

## Continuous Integration (Codemagic)

The included `codemagic.yaml` defines an `ios-build` workflow that builds the
`MyAIChat` scheme for the iOS Simulator without code signing — perfect for
verifying the skeleton compiles. Connect the repository in Codemagic and the
workflow will be detected automatically.

## Next steps (TODO)

- [ ] Implement `ChatView` message list + auto-scroll
- [ ] Implement `MessageInputView` send flow
- [ ] Wire `ChatViewModel` to a concrete `AIService`
- [ ] Implement `PersistenceService` (FileManager / SwiftData)
- [ ] Build conversation navigation (`ConversationListView` → `ChatView`)
- [ ] Add app icon + accent color assets
