import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';
import 'package:sanlink/features/chat/screens/direct_chat_screen.dart';

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
    final chatId = await chatService.acceptRequest(requestId, fromUserId);
    
    if (mounted) {
      if (chatId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectChatScreen(
              chatId: chatId,
              friendName: name,
            ),
          ),
        ).then((_) => fetchRequests());
      } else {
        fetchRequests();
      }
    }
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
                        final sender = req['from_user'];
                        final senderName = sender != null ? (sender['name'] ?? 'Unknown User') : 'Unknown User';
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
                                    // REJECT BUTTON
                                    GestureDetector(
                                      onTap: () => _handleReject(req['id']),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _C.surfaceAlt,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _C.red.withOpacity(0.3)),
                                        ),
                                        child: const Icon(Icons.close_rounded, color: _C.red, size: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // ACCEPT BUTTON
                                    GestureDetector(
                                      onTap: () => _handleAccept(req['id'], sender?['id'] ?? '', senderName),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [_C.primary, Color(0xFF9B7BFF)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _C.primary.withOpacity(0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              "Accept",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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