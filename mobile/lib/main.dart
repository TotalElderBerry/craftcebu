import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The live CraftCebu site. Every Vercel deploy shows up in the app at once.
const homeUrl = 'https://craftcebu.vercel.app';

// CraftCebu palette (src/style.css).
const paper = Color(0xFFFAF6EE);
const ink = Color(0xFF1F1A17);
const atsuete = Color(0xFFAE3D24);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CraftCebuApp());
}

class CraftCebuApp extends StatelessWidget {
  const CraftCebuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CraftCebu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: atsuete, surface: paper),
        scaffoldBackgroundColor: paper,
      ),
      home: const ShellScreen(),
    );
  }
}

/// A full-screen web view of the CraftCebu site, plus the native pieces a
/// browser tab doesn't have: back navigation, photo picking, external links
/// and an offline screen.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late final WebViewController _controller;
  final _picker = ImagePicker();
  int _progress = 0;
  bool _offline = false;

  @override
  void initState() {
    super.initState();

    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(paper)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageStarted: (_) => setState(() => _offline = false),
          onWebResourceError: (error) {
            // Only a failed page counts as offline, not one missing image.
            if (error.isForMainFrame ?? false) setState(() => _offline = true);
          },
          onNavigationRequest: _onNavigation,
        ),
      )
      ..loadRequest(Uri.parse(homeUrl));

    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      // iPhone: swipe from the left edge to go back.
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    if (platform is AndroidWebViewController) {
      // Android's WebView ignores <input type="file"> unless the app picks
      // the files itself; the iPhone's WebView shows its own picker.
      platform.setOnShowFileSelector(_pickFiles);
      AndroidWebViewController.enableDebugging(kDebugMode);
    }
  }

  // Web pages stay in the app, including Maya's payment pages and the card
  // checks they redirect through. Other kinds of links (email, phone, wallet
  // apps) open in the app that handles them.
  Future<NavigationDecision> _onNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null || uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
      return NavigationDecision.navigate;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final images = params.mode == FileSelectorMode.openMultiple
        ? await _picker.pickMultiImage(imageQuality: 90)
        : [if (await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90) case final XFile file) file];
    return images.map((file) => Uri.file(file.path).toString()).toList();
  }

  // Android back button: go back a page, and leave the app from the first one.
  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  void _retry() {
    setState(() => _offline = false);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: paper,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          // The site pads itself for notches only when it draws under them;
          // SafeArea keeps it between the status bar and home indicator.
          body: SafeArea(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_progress < 100 && !_offline)
                  LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 2,
                    color: atsuete,
                    backgroundColor: Colors.transparent,
                  ),
                if (_offline) _OfflineView(onRetry: _retry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/splash.png', width: 72, height: 72),
              const SizedBox(height: 24),
              const Text(
                'Walay koneksyon',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: ink),
              ),
              const SizedBox(height: 8),
              const Text(
                "You're offline. Check your internet connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF6B635C), height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: atsuete,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
