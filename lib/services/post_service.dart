import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  final supabase = Supabase.instance.client;

  void log(String message) => print("📌 [PostService] $message");

  // CREATE TEXT POST
  Future<void> createPost(String content) async {
    final user = supabase.auth.currentUser;
    if (user == null) return log("User not logged in");

    try {
      log("Creating post...");
      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
      });
      log("Post created ✅");
    } catch (e) {
      log("Error creating post ❌: $e");
    }
  }

  // CREATE POST WITH MEDIA
  Future<void> createPostWithMedia({
    required String content,
    required String mediaUrl,
    required String mediaType,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return log("User not logged in");

    try {
      log("Creating post with media...");
      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'media_url': mediaUrl,
        'media_type': mediaType,
      });
      log("Post with media created ✅");
    } catch (e) {
      log("Error creating post ❌: $e");
    }
  }

  // UPLOAD MEDIA (WEB + MOBILE)
  Future<String?> uploadMedia({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String? contentType,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return log("User not logged in") as String?;

    try {
      log("Uploading media...");

      final fileExt = fileName.split('.').last;
      final newFileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      if (kIsWeb) {
        if (fileBytes == null) return log("fileBytes is null ❌") as String?;
        await supabase.storage.from('post-media').uploadBinary(
          newFileName,
          fileBytes,
          fileOptions: FileOptions(contentType: contentType),
        );
      } else {
        if (filePath == null) return log("filePath is null ❌") as String?;
        final file = File(filePath);
        await supabase.storage.from('post-media').upload(
          newFileName,
          file,
          fileOptions: FileOptions(contentType: contentType),
        );
      }

      final publicUrl = supabase.storage.from('post-media').getPublicUrl(newFileName);
      log("Media uploaded ✅ URL: $publicUrl");

      return publicUrl;
    } catch (e) {
      log("Error uploading media ❌: $e");
      return null;
    }
  }

  // GET POSTS
  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final data = await supabase
          .from('posts')
          .select('*, users(name, avatar_url, profile_pic)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log("Error fetching posts ❌: $e");
      return [];
    }
  }

  // LIKES
  Future<void> likePost(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('likes').insert({'post_id': postId, 'user_id': user.id});
  }

  Future<void> unlikePost(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('likes').delete().eq('post_id', postId).eq('user_id', user.id);
  }

  Future<bool> isLiked(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final res = await supabase.from('likes').select().eq('post_id', postId).eq('user_id', user.id).maybeSingle();
    return res != null;
  }

  Future<int> getLikesCount(String postId) async {
    final res = await supabase.from('likes').select().eq('post_id', postId);
    return res.length;
  }

  // COMMENTS
  Future<void> addComment(String postId, String content) async {
    final user = supabase.auth.currentUser;
    if (user == null || content.trim().isEmpty) return;
    await supabase.from('comments').insert({'post_id': postId, 'user_id': user.id, 'comment': content.trim()});
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final data = await supabase
        .from('comments')
        .select('*, users(name, avatar_url, profile_pic)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }
  // DELETE POST
  Future<void> deletePost(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return log("User not logged in");

    try {
      // Optional: only allow deleting your own posts
      final post = await supabase.from('posts')
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();

      if (post == null) return log("Post not found ❌");

      if (post['user_id'] != user.id) {
        return log("Cannot delete someone else's post ❌");
      }

      await supabase.from('posts').delete().eq('id', postId);
      log("Post deleted ✅");

      // Optional: delete related likes, comments, saves
      await supabase.from('likes').delete().eq('post_id', postId);
      await supabase.from('comments').delete().eq('post_id', postId);
      await supabase.from('saves').delete().eq('post_id', postId);

      log("Related likes/comments/saves deleted ✅");
    } catch (e) {
      log("Error deleting post ❌: $e");
    }
  }
  // SEND REQUEST
  Future<void> sendFriendRequest(String receiverId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('friend_requests').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  // 🔹 GET POSTS BY USER
  Future<List<Map<String, dynamic>>> getPostsByUser(String userId) async {
    try {
      final data = await supabase
          .from('posts')
          .select('*, users(name, avatar_url, profile_pic)') // include user data
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log("Error fetching posts by user ❌: $e");
      return [];
    }
  }

// CHECK IF FRIENDS
  Future<bool> areFriends(String otherUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final res = await supabase
        .from('friends')
        .select()
        .or(
      'and(user1_id.eq.${user.id},user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.${user.id})',
    )
        .maybeSingle();

    return res != null;
  }

  // SAVES
  Future<void> savePost(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('saves').insert({'post_id': postId, 'user_id': user.id});
  }

  Future<void> unsavePost(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('saves').delete().eq('post_id', postId).eq('user_id', user.id);
  }

  Future<bool> isSaved(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final res = await supabase.from('saves').select().eq('post_id', postId).eq('user_id', user.id).maybeSingle();
    return res != null;
  }

  // UPDATE PROFILE PICTURE
  Future<void> updateProfilePicture(String avatarUrl) async {
    final user = supabase.auth.currentUser;
    if (user == null) return log("User not logged in");

    try {
      await supabase.from('users').update({
        'profile_pic': avatarUrl,
        'avatar_url': avatarUrl, // Update both for consistency
      }).eq('id', user.id);
      log("Profile picture updated ✅");
    } catch (e) {
      log("Error updating profile picture ❌: $e");
    }
  }

  // GET ALL FRAMES
  Future<List<Map<String, dynamic>>> getFrames() async {
    try {
      final res = await supabase.from('frames').select().order('min_level', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      log("Error fetching frames ❌: $e");
      return [];
    }
  }

  // UPDATE SELECTED FRAME
  Future<void> updateSelectedFrame(String frameUrl) async {
    final user = supabase.auth.currentUser;
    if (user == null) return log("User not logged in");
    try {
      await supabase.from('users').update({'profile_frame': frameUrl}).eq('id', user.id);
      log("Profile frame updated ✅");
    } catch (e) {
      log("Error updating profile frame ❌: $e");
    }
  }
}