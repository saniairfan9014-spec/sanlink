import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/mic_seat_widget.dart';
import '../widgets/room_chat_section.dart';
import '../controllers/voice_room_controller.dart';
import '../data/models/room_member_model.dart';
import '../data/models/room_model.dart';
import '../data/services/agora_service.dart';
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
  bool _isSpeakerMuted = false;

  String _getRoomDisplayId(String roomId) {
    final hash = roomId.hashCode.abs();
    final sixDigit = 100000 + (hash % 900000);
    return 'ID: $sixDigit';
  }

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

  void _showAudienceSheet(BuildContext context, VoiceRoomState state, AppColorsExtension colors, TextTheme textTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final activeMembers = state.members
            .where((m) => state.activePresenceUserIds.contains(m.userId))
            .toList();

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Active Users (${activeMembers.length})',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Divider(color: colors.border),
              Flexible(
                child: activeMembers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No active listeners',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: activeMembers.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index) {
                          final member = activeMembers[index];
                          final roleName = member.role == RoomRole.host
                              ? 'Host'
                              : member.role == RoomRole.speaker
                                  ? 'Speaker'
                                  : 'Listener';

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.surfaceAlt,
                              backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(member.avatarUrl!)
                                  : null,
                              child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                                  ? Text(
                                      (member.userName ?? 'User').isNotEmpty
                                          ? member.userName![0].toUpperCase()
                                          : '?',
                                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              member.userName ?? 'User',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: member.role == RoomRole.host
                                    ? colors.primary.withOpacity(0.12)
                                    : colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: member.role == RoomRole.host
                                      ? colors.primary.withOpacity(0.3)
                                      : colors.border,
                                ),
                              ),
                              child: Text(
                                roleName,
                                style: textTheme.labelSmall?.copyWith(
                                  color: member.role == RoomRole.host
                                      ? colors.primary
                                      : colors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditRulesDialog(BuildContext context, RoomModel room, AppColorsExtension colors) {
    final controller = TextEditingController(text: room.cleanDescription ?? '');
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Edit Room Rules & Info', style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter room rules, bio, announcements, or custom text...',
            hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.5)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newDesc = RoomModel.formatDescription(
                cleanDescription: controller.text.trim(),
                coverImageUrl: room.coverImageUrl,
                bannedChatUserIds: room.bannedChatUserIds,
                kickedUserIds: room.kickedUserIds,
              );
              ref.read(voiceRoomControllerProvider.notifier).updateRoomInfo(
                room.id,
                room.title,
                newDesc,
                room.category,
              );
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
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
      if (isLocked) {
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
      if (seatUser.userId == _currentUserId) {
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
        if (isHost && state.room != null) {
          _showModerationSheet(
            targetUserId: seatUser.userId,
            targetUserName: seatUser.userName ?? 'Speaker',
            seatUser: seatUser,
            colors: colors,
            room: state.room!,
          );
        }
      }
    }
  }

  void _showModerationSheet({
    required String targetUserId,
    required String targetUserName,
    required RoomMemberModel? seatUser,
    required AppColorsExtension colors,
    required RoomModel room,
  }) {
    final isBannedFromChat = room.bannedChatUserIds.contains(targetUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md, horizontal: Spacing.base),
              child: Text(
                'Moderate $targetUserName',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Divider(color: colors.border),
            if (seatUser != null)
              ListTile(
                leading: Icon(Icons.mic_off, color: colors.red),
                title: Text('Remove from Mic Seat', style: TextStyle(color: colors.red)),
                subtitle: Text('Return speaker back to audience', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(voiceRoomControllerProvider.notifier).leaveSeat(_roomId, targetUserId);
                },
              ),
            ListTile(
              leading: Icon(
                isBannedFromChat ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: colors.primary,
              ),
              title: Text(
                isBannedFromChat ? 'Unban from Chatting' : 'Ban from Chatting',
                style: TextStyle(color: colors.textPrimary),
              ),
              subtitle: Text(
                isBannedFromChat ? 'Allow user to send messages' : 'Mute user from sending messages',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(voiceRoomControllerProvider.notifier).banChatUser(_roomId, targetUserId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isBannedFromChat
                          ? '$targetUserName has been unbanned from chatting.'
                          : '$targetUserName has been banned from chatting.',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    backgroundColor: colors.surface,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.gavel, color: colors.red),
              title: Text('Kick from Room', style: TextStyle(color: colors.red)),
              subtitle: Text('Completely remove and ban user from this room', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ref.read(voiceRoomControllerProvider.notifier).kickUser(_roomId, targetUserId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$targetUserName has been kicked from the room.', style: TextStyle(color: colors.textPrimary)),
                    backgroundColor: colors.surface,
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatWidget(
    int seatIndex,
    List<RoomMemberModel?> seats,
    RoomModel? room,
    bool isHost,
    AppColorsExtension colors,
    VoiceRoomState state,
  ) {
    final seat = seats[seatIndex - 1];
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(voiceRoomControllerProvider);

    ref.listen<VoiceRoomState>(voiceRoomControllerProvider, (previous, next) {
      if (next.isKicked) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have been kicked from the room by the host.', style: TextStyle(color: colors.textPrimary)),
            backgroundColor: colors.red,
          ),
        );
        return;
      }

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

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 64, // Increased height for premium padding and prominence!
        title: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomInfoScreen()));
          },
          child: Row(
            children: [
              // Beautiful rounded Room DP (Cover Thumbnail)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border, width: 1),
                  image: DecorationImage(
                    image: NetworkImage(
                      room?.coverImageUrl ?? _getCategoryCover(room?.category ?? 'Casual'),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Room Title & Unique 6-digit ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      room?.title ?? 'Loading...',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getRoomDisplayId(room?.id ?? _roomId),
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Active Presence Count Button
          GestureDetector(
            onTap: () => _showAudienceSheet(context, state, colors, textTheme),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 14), // Nicely centered in 64px bar
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded, size: 16, color: colors.textPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '${state.activePresenceUserIds.length}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Exit button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () {
              ref.read(voiceRoomControllerProvider.notifier).leaveRoom(_roomId, _currentUserId);
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Slim live indicator banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colors.surface.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (room?.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        room!.category!.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE VOICE CHAT',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 1. Seats section card (all 5 seats beautifully grouped in a single Wrap)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.border.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: List.generate(5, (index) => _buildSeatWidget(index + 1, seats, room, isHost, colors, state)),
                ),
              ),
            ),
            
            // 2. Rules & Info Card positioned just below the mics section card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withOpacity(0.06),
                      colors.accent.withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withOpacity(0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.border.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel_rounded, size: 14, color: colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Room Rules & Info',
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (isHost && room != null)
                          GestureDetector(
                            onTap: () => _showEditRulesDialog(context, room, colors),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 70),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          (room?.cleanDescription == null || room!.cleanDescription!.isEmpty)
                              ? 'Welcome! Respect others, keep the chat positive, and enjoy the stream.'
                              : room.cleanDescription!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Immersive Spacious Chat Section taking the rest of the height
            Expanded(
              child: RoomChatSection(
                messages: state.messages,
                currentUserId: _currentUserId,
                userProfiles: state.userProfiles,
                isChatBanned: room?.bannedChatUserIds.contains(_currentUserId) ?? false,
                isFullHeight: true,
                isMuted: state.isMuted,
                isSpeakerMuted: _isSpeakerMuted,
                onMuteToggle: () {
                  ref.read(voiceRoomControllerProvider.notifier).toggleMute();
                },
                onSpeakerMuteToggle: () {
                  setState(() {
                    _isSpeakerMuted = !_isSpeakerMuted;
                  });
                  ref.read(agoraServiceProvider).muteAllRemoteAudio(_isSpeakerMuted);
                },
                onSendMessage: (text) {
                  ref.read(voiceRoomControllerProvider.notifier).sendMessage(_roomId, _currentUserId, text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryCover(String category) {
    switch (category.toLowerCase()) {
      case 'music & chill':
      case 'music':
        return 'https://images.unsplash.com/photo-1614680376593-902f74a61327?q=80&w=1000';
      case 'gaming':
        return 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=1000';
      case 'chat':
      case 'social':
        return 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?q=80&w=1000';
      case 'tech':
      case 'education':
        return 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=1000';
      default:
        return 'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?q=80&w=1000';
    }
  }
}
