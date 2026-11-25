import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../theme.dart';

/// Tells the site it is inside the app (see src/lib/app/bridge.ts).
const appUserAgentSuffix = ' CraftCebuApp/1';

/// One web view of the CraftCebu site plus the native pieces a browser tab
/// doesn't have: photo picking, external links, swipe back, load progress
/// and an offline flag.
class WebHost extends ChangeNotifier {
  WebHost._(this.controller);

  final WebViewController controller;
  final _picker = ImagePicker();
  int progress = 0;
  bool offline = false;

  /// Set up, but not loaded: attach a WebBridge first, then call [load].
  static Future<WebHost> create() async {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final host = WebHost._(WebViewController.fromPlatformCreationParams(params));
    final controller = host.controller;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(paper);
    await controller.setUserAgent('${await controller.getUserAgent() ?? ''}$appUserAgentSuffix');
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (p) => host._set(progress: p),
        onPageStarted: (_) => host._set(offline: false),
        onWebResourceError: (error) {
          // Only a failed page counts as offline, not one missing image.
          if (error.isForMainFrame ?? false) host._set(offline: true);
        },
        onNavigationRequest: _onNavigation,
      ),
    );

    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      // iPhone: swipe from the left edge to go back.
      await platform.setAllowsBackForwardNavigationGestures(true);
    }
    if (platform is AndroidWebViewController) {
      // Android's WebView ignores <input type="file"> unless the app picks
      // the files itself; the iPhone's WebView shows its own picker.
      await platform.setOnShowFileSelector(host._pickFiles);
      await AndroidWebViewController.enableDebugging(kDebugMode);
    }
    return host;
  }

  Future<void> load(String url) => controller.loadRequest(Uri.parse(url));

  void retry() {
    _set(offline: false);
    controller.reload();
  }

  void _set({int? progress, bool? offline}) {
    this.progress = progress ?? this.progress;
    this.offline = offline ?? this.offline;
    notifyListeners();
  }

  // Web pages stay in the app, including Maya's payment pages and the card
  // checks they redirect through. Other kinds of links (email, phone, wallet
  // apps) open in the app that handles them.
  static Future<NavigationDecision> _onNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null || const {'http', 'https', 'about', 'data', 'blob'}.contains(uri.scheme)) {
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
}
