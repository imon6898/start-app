import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomWebView extends StatefulWidget {
  final String url;
  final String? title;
  final bool showAppBar;
  final bool enableShare;
  final bool enableOpenInBrowser;

  const CustomWebView({
    super.key,
    required this.url,
    this.title,
    this.showAppBar = true,
    this.enableShare = true,
    this.enableOpenInBrowser = true,
  });

  // Push the WebView screen via GetX.
  static void open(
    String url, {
    String? title,
    bool showAppBar = true,
    bool enableShare = true,
    bool enableOpenInBrowser = true,
  }) {
    Get.to(
      () => CustomWebView(
            url: url,
            title: title,
            showAppBar: showAppBar,
            enableShare: enableShare,
            enableOpenInBrowser: enableOpenInBrowser,
          ),
    );
  }

  @override
  State<CustomWebView> createState() => _CustomWebViewState();
}

class _CustomWebViewState extends State<CustomWebView> {
  InAppWebViewController? _webViewController;
  final RxDouble _progress = 0.0.obs;
  final RxBool _isLoading = true.obs;
  final RxString _currentTitle = ''.obs;
  final RxString _currentUrl = ''.obs;
  final RxBool _canGoBack = false.obs;
  final RxBool _canGoForward = false.obs;

  @override
  void initState() {
    super.initState();
    _currentUrl.value = widget.url;
    _currentTitle.value = widget.title ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_webViewController != null && await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: CustomColors.white(),
        appBar: widget.showAppBar ? _buildAppBar() : null,
        body: Column(
          children: [
            // Progress indicator
            Obx(() => _progress.value < 1.0
                ? LinearProgressIndicator(
                    value: _progress.value,
                    backgroundColor: CustomColors.gray(),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CustomColors.primary(),
                    ),
                    minHeight: 2,
                  )
                : const SizedBox.shrink()),

            // WebView
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.url),
                    ),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      javaScriptEnabled: true,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                      useHybridComposition: true,
                      allowsInlineMediaPlayback: true,
                      transparentBackground: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      _isLoading.value = true;
                      _currentUrl.value = url?.toString() ?? '';
                      _updateNavigationState();
                    },
                    onLoadStop: (controller, url) async {
                      _isLoading.value = false;
                      _currentUrl.value = url?.toString() ?? '';

                      // Get page title
                      final title = await controller.getTitle();
                      if (title != null && title.isNotEmpty) {
                        _currentTitle.value = title;
                      }
                      _updateNavigationState();
                    },
                    onProgressChanged: (controller, progress) {
                      _progress.value = progress / 100;
                    },
                    onReceivedError: (controller, request, error) {
                      _isLoading.value = false;
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final uri = navigationAction.request.url;
                      if (uri == null) return NavigationActionPolicy.CANCEL;

                      final url = uri.toString();

                      // Handle special URLs (tel:, mailto:, etc.)
                      if (url.startsWith('tel:') ||
                          url.startsWith('mailto:') ||
                          url.startsWith('sms:')) {
                        await launchUrl(uri);
                        return NavigationActionPolicy.CANCEL;
                      }

                      // Handle app store links
                      if (url.contains('play.google.com') ||
                          url.contains('apps.apple.com')) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                        return NavigationActionPolicy.CANCEL;
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                  ),

                  // Loading overlay
                  Obx(() => _isLoading.value
                      ? Container(
                          color: CustomColors.white().withValues(alpha: 0.7),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: CustomColors.primary(),
                            ),
                          ),
                        )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.showAppBar ? _buildBottomNavBar() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBarWidget(
      title: '',
      elevation: 0,
      backgroundColor: CustomColors.white(),
      titleWidget: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTitle.value.isNotEmpty
                    ? _currentTitle.value
                    : widget.title ?? 'Web Page',
                style: CustomTextStyles.semiBold16.copyWith(
                  color: CustomColors.black(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _getDisplayUrl(_currentUrl.value),
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.textGray(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )),
      toolbarActions: [
        if (widget.enableShare)
          IconButton(
            onPressed: _shareUrl,
            icon: Icon(
              Icons.share,
              color: CustomColors.black(),
              size: 20,
            ),
          ),
        if (widget.enableOpenInBrowser)
          IconButton(
            onPressed: _openInBrowser,
            icon: Icon(
              Icons.open_in_browser,
              color: CustomColors.black(),
              size: 20,
            ),
          ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          icon: Icon(
            Icons.more_vert,
            color: CustomColors.black(),
            size: 20,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text('Copy Link'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: CustomColors.white(),
        border: Border(
          top: BorderSide(
            color: CustomColors.stroke(),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Back button
          Obx(() => IconButton(
                onPressed: _canGoBack.value ? _goBack : null,
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _canGoBack.value
                      ? CustomColors.black()
                      : CustomColors.textGray(),
                  size: 20,
                ),
              )),

          // Forward button
          Obx(() => IconButton(
                onPressed: _canGoForward.value ? _goForward : null,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _canGoForward.value
                      ? CustomColors.black()
                      : CustomColors.textGray(),
                  size: 20,
                ),
              )),

          // Refresh button
          Obx(() => IconButton(
                onPressed: _isLoading.value ? _stopLoading : _refresh,
                icon: Icon(
                  _isLoading.value ? Icons.close : Icons.refresh,
                  color: CustomColors.black(),
                  size: 22,
                ),
              )),

          // Home button
          IconButton(
            onPressed: _goHome,
            icon: Icon(
              Icons.home_outlined,
              color: CustomColors.black(),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  Future<void> _updateNavigationState() async {
    if (_webViewController != null) {
      _canGoBack.value = await _webViewController!.canGoBack();
      _canGoForward.value = await _webViewController!.canGoForward();
    }
  }

  Future<void> _goBack() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
    }
  }

  Future<void> _goForward() async {
    if (_webViewController != null && await _webViewController!.canGoForward()) {
      await _webViewController!.goForward();
    }
  }

  Future<void> _refresh() async {
    await _webViewController?.reload();
  }

  Future<void> _stopLoading() async {
    await _webViewController?.stopLoading();
    _isLoading.value = false;
  }

  Future<void> _goHome() async {
    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(widget.url)),
    );
  }

  // share_plus 10+ API; older `Share.share(...)` was removed.
  void _shareUrl() {
    SharePlus.instance.share(
      ShareParams(text: _currentUrl.value, subject: _currentTitle.value),
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_currentUrl.value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _refresh();
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: _currentUrl.value));
        break;
    }
  }
}