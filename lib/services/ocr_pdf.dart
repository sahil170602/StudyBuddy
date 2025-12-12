/* lib/services/ocr_pdf.dart */
// Convert list of images (Uint8List) to PDF bytes and helper to call backend OCR if needed.
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:image/image.dart' as img;

class OcrPdfService {
  // Create a multi-page PDF from images; each image fills a page keeping aspect ratio
  static Future<Uint8List> imagesToPdf(List<Uint8List> imagesBytes) async {
    final pdf = pw.Document();
    for (final bytes in imagesBytes) {
      // decode to get dims and optionally downscale for size
      final image = img.decodeImage(bytes);
      if (image == null) continue;
      final pdfImage = pw.MemoryImage(img.encodeJpg(image, quality: 85));
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
      ));
    }
    return pdf.save();
  }
}
