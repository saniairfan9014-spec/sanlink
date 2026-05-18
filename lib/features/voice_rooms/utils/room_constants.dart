import '../data/models/room_member_model.dart';

class RoomConstants {
  static const int maxSeats = 10;
  static const RoomRole defaultRole = RoomRole.listener;
  static const bool defaultMuteState = true;
  
  // Seat locking rules
  static const bool allowHostToLock = true;
  static const bool allowSpeakerToLock = false;
  
  // Room Status Constants
  static const String statusActive = 'active';
  static const String statusEnded = 'ended';
}

enum RoomStatus { active, ended }
