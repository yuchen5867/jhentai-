# Volume Button Override

A plugin that allows customization of volume buttons on Android and iOS platforms.

## Features

- Assign custom functions to volume up and down buttons
- Trigger custom actions when buttons are pressed
- Support for both Android and iOS

## Important Note (iOS Simulator)

When this plugin is run on the iOS Simulator, a helper interface (HUD) with "+" and "-" buttons will appear in the bottom right corner (default position) of the screen to allow you to test the volume button functionality. This interface is **only visible in the simulator** and does not appear on real devices.

## Installation

Add the plugin to your pubspec.yaml file:

```yaml
dependencies:
  volume_button_override: ^0.0.1
```

## Usage

### Basic Usage

```dart
import 'package:volume_button_override/volume_button_override.dart';

// Create a controller
final controller = VolumeButtonController();

// Define actions
final volumeUpAction = ButtonAction(
  id: ButtonActionId.volumeUp,
  onAction: () {
    print('Volume up button pressed!');
    // Perform your desired action
  },
);

final volumeDownAction = ButtonAction(
  id: ButtonActionId.volumeDown,
  onAction: () {
    print('Volume down button pressed!');
    // Perform your desired action
  },
);

// Start listening
await controller.startListening(
  volumeUpAction: volumeUpAction,
  volumeDownAction: volumeDownAction,
);

// Stop listening
await controller.stopListening();
```

### Callback Usage

You can also set up a central callback function that will be triggered when the buttons are pressed:

```dart
controller.setButtonPressCallback((action) {
  print('${action.id.toString()} action triggered!');
  // Perform central action
});
```

## Example Application

You can examine the example application included in the package for more information.

## Platform Features

### Android

- Does not change the system volume level when volume buttons are pressed
- Captures KeyEvent.KEYCODE_VOLUME_UP and KeyEvent.KEYCODE_VOLUME_DOWN events

### iOS

- Does not change the system volume level when volume buttons are pressed
- Captures volume button events by observing `outputVolume` changes via `AVAudioSession`.

## License

This project is licensed under the MIT license.
