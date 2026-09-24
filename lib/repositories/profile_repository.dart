import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<ProfileModel> getMine() async {
    final user = _db.auth.currentUser!;
    final profile = await _db.from('profiles').select().eq('id', user.id).single();
    final private = await _db
        .from('profile_private')
        .select('birth_date')
        .eq('user_id', user.id)
        .maybeSingle();

    final date = private?['birth_date'] == null
        ? null
        : DateTime.parse(private!['birth_date'] as String);
    return ProfileModel.fromMap(profile, birthDate: date);
  }

  Future<ProfileModel> getById(String id) async {
    final profile = await _db.from('profiles').select().eq('id', id).single();
    return ProfileModel.fromMap(profile);
  }

  Future<void> updateProfile({
    required String fullName,
    required String username,
    required String preferredRole,
    DateTime? birthDate,
  }) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('profiles').update({
      'full_name': fullName.trim(),
      'username': username.trim().toLowerCase(),
      'preferred_role': preferredRole,
    }).eq('id', uid);

    await _db.from('profile_private').upsert({
      'user_id': uid,
      'birth_date': birthDate?.toIso8601String().split('T').first,
    });
  }

  Future<String?> chooseAndUploadAvatar() async {
    final uid = _db.auth.currentUser!.id;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 88,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    final path = '$uid/avatar.$ext';
    final contentType = file.mimeType ?? switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await _db.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
            cacheControl: '60',
          ),
        );
    final rawUrl = _db.storage.from('avatars').getPublicUrl(path);
    final url = '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('profiles').update({'avatar_url': url}).eq('id', uid);
    return url;
  }
}
