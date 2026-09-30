class ShopSettings {
  final int? id;
  final String shopName;      // اسم المحل
  final String? phone;        // التليفون
  final String? address;      // العنوان
  final String? logoPath;     // مسار صورة الشعار
  final String? footerText;   // نص أسفل الفاتورة (شكراً...)
  final bool taxEnabled;      // تفعيل الضريبة
  final double taxPercent;    // نسبة الضريبة

  ShopSettings({
    this.id,
    required this.shopName,
    this.phone,
    this.address,
    this.logoPath,
    this.footerText,
    this.taxEnabled = false,
    this.taxPercent = 0,
  });

  factory ShopSettings.fromMap(Map<String, dynamic> map) {
    return ShopSettings(
      id: map['id'] as int?,
      shopName: map['shop_name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      logoPath: map['logo_path'] as String?,
      footerText: map['footer_text'] as String?,
      taxEnabled: (map['tax_enabled'] as int) == 1,
      taxPercent: (map['tax_percent'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shop_name': shopName,
      'phone': phone,
      'address': address,
      'logo_path': logoPath,
      'footer_text': footerText,
      'tax_enabled': taxEnabled ? 1 : 0,
      'tax_percent': taxPercent,
    };
  }

  ShopSettings copyWith({
    int? id,
    String? shopName,
    String? phone,
    String? address,
    String? logoPath,
    String? footerText,
    bool? taxEnabled,
    double? taxPercent,
  }) {
    return ShopSettings(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoPath: logoPath ?? this.logoPath,
      footerText: footerText ?? this.footerText,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxPercent: taxPercent ?? this.taxPercent,
    );
  }
}