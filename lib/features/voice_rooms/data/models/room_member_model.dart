import 'package:flutter/foundation.dart';

enum RoomRole { host, speaker, listener }

class RoomMemberModel {
  final String id;
  final String roomId;
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final int? micSeat;
  final RoomRole role;
  final bool isMuted;
  final bool isSpeaking;
  final DateTime joinedAt;

  const RoomMemberModel({
    required this.id,
    required this.roomId,
    required this.userId,
    this.userName,
    this.avatarUrl,
    this.micSeat,
    required this.role,
    this.isMuted = true,
    this.isSpeaking = false,
    required this.joinedAt,
  });

  RoomMemberModel copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? userName,
    String? avatarUrl,
    int? micSeat,
    RoomRole? role,
    bool? isMuted,
    bool? isSpeaking,
    DateTime? joinedAt,
  }) {
    return RoomMemberModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      micSeat: micSeat ?? this.micSeat,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'user_name': userName,
      'avatar_url': avatarUrl,
      'mic_seat': micSeat,
      'role': role.name,
      'is_muted': isMuted,
      'is_speaking': isSpeaking,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  factory RoomMemberModel.fromJson(Map<String, dynamic> map) {
    return RoomMemberModel(
      id: map['id'] ?? '',
      roomId: map['room_id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'],
      avatarUrl: map['avatar_url'],
      micSeat: map['mic_seat']?.toInt(),
      role: RoomRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => RoomRole.listener,
      ),
      isMuted: map['is_muted'] ?? true,
      isSpeaking: map['is_speaking'] ?? false,
      joinedAt: map['joined_at'] != null 
          ? DateTime.parse(map['joined_at']) 
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is RoomMemberModel &&
      other.id == id &&
      other.roomId == roomId &&
      other.userId == userId &&
      other.userName == userName &&
      other.avatarUrl == avatarUrl &&
      other.micSeat == micSeat &&
      other.role == role &&
      other.isMuted == isMuted &&
      other.isSpeaking == isSpeaking &&
      other.joinedAt == joinedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      roomId.hashCode ^
      userId.hashCode ^
      userName.hashCode ^
      avatarUrl.hashCode ^
      micSeat.hashCode ^
      role.hashCode ^
      isMuted.hashCode ^
      isSpeaking.hashCode ^
      joinedAt.hashCode;
  }
}
