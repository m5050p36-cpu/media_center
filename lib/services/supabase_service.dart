import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ══════ Banners ══════
  Future<List<BannerModel>> fetchActiveBanners() async {
    final data = await client
        .from('banners')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return (data as List).map((e) => BannerModel.fromMap(e)).toList();
  }

  Future<void> addBanner(BannerModel banner) async {
    await client.from('banners').insert(banner.toMap());
  }

  Future<void> updateBanner(String id, Map<String, dynamic> updates) async {
    await client.from('banners').update(updates).eq('id', id);
  }

  Future<void> deleteBanner(String id) async {
    await client.from('banners').delete().eq('id', id);
  }
}
