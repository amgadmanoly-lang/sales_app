import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';
import '../models/shop_settings.dart';

class PdfService {
  // إنشاء ملف PDF للفاتورة
  static Future<File> generateInvoice({
    required Order order,
    required List<OrderItem> items,
    required ShopSettings settings,
    String? customerName,
    String? customerPhone,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (settings.logoPath != null && File(settings.logoPath!).existsSync()) {
      final logoBytes = await File(settings.logoPath!).readAsBytes();
      logoImage = pw.MemoryImage(logoBytes);
    }

    final font = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

    final ttf = pw.Font.ttf(font);
    final ttfBold = pw.Font.ttf(fontBold);

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttfBold,
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 70,
                          height: 70,
                          margin: const pw.EdgeInsets.only(left: 10),
                          child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                        ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              settings.shopName,
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (settings.phone != null &&
                                settings.phone!.isNotEmpty)
                              pw.Text(
                                'ت: ${settings.phone}',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            if (settings.address != null &&
                                settings.address!.isNotEmpty)
                              pw.Text(
                                settings.address!,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: order.type == OrderType.sale
                        ? PdfColors.green
                        : PdfColors.orange,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    order.type == OrderType.sale ? 'فاتورة بيع' : 'فاتورة مرتجع',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'رقم الفاتورة: ${order.orderNumber}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'التاريخ: ${_formatDate(order.createdAt)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),

          if ((customerName != null && customerName.isNotEmpty) ||
              (customerPhone != null && customerPhone.isNotEmpty)) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'بيانات العميل:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (customerName != null && customerName.isNotEmpty)
                    pw.Text(
                      'الاسم: $customerName',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  if (customerPhone != null && customerPhone.isNotEmpty)
                    pw.Text(
                      'الهاتف: $customerPhone',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                ),
                children: [
                  _headerCell('#'),
                  _headerCell('المنتج'),
                  _headerCell('الباركود'),
                  _headerCell('السعر'),
                  _headerCell('الكمية'),
                  _headerCell('الإجمالي'),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final item = entry.value;
                return pw.TableRow(
                  children: [
                    _cell('$i'),
                    _cell(item.productName),
                    _cell(item.barcode),
                    _cell('${item.price.toStringAsFixed(2)} ج.م'),
                    _cell('${item.quantity}'),
                    _cell('${item.subtotal.toStringAsFixed(2)} ج.م'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Container(
            alignment: pw.Alignment.centerLeft,
            child: pw.SizedBox(
              width: 250,
              child: pw.Column(
                children: [
                  _totalRow('الإجمالي الفرعي',
                      '${subtotal.toStringAsFixed(2)} ج.م'),
                  if (order.discount > 0)
                    _totalRow(
                        'الخصم', '- ${order.discount.toStringAsFixed(2)} ج.م'),
                  pw.Divider(color: PdfColors.grey400),
                  _totalRow(
                    'الإجمالي',
                    '${order.total.toStringAsFixed(2)} ج.م',
                    isBold: true,
                    color: order.type == OrderType.sale
                        ? PdfColors.green
                        : PdfColors.orange,
                  ),
                  if (order.type == OrderType.sale) ...[
                    pw.SizedBox(height: 6),
                    _totalRow('المدفوع', '${order.paid.toStringAsFixed(2)} ج.م'),
                    _totalRow('المتبقي',
                        '${order.remaining.toStringAsFixed(2)} ج.م'),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),

          if (settings.footerText != null &&
              settings.footerText!.isNotEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                settings.footerText!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),

          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'شكراً لتعاملكم معنا',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/invoice_${order.orderNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // مشاركة الفاتورة (Share Sheet)
  static Future<void> shareInvoice({
    required Order order,
    required List<OrderItem> items,
    required ShopSettings settings,
    String? customerName,
    String? customerPhone,
  }) async {
    final file = await generateInvoice(
      order: order,
      items: items,
      settings: settings,
      customerName: customerName,
      customerPhone: customerPhone,
    );

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'فاتورة ${order.orderNumber}',
      text: 'فاتورة رقم ${order.orderNumber}\n'
          'الإجمالي: ${order.total.toStringAsFixed(2)} ج.م',
    );
  }

  // فتح واتساب على رقم العميل مباشر
  static Future<bool> sendWhatsApp({
    required String phone,
    required String orderNumber,
    required double total,
    required String shopName,
  }) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // تحويل الرقم المصري
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = '20${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 10 && cleanPhone.startsWith('1')) {
      cleanPhone = '20$cleanPhone';
    }

    final message = Uri.encodeComponent(
      'فاتورة رقم: $orderNumber\n'
      'من: $shopName\n'
      'الإجمالي: ${total.toStringAsFixed(2)} ج.م\n\n'
      'شكراً لتعاملكم معنا 🌸',
    );

    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      return false;
    }
  }

  // ===== مساعدات =====

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 13 : 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBold ? 13 : 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}