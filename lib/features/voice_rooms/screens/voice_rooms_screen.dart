import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/shimmer_loading.dart';
import '../widgets/voice_room_card.dart';
import '../controllers/voice_rooms_list_provider.dart';
import '../data/models/room_model.dart';
import 'create_room_screen.dart';
import 'voice_room_screen.dart';

class VoiceRoomsScreen extends ConsumerStatefulWidget {
  const VoiceRoomsScreen({super.key});

  @override
  ConsumerState<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends ConsumerState<VoiceRoomsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  int _mySubTab = 0; // 0=Recent, 1=Joined, 2=Following
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<RoomModel> _filterRooms(List<RoomModel> rooms) {
    var filtered = rooms;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Tab-based filtering
    if (_mainTabController.index == 1) {
      // "My" tab
      switch (_mySubTab) {
        case 0: // Recent - show all sorted by created_at (already sorted)
          filtered =
              filtered.where((r) => r.hostId == _currentUserId).toList();
          break;
        case 1: // Joined - rooms where user is a member
          filtered =
              filtered.where((r) => r.hostId == _currentUserId).toList();
          break;
        case 2: // Following - placeholder
          filtered = [];
          break;
      }
    }

    return filtered;
  }

  RoomModel? _getMyActiveRoom(List<RoomModel> rooms) {
    try {
      return rooms.firstWhere((r) => r.hostId == _currentUserId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final roomsAsync = ref.watch(activeRoomsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          // ── Custom Header ──
          _buildHeader(colors, textTheme),

          // ── Main Tabs (Explore / My) ──
          _buildMainTabs(colors, textTheme),

          // ── Sub-tabs for "My" ──
          if (_mainTabController.index == 1)
            _buildMySubTabs(colors, textTheme),

          // ── Room List ──
          Expanded(
            child: roomsAsync.when(
              data: (rooms) {
                final filtered = _filterRooms(rooms);
                final myRoom = _getMyActiveRoom(rooms);
                return _buildRoomList(filtered, myRoom, colors, textTheme);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerFeedLoading(count: 4),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: TextStyle(color: colors.textMuted)),
              ),
            ),
          ),
        ],
      ),

      // ── FAB ──
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateRoomScreen()));
        },
        backgroundColor: colors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────
  Widget _buildHeader(AppColorsExtension colors, TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
            bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Title
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [colors.primary, colors.accent],
            ).createShader(bounds),
            child: Text('Rooms',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1)),
          ),
          const Spacer(),

          // Search toggle
          if (_showSearch)
            Expanded(
              flex: 3,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                      color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search rooms...',
                    hintStyle: TextStyle(
                        color: colors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),

          IconButton(
            icon: Icon(
                _showSearch ? Icons.close : Icons.search,
                color: colors.textSecondary,
                size: 22),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Main Tabs ────────────────────────────
  Widget _buildMainTabs(AppColorsExtension colors, TextTheme textTheme) {
    return Container(
      color: colors.surface,
      child: TabBar(
        controller: _mainTabController,
        indicatorColor: colors.primary,
        indicatorWeight: 3,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textMuted,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 15),
        tabs: const [
          Tab(text: 'Explore'),
          Tab(text: 'My'),
        ],
      ),
    );
  }

  // ───────────────────── My Sub Tabs ────────────────────────────
  Widget _buildMySubTabs(AppColorsExtension colors, TextTheme textTheme) {
    final labels = ['Recent', 'Joined', 'Following'];
    return Container(
      height: 44,
      color: colors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _mySubTab == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _mySubTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withOpacity(0.15)
                      : colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? colors.primary
                        : colors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected
                        ? colors.primary
                        : colors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────── Room List Body ───────────────────────────
  Widget _buildRoomList(List<RoomModel> rooms, RoomModel? myRoom,
      AppColorsExtension colors, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(activeRoomsProvider),
      color: colors.primary,
      backgroundColor: colors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── My Room Highlight ──
          _buildMyRoomCard(myRoom, colors, textTheme),
          const SizedBox(height: 16),

          // ── Room list ──
          if (rooms.isEmpty)
            _buildEmptyState(colors, textTheme)
          else
            ...rooms.map((room) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VoiceRoomCard(
                    title: room.title,
                    hostName: room.hostId,
                    hostImage:
                        'https://i.pravatar.cc/150?u=${room.hostId}',
                    listenerCount: room.listenersCount,
                    speakerCount: 1,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VoiceRoomScreen(
                            roomId: room.id,
                            channelName: room.channelName,
                          ),
                        ),
                      );
                    },
                  ),
                )),
        ],
      ),
    );
  }

  // ────────────────── My Room Highlight Card ────────────────────
  Widget _buildMyRoomCard(
      RoomModel? myRoom, AppColorsExtension colors, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withOpacity(0.12),
            colors.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.25)),
      ),
      child: myRoom != null
          ? Row(
              children: [
                // Room info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.greenAccent.withOpacity(0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Your Room is Live',
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(myRoom.title,
                          style: textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '${myRoom.listenersCount} listeners',
                          style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),

                // Enter button
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VoiceRoomScreen(
                          roomId: myRoom.id,
                          channelName: myRoom.channelName,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enter',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No active room yet',
                          style: textTheme.titleSmall?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Start one and go live!',
                          style: TextStyle(
                              color: colors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateRoomScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }

  // ────────────────────── Empty State ────────────────────────────
  Widget _buildEmptyState(AppColorsExtension colors, TextTheme textTheme) {
    String message;
    String subtitle;

    if (_mainTabController.index == 1) {
      switch (_mySubTab) {
        case 0:
          message = 'No recent rooms';
          subtitle = 'Rooms you visit will appear here';
          break;
        case 1:
          message = 'No joined rooms';
          subtitle = 'Join a room to see it here';
          break;
        case 2:
          message = 'Not following anyone yet';
          subtitle = 'Follow users to see their rooms';
          break;
        default:
          message = 'No rooms';
          subtitle = '';
      }
    } else {
      message = 'No live rooms right now';
      subtitle = 'Be the first to start a conversation!';
    }

    return SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.mic_off_rounded,
                  color: colors.textMuted, size: 28),
            ),
            const SizedBox(height: 16),
            Text(message,
                style: textTheme.titleSmall
                    ?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    color: colors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
