class PostModel {
  final String id;
  final String content;
  final String userId;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.content,
    required this.userId,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      content: json['content'] ?? '',
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}