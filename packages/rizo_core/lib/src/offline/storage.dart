import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small JSON cache kept on the device, separated per signed-in user.
class KeyValueCache {
  KeyValueCache(this.namespace);

  final String namespace;

  String _k(String key) => 'rizo_cache_${namespace}_$key';

  Future<dynamic> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(key), jsonEncode(value));
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(key));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'rizo_cache_${namespace}_';
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}

/// Photos taken while offline wait here until they can be uploaded. On phones and tablets they are files in the
/// app's private folder; on the web (used only for testing) they stay in memory.
class PhotoStore {
  static final Map<String, Uint8List> _memory = {};

  static Future<String> save(String id, Uint8List bytes) async {
    if (kIsWeb) {
      _memory[id] = bytes;
      return 'mem:$id';
    }
    final dir = await _dir();
    final file = File('${dir.path}/$id.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return 'file:${file.path}';
  }

  static Future<Uint8List?> read(String ref) async {
    if (ref.startsWith('mem:')) return _memory[ref.substring(4)];
    if (ref.startsWith('file:') && !kIsWeb) {
      final file = File(ref.substring(5));
      if (await file.exists()) return file.readAsBytes();
    }
    return null;
  }

  static Future<void> delete(String ref) async {
    if (ref.startsWith('mem:')) {
      _memory.remove(ref.substring(4));
    } else if (ref.startsWith('file:') && !kIsWeb) {
      final file = File(ref.substring(5));
      if (await file.exists()) await file.delete();
    }
  }

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/rizo_queue');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
