import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

final agoraServiceProvider = Provider<AgoraService>((ref) {
  return AgoraService();
});

class AgoraService {
  final _speakingController = StreamController<bool>.broadcast();
  
  Stream<bool> get onSpeakingStatusChanged => _speakingController.stream;

  Future<void> initialize() async {
    // TODO: Initialize Agora RTC Engine
    print('AgoraService initialized');
  }

  Future<void> joinChannel(String token, String channelName, String uid) async {
    // TODO: Join Agora channel
    print('Joined channel $channelName with uid $uid');
  }

  Future<void> leaveChannel() async {
    // TODO: Leave Agora channel
    print('Left channel');
  }

  Future<void> muteMic(bool mute) async {
    // TODO: Mute/unmute local audio
    print('Mic muted: $mute');
  }
  
  void dispose() {
    _speakingController.close();
  }
}
