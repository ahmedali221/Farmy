import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' as printing;

class PdfArabicUtils {
  // Prefer WOFF2 for HTML/WebView to avoid OTS errors with some TTFs.
  static const String _assetTtfPath = 'assets/fonts/NotoSansArabic-Regular.ttf';
  static const String _assetWoff2Path =
      'assets/fonts/NotoSansArabic-Regular.woff2';

  // Returns base64 font data and mime for HTML @font-face
  static Future<(String base64, String mime)> _loadArabicFontForHtml() async {
    // 1) Try bundled WOFF2 (best for WebView)
    try {
      final w2 = await rootBundle.load(_assetWoff2Path);
      if (w2.lengthInBytes > 0) {
        final b64 = base64Encode(w2.buffer.asUint8List());
        return (b64, 'font/woff2');
      }
    } catch (_) {}

    // 2) Try bundled TTF (works on many devices, but can trigger OTS error)
    try {
      final ttf = await rootBundle.load(_assetTtfPath);
      if (ttf.lengthInBytes > 0) {
        final b64 = base64Encode(ttf.buffer.asUint8List());
        return (b64, 'font/ttf');
      }
    } catch (_) {}

    // 3) Try cached network WOFF2
    final cached = await _readCached('NotoSansArabic-Regular.woff2');
    if (cached != null && cached.isNotEmpty) {
      return (base64Encode(cached), 'font/woff2');
    }

    // 4) Download WOFF2 from Google Fonts CSS (runtime) then cache
    try {
      final tuple = await _downloadWoff2FromGoogleFonts();
      if (tuple != null) {
        final (bytes, mime, filename) = tuple;
        await _writeCached(filename, bytes);
        return (base64Encode(bytes), mime);
      }
    } catch (_) {}

    // 5) Fallback to a very small built-in CSS without custom font
    // Will rely on device shaping; Arabic may be OK on some devices
    return ('', '');
  }

  static Future<Uint8List?> _readCached(String filename) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$filename');
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  static Future<void> _writeCached(String filename, Uint8List bytes) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$filename');
      await f.create(recursive: true);
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  // Very small helper: fetch CSS, extract first woff2 URL, download it
  static Future<(Uint8List bytes, String mime, String filename)?>
  _downloadWoff2FromGoogleFonts() async {
    const cssUrl =
        'https://fonts.googleapis.com/css2?family=Noto+Sans+Arabic:wght@400&display=swap';
    try {
      final client = HttpClient();
      final cssReq = await client.getUrl(Uri.parse(cssUrl));
      cssReq.headers.add(HttpHeaders.acceptHeader, 'text/css');
      final cssRes = await cssReq.close();
      if (cssRes.statusCode != 200) return null;
      final cssText = utf8.decode(await cssRes.expand((e) => e).toList());
      final match = RegExp(r'url\((https:[^\)]+\.woff2)\)').firstMatch(cssText);
      if (match == null) return null;
      final url = match.group(1)!;
      final fontReq = await client.getUrl(Uri.parse(url));
      final fontRes = await fontReq.close();
      if (fontRes.statusCode != 200) return null;
      final bytes = Uint8List.fromList(await fontRes.expand((e) => e).toList());
      return (bytes, 'font/woff2', 'NotoSansArabic-Regular.woff2');
    } catch (_) {
      return null;
    }
  }

  // Shows system print/share dialog using HTML
  static Future<void> printArabicHtml({required String htmlBody}) async {
    final (b64, mime) = await _loadArabicFontForHtml();
    final fontSrc = b64.isEmpty
        ? ''
        : "@font-face { font-family: 'NotoArabic'; src: url(data:$mime;base64,$b64) format('woff2'); }";
    final html =
        '''
<!doctype html>
<html dir="rtl">
<head>
  <meta charset="utf-8">
  <style>
    $fontSrc
    body { font-family: ${b64.isEmpty ? 'sans-serif' : '"NotoArabic"'}; font-size: 14pt; }
    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  </style>
</head>
<body>
$htmlBody
</body>
</html>
''';
    await printing.Printing.layoutPdf(
      onLayout: (format) =>
          printing.Printing.convertHtml(format: format, html: html),
    );
  }

  // Returns PDF bytes from HTML without opening print dialog
  static Future<Uint8List> generateArabicHtmlPdf({
    required String htmlBody,
  }) async {
    final (b64, mime) = await _loadArabicFontForHtml();
    final fontSrc = b64.isEmpty
        ? ''
        : "@font-face { font-family: 'NotoArabic'; src: url(data:$mime;base64,$b64) format('woff2'); }";
    final html =
        '''
<!doctype html>
<html dir="rtl">
<head>
  <meta charset="utf-8">
  <style>
    $fontSrc
    body { font-family: ${b64.isEmpty ? 'sans-serif' : '"NotoArabic"'}; font-size: 14pt; }
    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  </style>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'self' data:; img-src data:; style-src 'unsafe-inline'" />
  <script>document.addEventListener('contextmenu', event => event.preventDefault());</script>
  <title>PDF</title>
  <base target="_blank">
  <meta name="color-scheme" content="light dark">
  <style>@page { size: A4; margin: 16mm; }</style>
</head>
<body>
$htmlBody
</body>
</html>
''';
    return await printing.Printing.convertHtml(html: html);
  }
}
