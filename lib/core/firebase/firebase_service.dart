import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../firebase_options.dart';

class FirebaseService {
  static FirebaseApp? _app;
  static bool _initialized = false;

  static bool get isInitialized => _initialized && _app != null;

  static Future<bool> initialize() async {
    if (_initialized) {
      return isInitialized;
    }

    _initialized = true;

    try {
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _ensureAnonymousAuth();
      return true;
    } on UnsupportedError {
      return false;
    } catch (_) {
      return false;
    }
  }

  static FirebaseApp get app {
    final app = _app;
    if (app == null) {
      throw StateError('Firebase is not initialized.');
    }
    return app;
  }

  static DatabaseReference? databaseRoot() {
    if (!isInitialized) {
      return null;
    }
    return FirebaseDatabase.instanceFor(app: app).ref();
  }

  static DatabaseReference? channelReference(String channelName) {
    final root = databaseRoot();
    if (root == null) {
      return null;
    }
    return root.child('channels/${channelName.trim()}');
  }

  static Future<void> _ensureAnonymousAuth() async {
    final auth = FirebaseAuth.instanceFor(app: app);
    if (auth.currentUser != null) {
      return;
    }

    await auth.signInAnonymously();
  }
}