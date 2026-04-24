import 'package:supabase_flutter/supabase_flutter.dart';

class LevelInfo {
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final double progress;

  LevelInfo({
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.progress,
  });
}

class GameStat {
  final String gameId;
  final int played;
  final int wins;
  final double winRate;

  GameStat({
    required this.gameId,
    required this.played,
    required this.wins,
    required this.winRate,
  });
}

class GameService {
  final SupabaseClient supabase = Supabase.instance.client;

  String? get currentUserId => supabase.auth.currentUser?.id;

  // Add game result and XP
  Future<void> addGameResult(String gameId, bool isWin, {int score = 0, String difficulty = 'medium'}) async {
    final me = currentUserId;
    if (me == null) return;

    // 1. Update game_stats
    final existingStats = await supabase
        .from('game_stats')
        .select()
        .eq('user_id', me)
        .eq('game_id', gameId)
        .maybeSingle();

    if (existingStats == null) {
      await supabase.from('game_stats').insert({
        'user_id': me,
        'game_id': gameId,
        'played_count': 1,
        'win_count': isWin ? 1 : 0,
      });
    } else {
      await supabase.from('game_stats').update({
        'played_count': (existingStats['played_count'] as int) + 1,
        'win_count': (existingStats['win_count'] as int) + (isWin ? 1 : 0),
      }).eq('user_id', me).eq('game_id', gameId);
    }

    // 2. Calculate and Add XP
    int xpEarned = 0;
    
    // Base XP for just playing
    xpEarned += 5;
    
    // Difficulty multiplier
    double multiplier = 1.0;
    switch (difficulty.toLowerCase()) {
      case 'easy': multiplier = 0.7; break;
      case 'medium': multiplier = 1.0; break;
      case 'hard': multiplier = 1.5; break;
    }

    // Win bonus
    if (isWin) {
      xpEarned += 15;
    }

    // Performance bonus (rewarding "playing well" even if lost)
    if (gameId == 'snake' || gameId == 'brickbreaker') {
      // Reward 1 XP for every 5 points
      xpEarned += (score / 5).floor();
    } else if (gameId == 'quiz') {
      // Reward 2 XP for every correct answer (assuming score is correct answers)
      xpEarned += (score * 2);
    } else if (gameId == 'tictactoe') {
      // Tic tac toe doesn't have a score, so maybe just win/loss
      if (!isWin && score > 5) xpEarned += 2; // "score" could be moves made?
    }

    int finalXp = (xpEarned * multiplier).round();

    if (finalXp > 0) {
      await supabase.from('xp_transactions').insert({
        'user_id': me,
        'action_type': 'game_$gameId',
        'xp_earned': finalXp,
        'metadata': {
          'is_win': isWin,
          'score': score,
          'difficulty': difficulty,
        }
      });
    }
  }

  // Get total XP and calculate level
  Future<LevelInfo> getUserLevelInfo() async {
    final me = currentUserId;
    if (me == null) {
      return LevelInfo(level: 1, currentXp: 0, nextLevelXp: 100, progress: 0);
    }

    final data = await supabase
        .from('xp_transactions')
        .select('xp_earned')
        .eq('user_id', me);

    int totalXp = 0;
    if (data.isNotEmpty) {
      totalXp = (data as List).fold(0, (sum, item) => sum + (item['xp_earned'] as int));
    }

    return calculateLevel(totalXp);
  }

  LevelInfo calculateLevel(int totalXp) {
    int level = 1;
    int xpInCurrentLevel = totalXp;
    int requiredXp = 100;

    while (xpInCurrentLevel >= requiredXp) {
      xpInCurrentLevel -= requiredXp;
      level++;
      requiredXp = 100 + (level - 1) * 50;
    }

    return LevelInfo(
      level: level,
      currentXp: xpInCurrentLevel,
      nextLevelXp: requiredXp,
      progress: xpInCurrentLevel / requiredXp,
    );
  }

  // Get stats for all games
  Future<List<GameStat>> getUserGameStats(String userId) async {
    final data = await supabase
        .from('game_stats')
        .select()
        .eq('user_id', userId);

    if (data == null || (data as List).isEmpty) return [];

    return (data as List).map((item) {
      final played = item['played_count'] as int;
      final wins = item['win_count'] as int;
      return GameStat(
        gameId: item['game_id'],
        played: played,
        wins: wins,
        winRate: played > 0 ? (wins / played) * 100 : 0.0,
      );
    }).toList();
  }
}
