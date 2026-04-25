// /Users/irfanhussain/Documents/flutter /sanlink/lib/features/chat/screens/search_users_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';

import 'package:sanlink/widgets/profile_avatar.dart';

class _C {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C27);
  static const border = Color(0xFF2A2A3D);
  static const primary = Color(0xFF7C5CFC);
  static const primaryGlow = Color(0x337C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF44445A);
}

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  List<Map<String, dynamic>> _results = [];
  Set<String> _pendingRequests = {};
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().length < 2) {
      if (mounted) setState(() { _results = []; _isSearching = false; });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      
      final results = await chatService.searchUsers(query);
      
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _sendRequest(String userId) async {
    HapticFeedback.lightImpact();
    setState(() {
      _pendingRequests.add(userId);
    });
    
    final error = await chatService.sendChatRequest(userId);
    
    if (mounted) {
      if (error != null) {
        setState(() => _pendingRequests.remove(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat request sent!'),
            backgroundColor: _C.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Friends',
          style: TextStyle(color: _C.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: _C.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: _C.textPrimary),
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: TextStyle(color: _C.textMuted),
                  prefixIcon: Icon(Icons.search, color: _C.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : _results.isEmpty && _searchController.text.trim().length >= 2
                    ? const Center(
                        child: Text('No users found.', style: TextStyle(color: _C.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final name = user['name'] ?? 'Unknown';
                          final userId = user['id'];
                          final isPending = _pendingRequests.contains(userId);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: ProfileAvatar(
                              avatarUrl: user['avatar_url'],
                              frameUrl: user['selected_frame']?['image_url'],
                              size: 40,
                              name: name,
                            ),
                            title: Text(name, style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.bold)),
                            subtitle: Text(user['email'] ?? '', style: const TextStyle(color: _C.textSecondary, fontSize: 12)),
                            trailing: isPending
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _C.surfaceAlt,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _C.border),
                                    ),
                                    child: const Text('Pending', style: TextStyle(color: _C.textSecondary, fontSize: 12)),
                                  )
                                : GestureDetector(
                                    onTap: () => _sendRequest(userId),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _C.primaryGlow,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _C.primary.withOpacity(0.5)),
                                      ),
                                      child: const Text('Add', style: TextStyle(color: _C.primary, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
