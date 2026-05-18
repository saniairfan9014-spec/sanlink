import 'package:flutter/foundation.dart';

class RoomModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String hostId;
  final String channelName;
  final bool isLive;
  final int listenersCount;
  final DateTime createdAt;
  final List<int> lockedSeats;

  String? get coverImageUrl {
    if (description == null) return null;
    if (description!.contains('||cover_url||')) {
      final parts = description!.split('||cover_url||');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
    }
    return null;
  }

  String? get cleanDescription {
    if (description == null) return null;
    if (description!.contains('||cover_url||')) {
      final parts = description!.split('||cover_url||');
      if (parts.isNotEmpty) {
        return parts[0].trim();
      }
    }
    return description;
  }

  const RoomModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.hostId,
    required this.channelName,
    this.isLive = true,
    this.listenersCount = 0,
    required this.createdAt,
    this.lockedSeats = const [],
  });

  RoomModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? hostId,
    String? channelName,
    bool? isLive,
    int? listenersCount,
    DateTime? createdAt,
    List<int>? lockedSeats,
  }) {
    return RoomModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      hostId: hostId ?? this.hostId,
      channelName: channelName ?? this.channelName,
      isLive: isLive ?? this.isLive,
      listenersCount: listenersCount ?? this.listenersCount,
      createdAt: createdAt ?? this.createdAt,
      lockedSeats: lockedSeats ?? this.lockedSeats,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'host_id': hostId,
      'channel_name': channelName,
      'is_live': isLive,
      'listeners_count': listenersCount,
      'created_at': createdAt.toIso8601String(),
      'locked_seats': lockedSeats,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      category: map['category'] ?? '',
      hostId: map['host_id'] ?? '',
      channelName: map['channel_name'] ?? '',
      isLive: map['is_live'] ?? true,
      listenersCount: map['listeners_count']?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      lockedSeats: map['locked_seats'] != null
          ? List<int>.from(map['locked_seats'] as List)
          : const [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is RoomModel &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.category == category &&
      other.hostId == hostId &&
      other.channelName == channelName &&
      other.isLive == isLive &&
      other.listenersCount == listenersCount &&
      other.createdAt == createdAt &&
      listEquals(other.lockedSeats, lockedSeats);
  }

  @override
  int get hashCode {
    return id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      category.hashCode ^
      hostId.hashCode ^
      channelName.hashCode ^
      isLive.hashCode ^
      listenersCount.hashCode ^
      createdAt.hashCode ^
      lockedSeats.hashCode;
  }
}
