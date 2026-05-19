import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../utils/agora_config.dart';
import '../models/room_member_model.dart';

final agoraServiceProvider = Provider<AgoraService>((ref) {
  return AgoraService();
});

class AgoraService {
  RtcEngine? _engine;
  final _speakingController = StreamController<Set<int>>.broadcast();
  bool _isInitialized = false;
  String? _currentChannel;
  int? _currentUid;

  Stream<Set<int>> get onSpeakingStatusChanged => _speakingController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission is required for voice rooms.');
    }

    try {
      // 2. Create the RtcEngine
      _engine = createAgoraRtcEngine();
      
      // 3. Initialize with config
      await _engine!.initialize(
        RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: AgoraConfig.channelProfile,
        ),
      );

      // 4. Configure audio properties for voice-only high performance
      await _engine!.setAudioProfile(
        profile: AgoraConfig.audioProfile,
        scenario: AgoraConfig.audioScenario,
      );

      // Enable the audio volume indication to detect active speaking
      await _engine!.enableAudioVolumeIndication(
        interval: AgoraConfig.speakingDetectionIntervalMs,
        smooth: AgoraConfig.speakingDetectionSmoothFactor,
        reportVad: true,
      );

      // 5. Setup event handler callbacks
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('Successfully joined channel: ${connection.channelId} with uid: ${connection.localUid}');
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            print('Left channel: ${connection.channelId}');
          },
          onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
            final Set<int> activeUids = {};
            for (final speaker in speakers) {
              // Ignore local speaker if volume is below threshold or speaker is muted
              if (speaker.volume != null && speaker.volume! > 10) {
                // If speaker uid is 0, it represents the local speaker
                final uid = speaker.uid == 0 ? (_currentUid ?? 0) : speaker.uid;
                if (uid != null && uid != 0) {
                  activeUids.add(uid);
                }
              }
            }
            _speakingController.add(activeUids);
          },
          onError: (ErrorCodeType err, String msg) {
            print('Agora RTC Error: [$err] $msg');
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            print('Agora Connection State Changed: $state Reason: $reason');
          },
        ),
      );

      _isInitialized = true;
      print('AgoraService successfully initialized');
    } catch (e) {
      print('Failed to initialize Agora RTC engine: $e');
      rethrow;
    }
  }

  Future<void> joinChannel(String token, String channelName, String userId, RoomRole role) async {
    // Proactively initialize if not done yet
    if (!_isInitialized) {
      await initialize();
    }

    final int agoraUid = userId.hashCode.abs() & 0x7FFFFFFF;
    _currentUid = agoraUid;
    _currentChannel = channelName;

    // Fetch secure token dynamically if not provided in parameter
    String activeToken = token;
    if (activeToken.isEmpty) {
      activeToken = await _fetchToken(channelName, userId);
    }

    try {
      // Choose correct client role based on seat/participation
      final clientRole = (role == RoomRole.listener)
          ? ClientRoleType.clientRoleAudience
          : ClientRoleType.clientRoleBroadcaster;

      // Join the channel
      await _engine!.joinChannel(
        token: activeToken,
        channelId: channelName,
        uid: agoraUid,
        options: ChannelMediaOptions(
          clientRoleType: clientRole,
          publishMicrophoneTrack: role != RoomRole.listener,
          autoSubscribeAudio: true,
        ),
      );

      // Explicitly set default mute state
      await muteMic(role == RoomRole.listener);
    } catch (e) {
      print('Error joining Agora channel: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;
    try {
      await _engine!.leaveChannel();
      _currentChannel = null;
      _currentUid = null;
    } catch (e) {
      print('Error leaving Agora channel: $e');
    }
  }

  Future<void> muteMic(bool mute) async {
    if (_engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(mute);
      print('Agora microphone stream muted: $mute');
    } catch (e) {
      print('Error setting mute state on Agora engine: $e');
    }
  }

  Future<void> muteAllRemoteAudio(bool mute) async {
    if (_engine == null) return;
    try {
      await _engine!.muteAllRemoteAudioStreams(mute);
      print('Agora remote audio streams muted: $mute');
    } catch (e) {
      print('Error setting remote audio mute state: $e');
    }
  }

  Future<void> changeRole(RoomRole role) async {
    if (_engine == null) return;
    try {
      final clientRole = (role == RoomRole.listener)
          ? ClientRoleType.clientRoleAudience
          : ClientRoleType.clientRoleBroadcaster;

      await _engine!.setClientRole(role: clientRole);
      
      // Also adjust mic publishing state
      final options = ChannelMediaOptions(
        clientRoleType: clientRole,
        publishMicrophoneTrack: role != RoomRole.listener,
        autoSubscribeAudio: true,
      );
      await _engine!.updateChannelMediaOptions(options);

      // Automatically mute/unmute local mic depending on role
      await muteMic(role == RoomRole.listener);
      print('Agora client role changed to: $role');
    } catch (e) {
      print('Error changing Agora client role: $e');
    }
  }

  Future<String> _fetchToken(String channelName, String userId) async {
    final int intUid = userId.hashCode.abs() & 0x7FFFFFFF;
    try {
      final url = Uri.parse('${AgoraConfig.tokenServiceUrl}?channelName=$channelName&uid=$intUid');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] ?? '';
      }
    } catch (e) {
      print('Agora GET token failed, trying POST: $e');
      try {
        final response = await http.post(
          Uri.parse(AgoraConfig.tokenServiceUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'channelName': channelName,
            'uid': intUid,
            'userId': userId,
          }),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['token'] ?? '';
        }
      } catch (e2) {
        print('Agora token server unreachable: $e2');
      }
    }
    return ''; // Fallback for testing mode (supports joining without token)
  }

  void dispose() {
    leaveChannel();
    if (_engine != null) {
      _engine!.release();
      _engine = null;
    }
    _speakingController.close();
    _isInitialized = false;
  }
}
