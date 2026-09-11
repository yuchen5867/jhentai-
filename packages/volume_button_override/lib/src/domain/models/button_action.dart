import 'package:flutter/foundation.dart';
import 'package:volume_button_override/src/domain/models/button_action_id.dart';

final class ButtonAction {
  final ButtonActionId id;

  final VoidCallback onAction;

  const ButtonAction({required this.id, required this.onAction});
}
