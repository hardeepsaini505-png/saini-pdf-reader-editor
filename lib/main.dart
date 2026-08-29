import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SainiPdfApp());
}

class SainiPdfApp extends StatelessWidget {
  const SainiPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saini PDF Reader & Editor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B3D91),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class RecentPdf {
  final String name;
  final String path;
  final DateTime openedAt;

  RecentPdf({
    required this.name,
    required this.path,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'openedAt': openedAt.toIso8601String(),
      };

  factory RecentPdf.fromJson(Map<String, dynamic> json) {
    return RecentPdf(
      name: json['name'] ?? 'PDF File',
      path: json['path'] ?? '',
      openedAt: DateTime.tryParse(json['openedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class RecentStore {
  static const _key = 'saini_recent_pdfs';

  static Future<List<RecentPdf>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final list = raw
        .map((e) {
          try {
            return RecentPdf.fromJson(jsonDecode(e));
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentPdf>()
        .where((e) => File(e.path).existsSync())
        .toList();

    list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  static Future<void> add(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await load();

    list.removeWhere((e) => e.path == path);
    list.insert(
      0,
      RecentPdf(
        name: path.split(Platform.pathSeparator).last,
        path: path,
        openedAt: DateTime.now(),
      ),
    );

    final limited = list.take(20).toList();
    await prefs.setStringList(
      _key,
      limited.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<RecentPdf> recent = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final data = await RecentStore.load();
    if (!mounted) return;
    setState(() {
      recent = data;
      loading = false;
    });
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) return;

      String? path = result.files.single.path;

      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF path nahi mila.')),
        );
        return;
      }

      await RecentStore.add(path);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(
            filePath: path,
            fileName: result.files.single.name,
          ),
        ),
      );

      _loadRecent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF open nahi hui: $e')),
      );
    }
  }

  void _showToolInfo(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.construction_rounded, size: 40),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearRecent() async {
    await RecentStore.clear();
    await _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Saini PDF Reader & Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'About',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Saini PDF Reader & Editor',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Powered by Saini Info Solutions',
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickPdf,
        icon: const Icon(Icons.folder_open),
        label: const Text('Open PDF'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary,
                    cs.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Saini PDF Reader & Editor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open, Read, Search, Zoom and Share PDF Files',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cs.primary,
                    ),
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.add),
                    label: const Text('SELECT PDF'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PDF Tools',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                ToolCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Reader',
                  onTap: _pickPdf,
                ),
                ToolCard(
                  icon: Icons.edit_document,
                  title: 'Edit',
                  onTap: () => _showToolInfo(
                    'PDF Editor',
                    'Editor module ke liye next update me annotation, text aur signature tools add kiye ja sakte hain.',
                  ),
                ),
                ToolCard(
                  icon: Icons.call_merge_rounded,
                  title: 'Merge',
                  onTap: () => _showToolInfo(
                    'Merge PDF',
                    'Multiple PDFs ko merge karne wala module project me alag tool ke roop me add kiya ja sakta hai.',
                  ),
                ),
                ToolCard(
                  icon: Icons.content_cut_rounded,
                  title: 'Split',
                  onTap: () => _showToolInfo(
                    'Split PDF',
                    'PDF pages split/extract karne wala module next tool screen me add kiya ja sakta hai.',
                  ),
                ),
                ToolCard(
                  icon: Icons.image_rounded,
                  title: 'Image PDF',
                  onTap: () => _showToolInfo(
                    'Image to PDF',
                    'Gallery images ko PDF me convert karne ka module add kiya ja sakta hai.',
                  ),
                ),
                ToolCard(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF Info',
                  onTap: () => _showToolInfo(
                    'PDF Information',
                    'Kisi PDF ko open karke page navigation, zoom aur search use karein.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent PDFs',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (recent.isNotEmpty)
                  TextButton(
                    onPressed: _clearRecent,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 55),
                      SizedBox(height: 10),
                      Text('Abhi koi recent PDF nahi hai'),
                    ],
                  ),
                ),
              )
            else
              ...recent.map(
                (item) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.picture_as_pdf),
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item.path),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      if (!File(item.path).existsSync()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ye PDF file ab phone me available nahi hai.'),
                          ),
                        );
                        await _loadRecent();
                        return;
                      }

                      await RecentStore.add(item.path);
                      if (!mounted) return;

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerPage(
                            filePath: item.path,
                            fileName: item.name,
                          ),
                        ),
                      );
                      _loadRecent();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();

  int _pageNumber = 0;
  int _pageCount = 0;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sharePdf() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        text: widget.fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share error: $e')),
      );
    }
  }

  void _jumpToPageDialog() {
    final pageController = TextEditingController(
      text: _pageNumber > 0 ? _pageNumber.toString() : '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: pageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 - $_pageCount',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(pageController.text);
              if (page != null && page >= 1 && page <= _pageCount) {
                _controller.jumpToPage(page);
                Navigator.pop(context);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showSearch() {
    setState(() => _searching = true);
  }

  void _hideSearch() {
    _searchController.clear();
    _controller.clearSelection();
    setState(() => _searching = false);
  }

  void _searchNext() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    _controller.searchText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onSubmitted: (_) => _searchNext(),
                decoration: const InputDecoration(
                  hintText: 'Search in PDF...',
                  border: InputBorder.none,
                ),
              )
            : Text(
                widget.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_searching) ...[
            IconButton(
              onPressed: _searchNext,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: _hideSearch,
              icon: const Icon(Icons.close),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Search',
              onPressed: _showSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Go to page',
              onPressed: _pageCount > 0 ? _jumpToPageDialog : null,
              icon: const Icon(Icons.find_in_page),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: _sharePdf,
              icon: const Icon(Icons.share),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(
            File(widget.filePath),
            controller: _controller,
            canShowPaginationDialog: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            onDocumentLoaded: (details) {
              setState(() {
                _pageCount = details.document.pages.count;
                _pageNumber = 1;
              });
            },
            onPageChanged: (details) {
              setState(() {
                _pageNumber = details.newPageNumber;
              });
            },
            onDocumentLoadFailed: (details) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PDF load failed: ${details.error}')),
              );
            },
          ),
          if (_pageCount > 0)
            Positioned(
              bottom: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text('Page $_pageNumber / $_pageCount'),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: _pageNumber > 1
                    ? () => _controller.previousPage()
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              Text(
                _pageCount == 0 ? 'Loading...' : '$_pageNumber / $_pageCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _pageCount > 0 && _pageNumber < _pageCount
                    ? () => _controller.nextPage()
                    : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
