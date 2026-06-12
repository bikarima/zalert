class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final String type; // info / warning / update
  final DateTime createdAt;
  bool isRead;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id:        json['id']?.toString()    ?? '',
      title:     json['title']?.toString() ?? '',
      body:      json['body']?.toString()  ?? '',
      type:      json['type']?.toString()  ?? 'info',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'created_at': createdAt.toIso8601String(),
  };
}
