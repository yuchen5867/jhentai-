import 'package:flutter/services.dart';
import '../domain/interfaces/volume_button_platform.dart';
import '../domain/models/button_action.dart';

final class MethodChannelVolumeButton implements VolumeButtonPlatform {
  final MethodChannel _methodChannel = const MethodChannel(
    'com.volume_button_override/channel',
  );

  final Map<String, ButtonAction> _actions = {};

  void Function(ButtonAction action)? _buttonPressCallback;

  MethodChannelVolumeButton() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<bool> startListening({
    required ButtonAction volumeUpAction,
    required ButtonAction volumeDownAction,
  }) async {
    _actions.clear();
    _actions[volumeUpAction.id.name] = volumeUpAction;
    _actions[volumeDownAction.id.name] = volumeDownAction;

    try {
      final result = await _methodChannel.invokeMethod<bool>('startListening', {
        'volumeUpAction': volumeUpAction.id.name,
        'volumeDownAction': volumeDownAction.id.name,
      });

      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> stopListening() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopListening');
      _actions.clear();
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  void setButtonPressCallback(void Function(ButtonAction action) callback) {
    _buttonPressCallback = callback;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onVolumeButtonPressed') {
      try {
        final arguments = call.arguments as Map<Object?, Object?>;
        final actionId = arguments['action'] as String?;

        if (actionId != null && _actions.containsKey(actionId)) {
          final action = _actions[actionId]!;
          action.onAction();

          if (_buttonPressCallback != null) {
            _buttonPressCallback!(action);
          }
        }
      } catch (_) {}
    }
  }
}
