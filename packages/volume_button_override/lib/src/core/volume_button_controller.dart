import '../domain/interfaces/volume_button_platform.dart';
import '../domain/models/button_action.dart';
import '../data/method_channel_volume_button.dart';

final class VolumeButtonController {
  final VolumeButtonPlatform _platform;

  ButtonAction? _volumeUpAction;
  ButtonAction? _volumeDownAction;
  bool _isListening = false;

  VolumeButtonController([VolumeButtonPlatform? platform])
    : _platform = platform ?? MethodChannelVolumeButton();

  Future<bool> startListening({
    required ButtonAction volumeUpAction,
    required ButtonAction volumeDownAction,
  }) async {
    if (_isListening) {
      await stopListening();
    }

    _volumeUpAction = volumeUpAction;
    _volumeDownAction = volumeDownAction;

    final result = await _platform.startListening(
      volumeUpAction: volumeUpAction,
      volumeDownAction: volumeDownAction,
    );

    _isListening = result;
    return result;
  }

  Future<bool> stopListening() async {
    if (!_isListening) {
      return true;
    }

    final result = await _platform.stopListening();
    if (result) {
      _isListening = false;
      _volumeUpAction = null;
      _volumeDownAction = null;
    }

    return result;
  }

  void setButtonPressCallback(void Function(ButtonAction action) callback) {
    _platform.setButtonPressCallback(callback);
  }

  bool get isListening => _isListening;
  ButtonAction? get volumeUpAction => _volumeUpAction;
  ButtonAction? get volumeDownAction => _volumeDownAction;
}
