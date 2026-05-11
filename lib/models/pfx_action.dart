// lib/models/pfx_action.dart

class PFxAction {
  final String label;
  final int actionId;
  final int channel;

  PFxAction({
    required this.label,
    required this.actionId,
    required this.channel,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'actionId': actionId,
    'channel': channel,
  };

  factory PFxAction.fromJson(Map<String, dynamic> json) => PFxAction(
    label: json['label'],
    actionId: json['actionId'],
    channel: json['channel'],
  );
}