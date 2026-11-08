import 'dart:convert';

class Alarm {
  const Alarm({required this.id, required this.hour, required this.minute, required this.label, required this.message, required this.enabled, required this.repeatDaily});
  final int id, hour, minute;
  final String label, message;
  final bool enabled, repeatDaily;
  Alarm copyWith({int? hour, int? minute, String? label, String? message, bool? enabled, bool? repeatDaily}) => Alarm(
    id: id, hour: hour ?? this.hour, minute: minute ?? this.minute, label: label ?? this.label,
    message: message ?? this.message, enabled: enabled ?? this.enabled, repeatDaily: repeatDaily ?? this.repeatDaily,
  );
  Map<String, dynamic> toJson() => {'id': id, 'hour': hour, 'minute': minute, 'label': label, 'message': message, 'enabled': enabled, 'repeatDaily': repeatDaily};
  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
    id: json['id'] as int, hour: json['hour'] as int, minute: json['minute'] as int,
    label: json['label'] as String? ?? 'Wake up', message: json['message'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true, repeatDaily: json['repeatDaily'] as bool? ?? false,
  );
  static String encodeAll(List<Alarm> alarms) => jsonEncode(alarms.map((a) => a.toJson()).toList());
}
