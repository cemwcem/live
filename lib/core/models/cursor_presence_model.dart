class CursorPresenceModel {
  const CursorPresenceModel({
    required this.nick,
    required this.offset,
    required this.updatedAt,
  });

  final String nick;
  final int offset;
  final int updatedAt;

  factory CursorPresenceModel.fromJson(Map<String, dynamic> json) {
    return CursorPresenceModel(
      nick: json['nick']?.toString() ?? '',
      offset: _toInt(json['offset']),
      updatedAt: _toInt(json['updatedAt']),
    );
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? -1;
    }
    return -1;
  }
}
