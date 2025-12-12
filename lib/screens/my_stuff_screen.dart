// File: lib/screens/my_stuff_screen.dart
// Cross-platform My Stuff screen using file_picker + path_provider.
// Works on: web (downloads via universal_html) and mobile/desktop (saves in app documents dir).
//
// Requirements (pubspec.yaml):
//   file_picker, path_provider, pdf, universal_io, universal_html, intl, glassmorphism (GlassCard)
//
// Notes:
//  - OCR remains a stub. Replace performOcr() with your OCR integration.
//  - Created files are stored in-memory index _files; for persistence add shared_preferences or proper file indexing.
//  - This file avoids importing dart:io/dart:html directly, relying on universal_io & universal_html to be safe cross-platform.

import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:universal_io/io.dart' as uio;
import 'package:universal_html/html.dart' as html;

import '../widgets/glass_card.dart';

// Keep nav reserve consistent with other screens
const double kNavVisualHeight = 86.0;

String _fmtDate(DateTime d) => DateFormat.yMMMd().add_jm().format(d);

class StoredFile {
  final String id;
  final String name;
  final String ext;
  final Uint8List bytes;
  final int size;
  final DateTime uploadedAt;
  String? recognizedText;
  String? savedPath; // path on device (non-web)

  StoredFile({
    required this.id,
    required this.name,
    required this.ext,
    required this.bytes,
    required this.size,
    DateTime? uploadedAt,
    this.recognizedText,
    this.savedPath,
  }) : uploadedAt = uploadedAt ?? DateTime.now();
}

class MyStuffScreen extends StatefulWidget {
  const MyStuffScreen({Key? key}) : super(key: key);

  @override
  State<MyStuffScreen> createState() => _MyStuffScreenState();
}

class _MyStuffScreenState extends State<MyStuffScreen> with SingleTickerProviderStateMixin {
  final List<StoredFile> _files = [];
  final List<Uint8List> _pendingImagesForPdf = [];
  String _searchQuery = '';
  String _activeFilter = 'All';
  bool _isUploading = false;

  late final AnimationController _titlePulse;
  final List<String> _filters = ['All', 'PDF', 'Word', 'Excel', 'CSV', 'Images', 'Others'];

  @override
  void initState() {
    super.initState();
    _titlePulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _titlePulse.dispose();
    super.dispose();
  }

