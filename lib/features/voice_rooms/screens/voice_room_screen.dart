import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/mic_seat_widget.dart';
import '../widgets/voice_controls.dart';
import '../widgets/audience_list_widget.dart';
import '../widgets/room_chat_section.dart';
import '../controllers/voice_room_controller.dart';
import '../data/models/room_member_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'room_info_screen.dart';

class VoiceRoomScreen extends ConsumerStatefulWidget {
  final String? roomId;
  final String? channelName;

  const VoiceRoomScreen({
    super.key,
    this.roomId,
    this.channelName,
  });

  @override
  ConsumerState<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends ConsumerState<VoiceRoomScreen> {
  late final String _roomId;
  late final String _channelName;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId ?? 'room_123';
    _channelName = widget.channelName ?? 'dummy_channel';
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'my_user_id';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceRoomControllerProvider.notifier).initRoom(
        _roomId,
        _currentUserId,
        'dummy_token',
        _channelName,
      );
    });
  }

  void _handleSeatTap({
    required int seatIndex,
    required RoomMemberModel? seatUser,
    required bool isLocked,
    required bool isHost,
    required AppColorsExtension colors,
    required VoiceRoomState state,
  }) {
    if (state.isClaimingSeat) return;

    if (seatUser == null) {
      // Empty seat
      if (isLocked) {
        if (isHost) {
          // Host can unlock
          showModalBottomSheet(
            context: context,
            backgroundColor: colors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_open, color: colors.primary),
                    title: Text('Unlock Seat $seatIndex', style: TextStyle(color: colors.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(voiceRoomControllerProvider.notifier).unlockSeat(_roomId, seatIndex);
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Seat $seatIndex is locked by host', style: TextStyle(color: colors.textPrimary)),
              backgroundColor: colors.surface,
            ),
          );
        }
      } else {
        // Unlocked empty seat
        if (isHost) {
          showModalBottomSheet(
            context: context,
            backgroundColor: colors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.mic, color: colors.primary),
                    title: Text('Claim Seat $seatIndex', style: TextStyle(color: colors.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      final user = Supabase.instance.client.auth.currentUser;
                      final fallbackName = user?.email?.split('@')[0] ?? 'User';
                      ref.read(voiceRoomControllerProvider.notifier).claimSeat(
                        _roomId,
                        _currentUserId,
                        fallbackName,
                        null,
                        seatIndex,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.lock, color: colors.textSecondary),
                    title: Text('Lock Seat $seatIndex', style: TextStyle(color: colors.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(voiceRoomControllerProvider.notifier).lockSeat(_roomId, seatIndex);
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          // Regular listener claiming seat
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: colors.surface,
              title: Text('Claim Seat', style: TextStyle(color: colors.textPrimary)),
              content: Text('Would you like to claim seat $seatIndex and become a speaker?', style: TextStyle(color: colors.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final user = Supabase.instance.client.auth.currentUser;
                    final fallbackName = user?.email?.split('@')[0] ?? 'User';
                    ref.read(voiceRoomControllerProvider.notifier).claimSeat(
                      _roomId,
                      _currentUserId,
                      fallbackName,
                      null,
                      seatIndex,
                    );
                  },
                  child: Text('Claim', style: TextStyle(color: colors.primary)),
                ),
              ],
            ),
          );
        }
      }
    } else {
      // Occupied seat
      if (seatUser.userId == _currentUserId) {
        // Tapped own seat: Leave option
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text('Leave Seat', style: TextStyle(color: colors.textPrimary)),
            content: Text('Would you like to leave your seat and return to the audience?', style: TextStyle(color: colors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(voiceRoomControllerProvider.notifier).leaveSeat(_roomId, _currentUserId);
                },
                child: Text('Leave', style: TextStyle(color: colors.red)),
              ),
            ],
          ),
        );
      } else {
        // Tapped someone else's seat
        if (isHost) {
          // Host controls for occupied seat
          showModalBottomSheet(
            context: context,
            backgroundColor: colors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.exit_to_app, color: colors.red),
                    title: Text('Remove ${seatUser.userName ?? 'Speaker'} from Seat', style: TextStyle(color: colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(voiceRoomControllerProvider.notifier).leaveSeat(_roomId, seatUser.userId);
                    },
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(voiceRoomControllerProvider);

    ref.listen<VoiceRoomState>(voiceRoomControllerProvider, (previous, next) {
      if (next.claimError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.claimError!, style: TextStyle(color: colors.textPrimary)),
            backgroundColor: colors.surface,
          ),
        );
        ref.read(voiceRoomControllerProvider.notifier).clearClaimError();
      }
    });

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final room = state.room;
    final members = state.members;
    final isHost = room?.hostId == _currentUserId;
    
    // Use exact 5 seats mapped by micSeat (1-5)
    final List<RoomMemberModel?> seats = List.generate(5, (_) => null);
    for (final m in members) {
      if ((m.role == RoomRole.host || m.role == RoomRole.speaker) && m.micSeat != null && m.micSeat! >= 1 && m.micSeat! <= 5) {
        seats[m.micSeat! - 1] = m;
      }
    }

    final audience = members.where((m) => m.role == RoomRole.listener).toList();
    
    // Map audience to the format expected by AudienceListWidget
    final audienceMaps = audience.map((m) => {
      'name': m.userName ?? m.userId,
      'image': m.avatarUrl,
      'role': 'Listener',
      'isOnline': true,
    }).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomInfoScreen()));
          },
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      room?.title ?? 'Loading...',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.info_outline, size: 16, color: colors.textSecondary),
                ],
              ),
              Text(
                '${audience.length} listeners • ${seats.where((s) => s != null).length} speakers',
                style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Seats Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xl, horizontal: Spacing.base),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Spacing.xl,
                    runSpacing: Spacing.xl,
                    children: seats.asMap().entries.map((entry) {
                      final index = entry.key;
                      final seat = entry.value;
                      final seatIndex = index + 1;
                      final isLocked = room?.lockedSeats.contains(seatIndex) ?? false;

                      if (seat == null) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            MicSeatWidget(
                              seatIndex: seatIndex,
                              isLocked: isLocked,
                              onTap: () => _handleSeatTap(
                                seatIndex: seatIndex,
                                seatUser: null,
                                isLocked: isLocked,
                                isHost: isHost,
                                colors: colors,
                                state: state,
                              ),
                            ),
                            if (state.isClaimingSeat)
                              const Positioned(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                          ],
                        );
                      }
                      return MicSeatWidget(
                        seatIndex: seatIndex,
                        userName: seat.userName ?? 'Speaker',
                        imageUrl: seat.avatarUrl,
                        isSpeaking: seat.isSpeaking,
                        isMuted: seat.isMuted,
                        isLocked: isLocked,
                        onTap: () => _handleSeatTap(
                          seatIndex: seatIndex,
                          seatUser: seat,
                          isLocked: isLocked,
                          isHost: isHost,
                          colors: colors,
                          state: state,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Divider
              SliverToBoxAdapter(
                child: Container(
                  height: 8,
                  color: colors.surfaceAlt.withOpacity(0.5),
                ),
              ),

              // Audience Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.base, Spacing.lg, Spacing.base, Spacing.sm),
                  child: Text(
                    'Audience (${audienceMaps.length})',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Audience List
              SliverToBoxAdapter(
                child: AudienceListWidget(
                  users: audienceMaps,
                  isGridMode: false,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ),

              // Bottom padding for chat and controls
              const SliverToBoxAdapter(
                child: SizedBox(height: 380),
              ),
            ],
          ),

          // Chat Overlay & Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoomChatSection(
                  messages: state.messages,
                  currentUserId: _currentUserId,
                  userProfiles: state.userProfiles,
                  onSendMessage: (text) {
                    ref.read(voiceRoomControllerProvider.notifier).sendMessage(_roomId, _currentUserId, text);
                  },
                ),
                VoiceControls(
                  isMuted: state.isMuted,
                  onMuteToggle: () {
                    ref.read(voiceRoomControllerProvider.notifier).toggleMute();
                  },
                  onLeave: () {
                    ref.read(voiceRoomControllerProvider.notifier).leaveRoom(_roomId, _currentUserId);
                    Navigator.pop(context);
                  },
                  onRequestMic: () {
                    ref.read(voiceRoomControllerProvider.notifier).requestMic(_roomId, _currentUserId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Mic requested!', style: TextStyle(color: colors.textPrimary)),
                        backgroundColor: colors.surface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
