import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanlink/services/frame_service.dart';
import 'package:sanlink/core/theme/app_theme.dart';

class FramesScreen extends StatefulWidget {
  const FramesScreen({super.key});

  @override
  State<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends State<FramesScreen> {
  final FrameService _frameService = FrameService();

  List frames = [];
  List userFrames = [];
  String? selectedFrameId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final allFrames = await _frameService.getAllFrames();
      final unlocked = await _frameService.getUserFrames();
      
      // Fetch current user's equipped frame URL for selection highlighting
      final currentUser = _frameService.client.auth.currentUser;
      String? currentFrameUrl;
      if (currentUser != null) {
        try {
          final profile = await _frameService.client
              .from('users')
              .select('name, avatar_url, profile_pic') // Only select columns that definitely exist
              .eq('id', currentUser.id)
              .maybeSingle();
          
          if (profile != null) {
            // Check for DB column (we already know it might fail, so we'll check local fallback)
          }
        } catch (e) {
          debugPrint("Profile frame column missing in users table: $e");
        }

        // Check local storage fallback
        currentFrameUrl = await _frameService.getLocalEquippedFrame();
      }

      // Fallback: If no frames in table, check the bucket directly
      List<dynamic> combinedFrames = List.from(allFrames);
      if (combinedFrames.isEmpty) {
        final bucketFrames = await _frameService.getBucketFrames();
        combinedFrames.addAll(bucketFrames);
      }

      // Determine selected frame ID based on either URL match or table flag
      String? initialSelectedId;
      if (currentFrameUrl != null) {
        final matchingFrame = combinedFrames.firstWhere(
          (f) => f['image_url'] == currentFrameUrl,
          orElse: () => null,
        );
        if (matchingFrame != null) {
          initialSelectedId = matchingFrame['id'] ?? matchingFrame['name'];
        }
      }

      // Fallback to table-based equipped flag if URL match failed
      if (initialSelectedId == null) {
        final equipped = unlocked.firstWhere(
              (f) => f['is_equipped'] == true,
          orElse: () => null,
        );
        initialSelectedId = equipped?['frame_id'];
      }

      setState(() {
        frames = combinedFrames;
        userFrames = unlocked;
        selectedFrameId = initialSelectedId;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      // Try bucket as last resort on error
      try {
        final bucketFrames = await _frameService.getBucketFrames();
        setState(() {
          frames = bucketFrames;
          isLoading = false;
        });
      } catch (_) {
        setState(() => isLoading = false);
      }
    }
  }

  bool isUnlocked(String frameId) {
    // If it's a discovered frame (from bucket fallback), we allow it for now
    final isDiscovered = frames.any((f) => (f['id'] == frameId || f['name'] == frameId) && f['is_discovered'] == true);
    if (isDiscovered) return true;
    
    return userFrames.any((f) => f['frame_id'] == frameId);
  }

  Future<void> onFrameTap(dynamic frame) async {
    final frameId = frame['id'] ?? frame['name'];
    final imageUrl = frame['image_url'];

    if (!isUnlocked(frameId)) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unlock at Level ${frame['required_level']}!"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (selectedFrameId == frameId) return;

    HapticFeedback.mediumImpact();
    setState(() => selectedFrameId = frameId);

    try {
      await _frameService.equipFrame(frameId, imageUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("New frame equipped! 🎉"),
              ],
            ),
            backgroundColor: context.colors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Equip error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "FRAME COLLECTIONS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    "Personalize your avatar with exclusive achievement frames.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: frames.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final frame = frames[index];
                      final unlocked = isUnlocked(frame['id']);
                      final selected = selectedFrameId == frame['id'];

                      return GestureDetector(
                        onTap: () => onFrameTap(frame),
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected 
                                        ? context.colors.primary 
                                        : (unlocked ? context.colors.border : Colors.transparent),
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [BoxShadow(color: context.colors.primary.withOpacity(0.3), blurRadius: 15)]
                                      : [],
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Opacity(
                                        opacity: unlocked ? 1 : 0.3,
                                        child: Image.network(
                                          frame['image_url'],
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    if (!unlocked)
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.lock_rounded, color: Colors.white54, size: 20),
                                            const SizedBox(height: 4),
                                            Text(
                                              "LVL ${frame['required_level']}",
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (selected)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: context.colors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              frame['name'] ?? "Frame",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unlocked ? Colors.white : context.colors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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