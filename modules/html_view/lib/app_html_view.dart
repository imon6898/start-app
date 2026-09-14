import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';

/// Static helpers that render HTML strings as Flutter widgets, plus HTML text utilities.
class AppHtmlView {
  /// Optional hook to open web links in an in-app WebView; falls back to the external browser.
  static void Function(String url)? webViewOpener;

  /// Opens tel/mailto/sms externally, web URLs via [webViewOpener] or the external browser.
  static Future<void> _handleLinkTap(String? url, {bool inWebView = true}) async {
    if (url == null || url.isEmpty) return;

    if (url.startsWith('tel:') ||
        url.startsWith('mailto:') ||
        url.startsWith('sms:')) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return;
    }

    final opener = webViewOpener;
    if (inWebView && opener != null) {
      opener(url);
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// True when the app is in dark mode (ThemeController, else platform).
  static bool get _isDarkMode {
    try {
      return Get.find<ThemeController>().isDarkMode;
    } catch (_) {
      return Get.isPlatformDarkMode;
    }
  }

  /// Strips hardcoded inline colors so content follows the app theme.
  static String _processColorsForTheme(String htmlText) {
    if (!_isDarkMode) {
      // Light mode: only drop background colors, keep author text colors.
      return htmlText
          .replaceAll(RegExp(r'background-color:\s*rgb\([^)]+\);?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'background-color:\s*#[a-fA-F0-9]{3,8};?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'background-color:\s*white;?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'style="\s*"', caseSensitive: false), '');
    }

    String result = htmlText;

    // Dark mode: drop backgrounds so the theme background shows through.
    result = result
        .replaceAll(RegExp(r'background-color:\s*rgb\s*\(\s*255\s*,\s*255\s*,\s*255\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'background-color:\s*#fff(?:fff)?;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'background-color:\s*white;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'background-color:\s*rgb\([^)]+\);?\s*', caseSensitive: false), '');

    // Dark mode: drop dark text colors so the theme text color wins.
    result = result
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\s*\(\s*0\s*,\s*0\s*,\s*0\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\s*\(\s*\d{1,2}\s*,\s*\d{1,2}\s*,\s*\d{1,2}\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\s*\(\s*7[0-9]\s*,\s*7[0-9]\s*,\s*7[0-9]\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*#000(?:000)?;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*black;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\([^)]+\);?\s*', caseSensitive: false), '');

    return result.replaceAll(RegExp(r'style="\s*"', caseSensitive: false), '');
  }

  /// Basic HTML renderer with theme-aware colors and tappable links.
  static html.Html applyHtml(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    int? maxLine,
    TextOverflow? textOverflow,
    Alignment alignment = Alignment.centerLeft,
    bool openLinksInWebView = true,
  }) {
    final unescape = HtmlUnescape();
    final decodedText = unescape.convert(
      _processColorsForTheme(text).replaceAll('\r\n', '').replaceAll('<br>', ''),
    );

    return html.Html(
      data: decodedText,
      style: {
        "*": html.Style(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: html.FontSize(style.fontSize ?? 16.0),
          color: style.color,
          lineHeight: html.LineHeight(style.height ?? 1.5),
          maxLines: maxLine ?? 100000,
          textAlign: textAlign,
          textOverflow: textOverflow ?? TextOverflow.ellipsis,
        ),
        "a": html.Style(
          color: Colors.blue,
          textDecoration: TextDecoration.underline,
        ),
        "img": html.Style(
          display: html.Display.block,
          width: html.Width(Get.width * 0.9),
          padding: html.HtmlPaddings.only(right: 12),
          alignment: alignment,
        ),
      },
      onLinkTap: (url, attributes, element) =>
          _handleLinkTap(url, inWebView: openLinksInWebView),
    );
  }

  /// Renders HTML with caller-supplied style overrides and link callback.
  static html.Html applyCustomHtml(
    BuildContext context, {
    required String text,
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
    Map<String, html.Style>? customStyles,
    void Function(String? url)? onLinkTap,
  }) {
    final decodedText = HtmlUnescape().convert(text);

    final styles = <String, html.Style>{
      "*": html.Style(
        fontFamily: style.fontFamily ?? GoogleFonts.inter().fontFamily,
        fontSize: html.FontSize(style.fontSize ?? 16.0),
        color: style.color,
        lineHeight: html.LineHeight(style.height ?? 1.5),
        textAlign: textAlign,
      ),
    };
    if (customStyles != null) styles.addAll(customStyles);

    return html.Html(
      data: decodedText,
      style: styles,
      onLinkTap: (url, attributes, element) => onLinkTap?.call(url),
    );
  }

  /// Rich renderer: chat-style markdown, auto-linkify, headings, lists, code, quotes.
  static html.Html applyHtmlWithLinkify(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    int? maxLine,
    TextOverflow? textOverflow,
    Alignment alignment = Alignment.centerLeft,
    bool openInWebView = true,
    Color? linkColor,
    EdgeInsets? padding,
  }) {
    final unescape = HtmlUnescape();
    final baseSize = style.fontSize ?? 16.0;

    // Normalize breaks -> decode entities -> markdown -> linkify.
    String processedText = text
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll('\n', '<br>');
    processedText = unescape.convert(processedText);
    processedText = parseWhatsAppMarkdown(processedText);
    processedText = linkifyText(processedText);

    final effectiveLinkColor = linkColor ?? Colors.blue;

    return html.Html(
      data: processedText,
      shrinkWrap: true,
      style: {
        "html": html.Style(
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        "body": html.Style(
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        "*": html.Style(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: html.FontSize(baseSize),
          color: style.color,
          lineHeight: html.LineHeight(style.height ?? 1.5),
          maxLines: maxLine ?? 100000,
          textAlign: textAlign,
          textOverflow: textOverflow ?? TextOverflow.ellipsis,
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        "p": html.Style(
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.only(bottom: 8),
          display: html.Display.block,
        ),
        "div": html.Style(
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        "span": html.Style(
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        "h1": html.Style(
          fontSize: html.FontSize(baseSize * 1.5),
          fontWeight: FontWeight.bold,
          margin: html.Margins.only(top: 12, bottom: 8),
          padding: html.HtmlPaddings.zero,
        ),
        "h2": html.Style(
          fontSize: html.FontSize(baseSize * 1.3),
          fontWeight: FontWeight.bold,
          margin: html.Margins.only(top: 10, bottom: 6),
          padding: html.HtmlPaddings.zero,
        ),
        "h3": html.Style(
          fontSize: html.FontSize(baseSize * 1.15),
          fontWeight: FontWeight.w600,
          margin: html.Margins.only(top: 8, bottom: 4),
          padding: html.HtmlPaddings.zero,
        ),
        "h4": html.Style(
          fontSize: html.FontSize(baseSize * 1.1),
          fontWeight: FontWeight.w600,
          margin: html.Margins.only(top: 6, bottom: 4),
          padding: html.HtmlPaddings.zero,
        ),
        "b": html.Style(fontWeight: FontWeight.bold),
        "strong": html.Style(fontWeight: FontWeight.bold),
        "i": html.Style(fontStyle: FontStyle.italic),
        "em": html.Style(fontStyle: FontStyle.italic),
        "u": html.Style(textDecoration: TextDecoration.underline),
        "s": html.Style(textDecoration: TextDecoration.lineThrough),
        "del": html.Style(textDecoration: TextDecoration.lineThrough),
        "strike": html.Style(textDecoration: TextDecoration.lineThrough),
        "ol": html.Style(
          padding: html.HtmlPaddings.only(left: 24),
          margin: html.Margins.only(top: 4, bottom: 8),
          display: html.Display.block,
          listStyleType: html.ListStyleType.decimal,
        ),
        "ul": html.Style(
          padding: html.HtmlPaddings.only(left: 24),
          margin: html.Margins.only(top: 4, bottom: 8),
          display: html.Display.block,
          listStyleType: html.ListStyleType.disc,
        ),
        "li": html.Style(
          margin: html.Margins.only(bottom: 4),
          padding: html.HtmlPaddings.zero,
          display: html.Display.listItem,
        ),
        "a": html.Style(
          color: effectiveLinkColor,
          textDecoration: TextDecoration.underline,
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        "blockquote": html.Style(
          padding: html.HtmlPaddings.only(left: 12),
          margin: html.Margins.symmetric(vertical: 8),
          fontStyle: FontStyle.italic,
          border: const Border(left: BorderSide(color: Colors.grey, width: 3)),
        ),
        "code": html.Style(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200,
          padding: html.HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
        "pre": html.Style(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200,
          padding: html.HtmlPaddings.all(8),
          margin: html.Margins.symmetric(vertical: 8),
        ),
        "img": html.Style(
          display: html.Display.block,
          width: html.Width(Get.width * 0.9),
          padding: html.HtmlPaddings.only(right: 12),
          alignment: alignment,
        ),
      },
      onLinkTap: (url, attributes, element) =>
          _handleLinkTap(url, inWebView: openInWebView),
    );
  }

  /// Style map for USFM/Scripture-style markup (verse numbers, headings, poetry, red letters).
  static Map<String, html.Style> _scriptureStyles({
    required double fontSize,
    required Color baseColor,
    required Color verseColor,
    required Color headColor,
    required Color redLetterColor,
    required Color linkColor,
    required String? font,
    required double lineHeight,
    required TextAlign textAlign,
    required EdgeInsets padding,
  }) {
    final verseNumberStyle = html.Style(
      fontSize: html.FontSize(fontSize * 0.65),
      color: verseColor,
      fontWeight: FontWeight.bold,
      verticalAlign: html.VerticalAlign.sup,
      padding: html.HtmlPaddings.only(right: 4, left: 2),
    );
    final redLetterStyle = html.Style(color: redLetterColor);

    return {
      "*": html.Style(
        fontFamily: font,
        fontSize: html.FontSize(fontSize),
        color: baseColor,
        lineHeight: html.LineHeight(lineHeight),
        textAlign: textAlign,
        padding: html.HtmlPaddings.only(
          left: padding.left,
          right: padding.right,
          top: padding.top,
          bottom: padding.bottom,
        ),
      ),
      "p": html.Style(
        margin: html.Margins.only(bottom: 12),
        padding: html.HtmlPaddings.zero,
      ),

      // Verse numbers.
      "sup": verseNumberStyle,
      "span.v": verseNumberStyle,

      // Chapter numbers.
      "span.c": html.Style(
        fontSize: html.FontSize(fontSize * 2),
        color: verseColor,
        fontWeight: FontWeight.bold,
        padding: html.HtmlPaddings.only(right: 8),
      ),

      // Headings.
      "h1": html.Style(
        fontSize: html.FontSize(fontSize * 1.5),
        fontWeight: FontWeight.bold,
        color: headColor,
        margin: html.Margins.only(top: 24, bottom: 12),
      ),
      "h2": html.Style(
        fontSize: html.FontSize(fontSize * 1.3),
        fontWeight: FontWeight.bold,
        color: headColor,
        margin: html.Margins.only(top: 20, bottom: 10),
      ),
      "h3": html.Style(
        fontSize: html.FontSize(fontSize * 1.15),
        fontWeight: FontWeight.w600,
        color: headColor,
        fontStyle: FontStyle.italic,
        margin: html.Margins.only(top: 16, bottom: 8),
      ),
      "h4": html.Style(
        fontSize: html.FontSize(fontSize),
        fontWeight: FontWeight.w600,
        color: headColor.withValues(alpha: 0.8),
        margin: html.Margins.only(top: 12, bottom: 6),
      ),

      // Section titles.
      "span.s": html.Style(
        fontSize: html.FontSize(fontSize * 1.1),
        fontWeight: FontWeight.bold,
        color: headColor,
        display: html.Display.block,
        margin: html.Margins.only(top: 16, bottom: 8),
      ),
      "span.s1": html.Style(
        fontSize: html.FontSize(fontSize * 1.15),
        fontWeight: FontWeight.bold,
        color: headColor,
        display: html.Display.block,
        margin: html.Margins.only(top: 20, bottom: 10),
      ),

      // Red-letter text.
      "span.wj": redLetterStyle,
      ".wj": redLetterStyle,

      "b": html.Style(fontWeight: FontWeight.bold),
      "strong": html.Style(fontWeight: FontWeight.bold),
      "i": html.Style(fontStyle: FontStyle.italic),
      "em": html.Style(fontStyle: FontStyle.italic),

      // Poetry indentation levels.
      "span.q": html.Style(
        display: html.Display.block,
        padding: html.HtmlPaddings.only(left: 24),
        fontStyle: FontStyle.italic,
      ),
      "span.q1": html.Style(
        display: html.Display.block,
        padding: html.HtmlPaddings.only(left: 24),
      ),
      "span.q2": html.Style(
        display: html.Display.block,
        padding: html.HtmlPaddings.only(left: 48),
      ),
      "span.q3": html.Style(
        display: html.Display.block,
        padding: html.HtmlPaddings.only(left: 72),
      ),

      // Annotations.
      "span.qs": html.Style(
        fontStyle: FontStyle.italic,
        color: baseColor.withValues(alpha: 0.7),
      ),
      "span.f": html.Style(
        fontSize: html.FontSize(fontSize * 0.8),
        color: baseColor.withValues(alpha: 0.6),
        fontStyle: FontStyle.italic,
      ),
      "span.x": html.Style(
        fontSize: html.FontSize(fontSize * 0.75),
        color: verseColor.withValues(alpha: 0.8),
      ),

      "blockquote": html.Style(
        padding: html.HtmlPaddings.only(left: 16),
        margin: html.Margins.symmetric(vertical: 12),
        fontStyle: FontStyle.italic,
        backgroundColor: verseColor.withValues(alpha: 0.05),
      ),
      "img": html.Style(
        display: html.Display.block,
        width: html.Width(Get.width * 0.9),
        padding: html.HtmlPaddings.symmetric(vertical: 8),
        alignment: Alignment.center,
      ),
      "a": html.Style(
        color: linkColor,
        textDecoration: TextDecoration.underline,
      ),
      "ul": html.Style(
        padding: html.HtmlPaddings.only(left: 20),
        margin: html.Margins.only(bottom: 12),
      ),
      "ol": html.Style(
        padding: html.HtmlPaddings.only(left: 20),
        margin: html.Margins.only(bottom: 12),
      ),
      "li": html.Style(margin: html.Margins.only(bottom: 4)),

      // Divine name (LORD).
      "span.nd": html.Style(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
      ),
      // Translator additions.
      "span.add": html.Style(
        fontStyle: FontStyle.italic,
        color: baseColor.withValues(alpha: 0.8),
      ),
      "span.p": html.Style(
        display: html.Display.block,
        margin: html.Margins.only(top: 8),
      ),
    };
  }

  /// Scripture/long-form renderer with verse-number and red-letter styling.
  static html.Html applyBibleHtml(
    BuildContext context, {
    required String text,
    required double fontSize,
    Color? textColor,
    Color? verseNumberColor,
    Color? headingColor,
    Color? jesusWordsColor,
    Color? linkColor,
    String? fontFamily,
    double lineHeight = 1.8,
    TextAlign textAlign = TextAlign.left,
    EdgeInsets padding = EdgeInsets.zero,
    bool openInWebView = true,
    bool linkify = false,
  }) {
    String decodedText = HtmlUnescape().convert(text);
    if (linkify) decodedText = linkifyText(decodedText);

    final baseColor =
        textColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return html.Html(
      data: decodedText,
      style: _scriptureStyles(
        fontSize: fontSize,
        baseColor: baseColor,
        verseColor: verseNumberColor ?? Theme.of(context).primaryColor,
        headColor: headingColor ?? baseColor,
        redLetterColor: jesusWordsColor ?? Colors.red.shade700,
        linkColor: linkColor ?? Colors.blue,
        font: fontFamily ?? GoogleFonts.merriweather().fontFamily,
        lineHeight: lineHeight,
        textAlign: textAlign,
        padding: padding,
      ),
      onLinkTap: (url, attributes, element) =>
          _handleLinkTap(url, inWebView: openInWebView),
    );
  }

  /// Scripture renderer that also auto-links URLs, emails and phone numbers.
  static html.Html applyBibleHtmlWithLinkify(
    BuildContext context, {
    required String text,
    required double fontSize,
    Color? textColor,
    Color? verseNumberColor,
    Color? headingColor,
    Color? jesusWordsColor,
    Color? linkColor,
    String? fontFamily,
    double lineHeight = 1.8,
    TextAlign textAlign = TextAlign.left,
    EdgeInsets padding = EdgeInsets.zero,
    bool openInWebView = true,
  }) {
    return applyBibleHtml(
      context,
      text: text,
      fontSize: fontSize,
      textColor: textColor,
      verseNumberColor: verseNumberColor,
      headingColor: headingColor,
      jesusWordsColor: jesusWordsColor,
      linkColor: linkColor,
      fontFamily: fontFamily,
      lineHeight: lineHeight,
      textAlign: textAlign,
      padding: padding,
      openInWebView: openInWebView,
      linkify: true,
    );
  }

  /// Removes all tags/comments/entities and collapses whitespace to plain text.
  static String stripHtml(String htmlText) {
    final stripped = htmlText
        .replaceAll(RegExp(r'<[^>]*?>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return HtmlUnescape().convert(stripped);
  }

  /// Plain verse text with leading/bracketed verse numbers removed.
  static String extractVerseText(String htmlContent) {
    return stripHtml(htmlContent)
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .replaceAll(RegExp(r'^\d+\s*'), '')
        .trim();
  }

  /// Converts WhatsApp-style markdown (*bold* _italic_ ~strike~ `code` > quote, lists) to HTML.
  static String parseWhatsAppMarkdown(String text) {
    String result = text;

    // Inline formatting first, so line parsing sees plain markers only.
    result = result.replaceAllMapped(
      RegExp(r'```([^`]+)```'),
      (match) => '<code>${match.group(1)}</code>',
    );
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => '<code>${match.group(1)}</code>',
    );
    result = result.replaceAllMapped(
      RegExp(r'\*([^\*\n<>]+)\*'),
      (match) => '<b>${match.group(1)}</b>',
    );
    result = result.replaceAllMapped(
      RegExp(r'_([^_\n<>]+)_'),
      (match) => '<i>${match.group(1)}</i>',
    );
    result = result.replaceAllMapped(
      RegExp(r'~([^~\n<>]+)~'),
      (match) => '<s>${match.group(1)}</s>',
    );

    // Line-based formatting: quotes and lists.
    final lines = result.split('<br>');
    final processedLines = <String>[];
    bool inList = false;
    String listType = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      if (inList && trimmedLine.isEmpty) continue;

      // Blockquote: "> text".
      if (trimmedLine.startsWith('&gt; ') || trimmedLine.startsWith('> ')) {
        if (inList) {
          processedLines.add('</$listType>');
          inList = false;
          listType = '';
        }
        final quoteContent = trimmedLine.startsWith('&gt; ')
            ? trimmedLine.substring(5)
            : trimmedLine.substring(2);
        processedLines.add('<blockquote>$quoteContent</blockquote>');
        continue;
      }

      // Bullet list: "- item" or "* item" (not *bold*).
      if (RegExp(r'^[\-]\s+').hasMatch(trimmedLine) ||
          (trimmedLine.startsWith('* ') &&
              !RegExp(r'\*[^\*]+\*').hasMatch(trimmedLine))) {
        if (!inList || listType != 'ul') {
          if (inList) processedLines.add('</$listType>');
          processedLines.add('<ul>');
          inList = true;
          listType = 'ul';
        }
        processedLines.add(
          '<li>${trimmedLine.replaceFirst(RegExp(r'^[\*\-]\s+'), '')}</li>',
        );
        continue;
      }

      // Numbered list: "1. item".
      if (RegExp(r'^\d+\.\s+').hasMatch(trimmedLine)) {
        if (!inList || listType != 'ol') {
          if (inList) processedLines.add('</$listType>');
          processedLines.add('<ol>');
          inList = true;
          listType = 'ol';
        }
        processedLines.add(
          '<li>${trimmedLine.replaceFirst(RegExp(r'^\d+\.\s+'), '')}</li>',
        );
        continue;
      }

      // Bullet character: "• item".
      if (trimmedLine.startsWith('• ')) {
        if (!inList || listType != 'ul') {
          if (inList) processedLines.add('</$listType>');
          processedLines.add('<ul>');
          inList = true;
          listType = 'ul';
        }
        processedLines.add('<li>${trimmedLine.substring(2)}</li>');
        continue;
      }

      // Non-list content closes an open list.
      if (inList && trimmedLine.isNotEmpty) {
        processedLines.add('</$listType>');
        inList = false;
        listType = '';
      }

      if (trimmedLine.isNotEmpty) {
        processedLines.add(line);
        processedLines.add('<br>');
      } else if (!inList && processedLines.isNotEmpty) {
        processedLines.add('<br>');
      }
    }

    if (inList) processedLines.add('</$listType>');

    result = processedLines.join('');

    // Tidy breaks around block elements.
    result = result
        .replaceAll('<br><ul>', '<ul>')
        .replaceAll('</ul><br>', '</ul>')
        .replaceAll('<br><ol>', '<ol>')
        .replaceAll('</ol><br>', '</ol>')
        .replaceAll('<br><blockquote>', '<blockquote>')
        .replaceAll('</blockquote><br>', '</blockquote>')
        .replaceAll(RegExp(r'(<br>){3,}'), '<br><br>')
        .replaceAll(RegExp(r'(<br>)+$'), '');

    return result;
  }

  static final RegExp _urlPattern = RegExp(
    r'(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _phonePattern = RegExp(
    r'(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}',
  );

  /// Wraps plain URLs, emails and phone numbers in anchor tags.
  static String linkifyText(String text) {
    String result = text;

    result = result.replaceAllMapped(_urlPattern, (match) {
      final url = match.group(0)!;
      final href = url.startsWith('http://') || url.startsWith('https://')
          ? url
          : 'https://$url';
      return '<a href="$href">$url</a>';
    });

    result = result.replaceAllMapped(_emailPattern, (match) {
      final email = match.group(0)!;
      if (result.contains('href="mailto:$email"')) return email;
      return '<a href="mailto:$email">$email</a>';
    });

    result = result.replaceAllMapped(_phonePattern, (match) {
      final phone = match.group(0)!;
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (result.contains('href="tel:$cleanPhone"')) return phone;
      return '<a href="tel:$cleanPhone">$phone</a>';
    });

    return result;
  }

  /// True if the text contains at least one URL.
  static bool containsLinks(String text) => _urlPattern.hasMatch(text);

  /// All URLs found in the text.
  static List<String> extractUrls(String text) =>
      _urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
}
