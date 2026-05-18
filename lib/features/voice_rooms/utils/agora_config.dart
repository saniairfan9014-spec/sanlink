import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class AgoraConfig {
  // Agora App ID for production voice rooms
  static const String appId = "8b64e52ec7cc42b6a22c5ef2256dfebf";

  // Token service endpoint (Supabase edge function url or backend endpoint)
  static const String tokenServiceUrl = "https://odhzkmgxnujisjuixiju.supabase.co/functions/v1/get-rtc-token";

  // Configuration profiles for high-performance audio communication
  static const ChannelProfileType channelProfile = ChannelProfileType.channelProfileLiveBroadcasting;
  static const AudioScenarioType audioScenario = AudioScenarioType.audioScenarioGameStreaming;
  static const AudioProfileType audioProfile = AudioProfileType.audioProfileMusicStandard;
  
  // Speaker detection volume threshold and interval
  static const int speakingDetectionIntervalMs = 300;
  static const int speakingDetectionSmoothFactor = 3;
}
