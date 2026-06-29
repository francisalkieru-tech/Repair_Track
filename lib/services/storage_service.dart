import 'dart:typed_data';
import 'package:http/http.dart' as http;

class StorageService {
  static const String _supabaseUrl = 'https://qvovruwmkfnyifhkhiqt.supabase.co';

  static const String _anonKey = 'sb_publishable_FRcinSQeFPRZqmozQjR02A_8vIE04ZG';

  static const String _bucket = 'repair-photos';

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

    return '$_supabaseUrl/storage/v1/object/public/$_bucket/$fileName';
  }
}