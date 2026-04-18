import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';

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
  static const green = Color(0xFF00E676);
  static const red = Color(0xFFFF4757);
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final ChatService chatService = ChatService();
  List<Map<String, dynamic>> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    if (mounted) setState(() => loading = true);
    try {
      final reqs = await chatService.getIncomingRequests();
      if (mounted) {
        setState(() {
          requests = reqs;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handleAccept(String requestId, String fromUserId, String name) async {
    HapticFeedback.mediumImpact();
    await chatService.acceptRequest(requestId, fromUserId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Now friends with $name!"),
          backgroundColor: _C.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    fetchRequests();
  }

  Future<void> _handleReject(String requestId) async {
    HapticFeedback.lightImpact();
    await chatService.rejectRequest(requestId);
    fetchRequests();
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
          "Friend Requests",
          style: TextStyle(color: _C.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _C.primary.withOpacity(0.1), blurRadius: 100, spreadRadius: 20),
                ],
              ),
            ),
          ),
          
          loading
              ? const Center(child: CircularProgressIndicator(color: _C.primary))
              : requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_disabled_outlined, size: 64, color: _C.border),
                          const SizedBox(height: 16),
                          const Text("No pending requests", style: TextStyle(color: _C.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final sender = req['users'];
                        final senderName = sender['name'] ?? 'Unknown User';
                        final senderInitial = senderName.isNotEmpty ? senderName[0].toUpperCase() : '?';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _C.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.border.withOpacity(0.5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: _C.surfaceAlt,
                                  child: Text(senderInitial, style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(senderName, style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.bold)),
                                subtitle: Text(sender['email'] ?? '', style: const TextStyle(color: _C.textSecondary, fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close, color: _C.red, size: 22),
                                      onPressed: () => _handleReject(req['id']),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.check, color: _C.green, size: 22),
                                      onPressed: () => _handleAccept(req['id'], sender['id'], senderName),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}