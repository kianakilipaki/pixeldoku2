import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  SupabaseClient? get supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // -----------------------------
  // SIGN IN ANONYMOUSLY
  // -----------------------------
  Future<User?> signInAnonymously() async {
    AppLogger.log('AuthService.signInAnonymously start');
    final client = supabase;
    if (client == null) {
      AppLogger.log('AuthService.signInAnonymously skipped offline');
      return null;
    }

    final response = await client.auth.signInAnonymously();

    AppLogger.log(
      'AuthService.signInAnonymously complete user=${response.user?.id ?? "null"}',
    );
    return response.user;
  }

  // -----------------------------
  // CURRENT USER
  // -----------------------------
  User? get currentUser => supabase?.auth.currentUser;

  // -----------------------------
  // AUTH STATE CHANGES
  // -----------------------------
  Stream<AuthState> get authStateChanges {
    return supabase?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();
  }

  // -----------------------------
  // CURRENT USER IS LOGGED IN
  // -----------------------------
  bool get isLoggedIn => currentUser != null && !currentUser!.isAnonymous;

  // -----------------------------
  // CREATE USER IF NOT EXISTS
  // -----------------------------
  Future<void> createUserIfNotExists(String userId) async {
    AppLogger.log('AuthService.createUserIfNotExists start user=$userId');
    final client = supabase;
    if (client == null) {
      AppLogger.log('AuthService.createUserIfNotExists skipped offline');
      return;
    }

    final existing = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    AppLogger.log(
      'AuthService.createUserIfNotExists exists=${existing != null}',
    );

    if (existing == null) {
      await client.from('users').insert({
        'id': userId,
        'coins': 100,
        'current_level': 1,
        StorageService.savedGameKey: {},
      });
      AppLogger.log('AuthService.createUserIfNotExists inserted user=$userId');
    }
  }

  // -----------------------------
  // GET USER DATA
  // -----------------------------
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final client = supabase;
    if (client == null) return null;

    return await client.from('users').select().eq('id', userId).single();
  }

  // -----------------------------
  // SIGN IN WITH GOOGLE
  // -----------------------------
  Future<bool> signInWithGoogle() async {
    AppLogger.log('AuthService.signInWithGoogle start');
    final client = supabase;
    if (client == null) return false;

    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  // -----------------------------
  // ENSURE CURRENT USER EXISTS
  // -----------------------------
  Future<void> ensureCurrentUserExists() async {
    final user = currentUser;
    AppLogger.log(
      'AuthService.ensureCurrentUserExists user=${user?.id ?? "null"}',
    );
    if (user == null) return;

    await createUserIfNotExists(user.id);
  }

  // -----------------------------
  // SIGN OUT
  // -----------------------------
  Future<void> signOut() async {
    AppLogger.log('AuthService.signOut start');
    final client = supabase;
    if (client == null) return;

    await client.auth.signOut();
    AppLogger.log('AuthService.signOut complete');
  }
}
