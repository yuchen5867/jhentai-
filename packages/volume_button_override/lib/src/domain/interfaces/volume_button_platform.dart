import '../models/button_action.dart';

abstract interface class VolumeButtonPlatform {
  Future<bool> startListening({
    required ButtonAction volumeUpAction,
    required ButtonAction volumeDownAction,
  });
  Future<bool> stopListening();
  void setButtonPressCallback(void Function(ButtonAction action) callback);
}
