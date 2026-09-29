class BannerModel {
  final String id;
  final String? title;
  final String imageUrl;
  final String? targetUrl;
  final bool isActive;
  final int displayOrder;

  BannerModel({
    required this.id,
    this.title,
    required this.imageUrl,
    this.targetUrl,
    required this.isActive,
    required this.displayOrder,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map) => BannerModel(
        id: map['id'] as String,
        title: map['title'] as String?,
        imageUrl: map['image_url'] as String,
        targetUrl: map['target_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        displayOrder: map['display_order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'image_url': imageUrl,
        'target_url': targetUrl,
        'is_active': isActive,
        'display_order': displayOrder,
      };
}
