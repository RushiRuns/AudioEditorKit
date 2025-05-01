# AudioEditorKit

Simplified audio editing library for Swift + UIKit. Requires iOS 16.0+

![Screenshot](./Resources/Simulator%20Screenshot.png)

## Features

- 🔊 **Smart Audio Loading**: Seamlessly import audio files from any URL
- 📊 **Waveform Visualization**: Automatic generation of sleek waveform displays
- ✂️ **Intuitive Editing Tools**: Interactive playback, precision trimming, and segment deletion
- 💾 **Simple Export**: One-click export of your professionally edited audio

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Lakr233/AudioEditorKit", from: "0.1.0"),
]
```

## Usage

**Localization**

To use built-in localization, add the following to your `Info.plist`:

```xml
<key>CFBundleAllowMixedLocalizations</key>
<true/>
```

**AVAudioSession**

Make sure to set up your `AVAudioSession` before using the library.

```swift
import AVKit

try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
try? AVAudioSession.sharedInstance().setActive(true)
```

**Using AudioEditorKit**

Check out the example project for a complete implementation. Basic usage is as simple as:

```swift
let rep = AudioFileRepresentable(
    url: url,
    aliasTitle: url.lastPathComponent,
    descriptionText: String(localized: "Example Audio File")
)

AudioEditorKit.presentEditor(audio: rep, parent: self) { edited, newURL in
    if edited {
        // Handle the edited audio file at newURL
    }
}
```

Additionally, you can specify export options by using the `exportAudioSettings` property of `AudioFileRepresentable`.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

This project incorporates code from [dmrschmidt/DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage), also licensed under the MIT License.

---

Copyright 2025 © Lakr233 & Lessica @ OwnGoal Studio. All rights reserved.
