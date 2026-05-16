import 'package:flutter/foundation.dart';

class RoomMessageModel {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;

  const RoomMessageModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  RoomMessageModel copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? content,
    DateTime? createdAt,
  }) {
    return RoomMessageModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': userId,
      'message': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RoomMessageModel.fromJson(Map<String, dynamic> map) {
    return RoomMessageModel(
      id: map['id'] ?? '',
      roomId: map['room_id'] ?? '',
      userId: map['sender_id'] ?? '',
      content: map['message'] ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is RoomMessageModel &&
      other.id == id &&
      other.roomId == roomId &&
      other.userId == userId &&
      other.content == content &&
      other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      roomId.hashCode ^
      userId.hashCode ^
      content.hashCode ^
      createdAt.hashCode;
  }
}