  // --- Helpers
  String _extractExt(String name) {
    final idx = name.lastIndexOf('.');
    if (idx == -1 || idx == name.length - 1) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  String _categoryForExt(String extLower) {
    final e = extLower.toLowerCase();
    if (e == 'pdf') return 'PDF';
    if (e == 'doc' || e == 'docx') return 'Word';
    if (e == 'xls' || e == 'xlsx') return 'Excel';
    if (e == 'csv') return 'CSV';
    if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic'].contains(e)) return 'Images';
    return 'Others';
  }

  bool _isImageExt(String ext) {
    return ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic'].contains(ext.toLowerCase());
  }

  String _mimeForExt(String ext) {
    final e = ext.toLowerCase();
    if (e == 'pdf') return 'application/pdf';
    if (e == 'png') return 'image/png';
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'csv') return 'text/csv';
    if (e == 'xls' || e == 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (e == 'doc' || e == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    return 'application/octet-stream';
  }

  List<StoredFile> get _filteredFiles {
    final q = _searchQuery.trim().toLowerCase();
    var list = _files.toList();
    if (_activeFilter != 'All') {
      list = list.where((f) => _categoryForExt(f.ext) == _activeFilter).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((f) => f.name.toLowerCase().contains(q) || (f.recognizedText ?? '').toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return list;
  }

  // --- Cross-platform pickers using FilePicker
  Future<void> _pickFilesCrossPlatform() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (result == null) {
        setState(() => _isUploading = false);
        return;
      }
      for (final pf in result.files) {
        final name = pf.name;
        final bytes = pf.bytes ?? Uint8List(0);
        final ext = _extractExt(name);
        final id = '${DateTime.now().millisecondsSinceEpoch}-${name.hashCode}';
        final stored = StoredFile(id: id, name: name, ext: ext, bytes: bytes, size: bytes.length);
        // Save to device storage on non-web platforms
        if (!kIsWeb) {
          final saved = await _saveBytesToAppDir(name, bytes);
          stored.savedPath = saved;
        }
        _files.add(stored);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload completed')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Images for PDF (pick images cross-platform)
  Future<void> _pickImagesForPdf() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.image);
      if (result == null) {
        setState(() => _isUploading = false);
        return;
      }
      for (final pf in result.files) {
        final bytes = pf.bytes;
        if (bytes != null) _pendingImagesForPdf.add(bytes);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Images added to pending PDF')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Create PDF from pending images and either download (web) or save to app dir (non-web)
  Future<void> _createPdfFromPendingImages() async {
    if (_pendingImagesForPdf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No images selected')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      final doc = pw.Document();
      for (final imgBytes in _pendingImagesForPdf) {
        try {
          final img = pw.MemoryImage(imgBytes);
          doc.addPage(pw.Page(build: (pw.Context ctx) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
        } catch (_) {
          // skip invalid image
        }
      }

      final pdfBytes = await doc.save();
      final fileName = 'notes_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // web: trigger browser download
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final a = html.document.createElement('a') as html.AnchorElement;
        a.href = url;
        a.download = fileName;
        html.document.body?.append(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(url);
        // add to internal list (in-memory)
        _files.add(StoredFile(id: '${DateTime.now().millisecondsSinceEpoch}-pdf', name: fileName, ext: 'pdf', bytes: Uint8List.fromList(pdfBytes), size: pdfBytes.length));
      } else {
        // desktop/mobile: write to app documents dir
        final saved = await _saveBytesToAppDir(fileName, Uint8List.fromList(pdfBytes));
        final stored = StoredFile(id: '${DateTime.now().millisecondsSinceEpoch}-pdf', name: fileName, ext: 'pdf', bytes: Uint8List.fromList(pdfBytes), size: pdfBytes.length, savedPath: saved);
        _files.add(stored);
      }

      _pendingImagesForPdf.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF created')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF creation failed: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Save bytes to app documents directory (non-web)
  Future<String?> _saveBytesToAppDir(String filename, Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$filename';
      final file = uio.File(path);
      await file.writeAsBytes(bytes, flush: true);
      return path;
    } catch (e) {
      // fallback: return null if unable to save
      return null;
    }
  }

  // Download/open stored file: web uses browser download, non-web opens a saved path if available
  Future<void> _downloadStoredFile(StoredFile f) async {
    if (kIsWeb) {
      try {
        final blob = html.Blob([f.bytes], _mimeForExt(f.ext));
        final url = html.Url.createObjectUrlFromBlob(blob);
        final a = html.document.createElement('a') as html.AnchorElement;
        a.href = url;
        a.download = f.name;
        html.document.body?.append(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(url);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } else {
      if (f.savedPath != null) {
        // On desktop/mobile you may open the file externally using platform-specific plugins.
        // For now we just notify location to user.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: ${f.savedPath}')));
      } else {
        // If file wasn't saved, try saving now
        final saved = await _saveBytesToAppDir(f.name, f.bytes);
        if (saved != null) {
          f.savedPath = saved;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $saved')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save file on this platform')));
        }
      }
    }
  }

  Future<void> _deleteStoredFile(StoredFile f) async {
    // delete any saved file on disk as well
    if (!kIsWeb && f.savedPath != null) {
      try {
        final file = uio.File(f.savedPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    setState(() => _files.removeWhere((x) => x.id == f.id));
  }

  // OCR stub (replace with real OCR)
  Future<String> performOcr(Uint8List imageBytes) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'OCR not implemented — integrate an OCR service or local ML kit';
  }

  Future<void> _runOcrAndSave(StoredFile file) async {
    if (!_isImageExt(file.ext)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OCR works on images only')));
      return;
    }
    setState(() => _isUploading = true);
    final text = await performOcr(file.bytes);
    setState(() {
      file.recognizedText = text;
      _isUploading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OCR (stub) complete')));
  }

  // --- UI pieces ---
  Widget _topActions(BuildContext ctx, double maxWidth) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(children: [
        ElevatedButton.icon(
          onPressed: _pickFilesCrossPlatform,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Upload'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _pickImagesForPdf,
          icon: const Icon(Icons.photo_library, size: 18),
          label: const Text('Images → PDF'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        ),
        const SizedBox(width: 12),
        if (_pendingImagesForPdf.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.photo, size: 16),
              const SizedBox(width: 8),
              Text('${_pendingImagesForPdf.length} images', style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              TextButton(onPressed: _createPdfFromPendingImages, child: const Text('Create PDF'))
            ]),
          ),
        const Spacer(),
        SizedBox(
          width: 320,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.search, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration.collapsed(hintText: 'Search my stuff...', hintStyle: TextStyle(color: Colors.white54)),
                ),
              ),
              if (_searchQuery.isNotEmpty) GestureDetector(onTap: () => setState(() => _searchQuery = ''), child: const Icon(Icons.close, size: 18)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final active = _activeFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? Colors.white10 : Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                if (f == 'PDF') const Icon(Icons.picture_as_pdf, size: 16) else if (f == 'Images') const Icon(Icons.photo, size: 16) else const SizedBox.shrink(),
                if (f == 'PDF' || f == 'Images') const SizedBox(width: 8) else const SizedBox.shrink(),
                Text(f, style: TextStyle(color: active ? Colors.cyanAccent : Colors.white)),
              ]),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFileListWidgets(double maxWidth) {
    final files = _filteredFiles;
    if (files.isEmpty) return [];
    final Map<String, List<StoredFile>> byDay = {};
    for (final f in files) {
      final dayKey = DateFormat.yMMMMd().format(f.uploadedAt);
      byDay.putIfAbsent(dayKey, () => []).add(f);
    }
    final widgets = <Widget>[];
    byDay.forEach((day, list) {
      widgets.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8), child: Text(day, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))));
      for (final f in list) widgets.add(_fileCard(f, maxWidth));
    });
    return widgets;
  }

  Widget _fileCard(StoredFile f, double maxWidth) {
    final cat = _categoryForExt(f.ext);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: GlassCard(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.white10, child: Icon(_iconForCategory(cat), size: 22, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text('${(f.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white12), child: Text(cat, style: const TextStyle(fontSize: 12))),
                    const SizedBox(width: 10),
                    Text(_fmtDate(f.uploadedAt), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              Column(children: [
                IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadStoredFile(f)),
                const SizedBox(height: 6),
                if (_isImageExt(f.ext)) IconButton(icon: const Icon(Icons.text_snippet_outlined), onPressed: () => _runOcrAndSave(f)),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteStoredFile(f)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'Word':
        return Icons.description;
      case 'Excel':
        return Icons.table_chart;
      case 'CSV':
        return Icons.grid_on;
      case 'Images':
        return Icons.photo;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _emptyState(double maxWidth) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth * 0.9),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.folder_open, size: 48),
              const SizedBox(height: 12),
              const Text("You haven't stored anything yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Upload PDFs, images, docs, spreadsheets or make a PDF from handwritten notes.", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: _pickFilesCrossPlatform, icon: const Icon(Icons.upload_file), label: const Text('Upload now')),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showFileDetails(StoredFile f) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            child: SizedBox(
              width: 720,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(f.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      ElevatedButton.icon(onPressed: () => _downloadStoredFile(f), icon: const Icon(Icons.download), label: const Text('Download')),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close), label: const Text('Close')),
                    ]),
                    const SizedBox(height: 12),
                    Text('Type: ${_categoryForExt(f.ext)}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text('Uploaded: ${_fmtDate(f.uploadedAt)}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    if (f.recognizedText != null) ...[
                      const Text('Recognized Text', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)), child: Text(f.recognizedText ?? '', style: const TextStyle(color: Colors.white70))),
                      const SizedBox(height: 12),
                    ],
                    if (_isImageExt(f.ext)) ...[
                      const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Center(child: Image.memory(f.bytes, width: 420)),
                      const SizedBox(height: 12),
                    ],
                    if (f.ext == 'pdf') const Text('PDF (download to view)', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (f.savedPath != null && !kIsWeb) ...[
                      const SizedBox(height: 12),
                      Text('Saved locally: ${f.savedPath}', style: const TextStyle(color: Colors.white54)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomReserve = kNavVisualHeight + MediaQuery.of(context).viewPadding.bottom;
    final maxWidth = MediaQuery.of(context).size.width.clamp(0.0, 1100.0);
    final files = _filteredFiles;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12), child: Row(children: [
              AnimatedBuilder(
                animation: _titlePulse,
                builder: (ctx, ch) {
                  final t = _titlePulse.value;
                  return ShaderMask(
                    shaderCallback: (rect) => LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: Text('My Stuff', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.white.withOpacity(0.06 * t), blurRadius: 6 * t)])),
                  );
                },
              ),
            ])),
          ),

          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: _topActions(context, maxWidth))),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),
          SliverToBoxAdapter(child: _filterChips()),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),

          if (files.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _emptyState(maxWidth))
          else
            SliverList(delegate: SliverChildListDelegate(_buildFileListWidgets(maxWidth))),

          SliverToBoxAdapter(child: SizedBox(height: bottomReserve + 12)),
        ],
      ),
    );
  }
}