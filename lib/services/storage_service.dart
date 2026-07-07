import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Supabase Storage wrapper para sa appliance photo uploads.
///
/// Ginamit natin ang Supabase Storage (hindi Firebase Storage) dahil
/// kailangan na ng Blaze (paid) plan ang Firebase Storage para sa
/// bagong projects, habang libre talaga ang Supabase (1GB storage +
/// 2GB bandwidth/month, walang kailangang card).
///
/// Mahalaga: gumagamit tayo ng Uint8List (raw bytes) sa buong file na
/// 'to, hindi dart:io File — dahil hindi gumagana ang dart:io sa
/// Flutter Web (kung saan tumatakbo ang Admin Dashboard via Chrome).
/// Si XFile.readAsBytes() (mula sa image_picker) ay gumagana sa lahat
/// ng platforms (web, Android, iOS), kaya dun na lang tayo babatay.
class StorageService {
  static const String _supabaseUrl = 'https://qvovruwmkfnyifhkhiqt.supabase.co';

  // Publishable key (bagong tawag sa "anon/public" key) — safe ilagay
  // sa client app, hindi 'to ang secret key.
  static const String _anonKey = 'sb_publishable_FRcinSQeFPRZqmozQjR02A_8vIE04ZG';

  static const String _bucket = 'repair-photos';

  /// Nag-uupload ng photo bytes sa Supabase Storage, ibinabalik ang
  /// public URL nito (na isasave natin sa Firestore).
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String trackingId,
  }) async {
    final fileName =
        '${trackingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final uploadUrl =
        Uri.parse('$_supabaseUrl/storage/v1/object/$_bucket/$fileName');

    final response = await http.post(
      uploadUrl,
      headers: {
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Hindi na-upload ang photo (${response.statusCode}). '
        'I-check ang Supabase credentials/bucket mo: ${response.body}',
      );
    }

    // Public URL pattern — gagana lang 'to kung "Public bucket" ang
    // setting ng bucket mo sa Supabase Storage.
    return '$_supabaseUrl/storage/v1/object/public/$_bucket/$fileName';
  }
}