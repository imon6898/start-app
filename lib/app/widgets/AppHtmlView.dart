import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:html_unescape/html_unescape.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_starter/app/themes/theme_controller.dart';
import 'package:flutter_starter/app/widgets/custom_webview.dart';

class AppHtmlView {
  /// Helper method to process inline colors based on theme
  /// In dark mode: black/dark text → white, white background → transparent with alpha
  static String _processColorsForTheme(String htmlText) {
    // Check if dark mode
    bool isDarkMode = false;
    try {
      final themeController = Get.find<ThemeController>();
      isDarkMode = themeController.isDarkMode;
    } catch (_) {
      // ThemeController not found, check platform
      isDarkMode = Get.isPlatformDarkMode;
    }

    if (!isDarkMode) {
      // In light mode, just remove background-color to use theme background
      return htmlText
          .replaceAll(RegExp(r'background-color:\s*rgb\([^)]+\);?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'background-color:\s*#[a-fA-F0-9]{3,8};?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'background-color:\s*white;?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'style="\s*"', caseSensitive: false), '');
    }

    // In dark mode, process colors
    String result = htmlText;

    // Remove white/light background colors (will use theme background)
    result = result
        .replaceAll(RegExp(r'background-color:\s*rgb\s*\(\s*255\s*,\s*255\s*,\s*255\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'background-color:\s*#fff(?:fff)?;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'background-color:\s*white;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'background-color:\s*rgb\([^)]+\);?\s*', caseSensitive: false), '');

    // Remove black/dark text colors (will use theme text color)
    // Match dark colors like rgb(0,0,0), rgb(74,74,74), etc.
    result = result
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\s*\(\s*0\s*,\s*0\s*,\s*0\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\s*\(\s*\d{1,2}\s*,\s*\d{1,2}\s*,\s*\d{1,2}\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\s*\(\s*7[0-9]\s*,\s*7[0-9]\s*,\s*7[0-9]\s*\);?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*#000(?:000)?;?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!-)color:\s*black;?\s*', caseSensitive: false), '')
        // Remove any remaining dark colors (values below 128)
        .replaceAll(RegExp(r'(?<!-)color:\s*rgb\([^)]+\);?\s*', caseSensitive: false), '');

    // Clean up empty style attributes
    result = result.replaceAll(RegExp(r'style="\s*"', caseSensitive: false), '');

    return result;
  }

  /// Basic HTML renderer with link support
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
    // Process colors based on theme (dark/light mode)
    final processedText = _processColorsForTheme(text);
    final decodedText = unescape.convert(
      processedText.replaceAll('\r\n', '').replaceAll('<br>', ''),
    );

    const linkColor = Colors.blue;

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
          color: linkColor,
          textDecoration: TextDecoration.underline,
        ),
        "img": html.Style(
          display: html.Display.block,
          width: html.Width(Get.width * 0.9),
          padding: html.HtmlPaddings.only(right: 12),
          alignment: alignment,
        ),
      },
      onLinkTap: (url, attributes, element) async {
        if (url == null || url.isEmpty) return;

        // Handle special URLs externally
        if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:')) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
          return;
        }

        // Open web URLs
        if (openLinksInWebView) {
          CustomWebView.open(url);
        } else {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  /// Enhanced Bible content renderer with verse numbers styling
  static html.Html applyBibleHtml(
    BuildContext context, {
    required String text,
    required double fontSize,
    Color? textColor,
    Color? verseNumberColor,
    Color? headingColor,
    Color? jesusWordsColor,
    String? fontFamily,
    double lineHeight = 1.8,
    TextAlign textAlign = TextAlign.left,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final unescape = HtmlUnescape();
    final decodedText = unescape.convert(text);

    final baseColor = textColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final verseColor = verseNumberColor ?? Theme.of(context).primaryColor;
    final headColor = headingColor ?? baseColor;
    final redLetterColor = jesusWordsColor ?? Colors.red.shade700;
    final font = fontFamily ?? GoogleFonts.merriweather().fontFamily;

    return html.Html(
      data: decodedText,
      style: {
        // Base text style
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

        // Paragraph styling
        "p": html.Style(
          margin: html.Margins.only(bottom: 12),
          padding: html.HtmlPaddings.zero,
        ),

        // Verse numbers (superscript style)
        "sup": html.Style(
          fontSize: html.FontSize(fontSize * 0.65),
          color: verseColor,
          fontWeight: FontWeight.bold,
          verticalAlign: html.VerticalAlign.sup,
          padding: html.HtmlPaddings.only(right: 4, left: 2),
        ),

        // Scripture API.Bible uses span.v for verse numbers
        "span.v": html.Style(
          fontSize: html.FontSize(fontSize * 0.65),
          color: verseColor,
          fontWeight: FontWeight.bold,
          verticalAlign: html.VerticalAlign.sup,
          padding: html.HtmlPaddings.only(right: 4, left: 2),
        ),

        // Chapter numbers
        "span.c": html.Style(
          fontSize: html.FontSize(fontSize * 2),
          color: verseColor,
          fontWeight: FontWeight.bold,
          padding: html.HtmlPaddings.only(right: 8),
        ),

        // Section headings
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

        // Scripture API.Bible section titles
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

        // Words of Jesus (red letter)
        "span.wj": html.Style(
          color: redLetterColor,
        ),
        ".wj": html.Style(
          color: redLetterColor,
        ),

        // Bold text
        "b": html.Style(
          fontWeight: FontWeight.bold,
        ),
        "strong": html.Style(
          fontWeight: FontWeight.bold,
        ),

        // Italic text
        "i": html.Style(
          fontStyle: FontStyle.italic,
        ),
        "em": html.Style(
          fontStyle: FontStyle.italic,
        ),

        // Poetry/verse indentation (Psalms, Proverbs, etc.)
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

        // Selah and other annotations
        "span.qs": html.Style(
          fontStyle: FontStyle.italic,
          color: baseColor.withValues(alpha: 0.7),
        ),

        // Footnotes
        "span.f": html.Style(
          fontSize: html.FontSize(fontSize * 0.8),
          color: baseColor.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
        ),

        // Cross references
        "span.x": html.Style(
          fontSize: html.FontSize(fontSize * 0.75),
          color: verseColor.withValues(alpha: 0.8),
        ),

        // Block quotes
        "blockquote": html.Style(
          padding: html.HtmlPaddings.only(left: 16),
          margin: html.Margins.symmetric(vertical: 12),
          fontStyle: FontStyle.italic,
          backgroundColor: verseColor.withValues(alpha: 0.05),
        ),

        // Images
        "img": html.Style(
          display: html.Display.block,
          width: html.Width(Get.width * 0.9),
          padding: html.HtmlPaddings.symmetric(vertical: 8),
          alignment: Alignment.center,
        ),

        // Links
        "a": html.Style(
          color: Colors.blue,
          textDecoration: TextDecoration.underline,
        ),

        // Lists
        "ul": html.Style(
          padding: html.HtmlPaddings.only(left: 20),
          margin: html.Margins.only(bottom: 12),
        ),
        "ol": html.Style(
          padding: html.HtmlPaddings.only(left: 20),
          margin: html.Margins.only(bottom: 12),
        ),
        "li": html.Style(
          margin: html.Margins.only(bottom: 4),
        ),

        // Divine name (YHWH/LORD) - using uppercase with smaller font
        "span.nd": html.Style(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),

        // Added text (translators' additions)
        "span.add": html.Style(
          fontStyle: FontStyle.italic,
          color: baseColor.withValues(alpha: 0.8),
        ),

        // Paragraph marker
        "span.p": html.Style(
          display: html.Display.block,
          margin: html.Margins.only(top: 8),
        ),
      },
      onLinkTap: (url, attributes, element) async {
        if (url == null || url.isEmpty) return;

        // Handle special URLs externally
        if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:')) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
          return;
        }

        // Open web URLs in custom WebView
        CustomWebView.open(url);
      },
    );
  }

  /// Render HTML with custom tag handlers
  static html.Html applyCustomHtml(
    BuildContext context, {
    required String text,
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
    Map<String, html.Style>? customStyles,
    void Function(String? url)? onLinkTap,
  }) {
    final unescape = HtmlUnescape();
    final decodedText = unescape.convert(text);

    final defaultStyles = {
      "*": html.Style(
        fontFamily: style.fontFamily ?? GoogleFonts.inter().fontFamily,
        fontSize: html.FontSize(style.fontSize ?? 16.0),
        color: style.color,
        lineHeight: html.LineHeight(style.height ?? 1.5),
        textAlign: textAlign,
      ),
    };

    // Merge custom styles with defaults
    if (customStyles != null) {
      defaultStyles.addAll(customStyles);
    }

    return html.Html(
      data: decodedText,
      style: defaultStyles,
      onLinkTap: (url, attributes, element) {
        if (onLinkTap != null) {
          onLinkTap(url);
        }
      },
    );
  }

  /// Simple text-only HTML stripper
  static String stripHtml(String htmlText) {
    final unescape = HtmlUnescape();

    String stripped = htmlText
        // Remove all HTML tags (including self-closing tags)
        .replaceAll(RegExp(r'<[^>]*?>', caseSensitive: false, dotAll: true), ' ')
        // Remove HTML comments
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        // Replace common HTML entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        // Replace multiple whitespace/newlines with single space
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Unescape any remaining HTML entities
    return unescape.convert(stripped);
  }

  /// Extract verse text without HTML tags
  static String extractVerseText(String htmlContent) {
    return stripHtml(htmlContent)
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .replaceAll(RegExp(r'^\d+\s*'), '')
        .trim();
  }

  /// Parse WhatsApp-style markdown formatting to HTML
  /// Supports: *bold*, _italic_, ~strikethrough~, ```monospace```, `code`, > quotes, lists
  static String parseWhatsAppMarkdown(String text) {
    String result = text;

    // Handle inline formatting first (before processing lines)

    // Monospace/code block: ```text```
    result = result.replaceAllMapped(
      RegExp(r'```([^`]+)```'),
      (match) => '<code>${match.group(1)}</code>',
    );

    // Inline code: `text`
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => '<code>${match.group(1)}</code>',
    );

    // Bold: *text* (but not ** or isolated *)
    result = result.replaceAllMapped(
      RegExp(r'\*([^\*\n<>]+)\*'),
      (match) => '<b>${match.group(1)}</b>',
    );

    // Italic: _text_
    result = result.replaceAllMapped(
      RegExp(r'_([^_\n<>]+)_'),
      (match) => '<i>${match.group(1)}</i>',
    );

    // Strikethrough: ~text~
    result = result.replaceAllMapped(
      RegExp(r'~([^~\n<>]+)~'),
      (match) => '<s>${match.group(1)}</s>',
    );

    // Split by lines to handle line-based formatting (quotes, lists)
    List<String> lines = result.split('<br>');
    List<String> processedLines = [];
    bool inList = false;
    String listType = '';

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      String trimmedLine = line.trim();

      // Skip empty lines inside lists
      if (inList && trimmedLine.isEmpty) {
        continue;
      }

      // Handle blockquote: > text
      if (trimmedLine.startsWith('&gt; ') || trimmedLine.startsWith('> ')) {
        if (inList) {
          processedLines.add('</$listType>');
          inList = false;
          listType = '';
        }
        String quoteContent = trimmedLine.startsWith('&gt; ')
            ? trimmedLine.substring(5)
            : trimmedLine.substring(2);
        processedLines.add('<blockquote>$quoteContent</blockquote>');
        continue;
      }

      // Handle bulleted list: - item (but not *bold* patterns)
      if (RegExp(r'^[\-]\s+').hasMatch(trimmedLine) ||
          (trimmedLine.startsWith('* ') && !RegExp(r'\*[^\*]+\*').hasMatch(trimmedLine))) {
        if (!inList || listType != 'ul') {
          if (inList) processedLines.add('</$listType>');
          processedLines.add('<ul>');
          inList = true;
          listType = 'ul';
        }
        String itemContent = trimmedLine.replaceFirst(RegExp(r'^[\*\-]\s+'), '');
        processedLines.add('<li>$itemContent</li>');
        continue;
      }

      // Handle numbered list: 1. item, 2. item, etc.
      if (RegExp(r'^\d+\.\s+').hasMatch(trimmedLine)) {
        if (!inList || listType != 'ol') {
          if (inList) processedLines.add('</$listType>');
          processedLines.add('<ol>');
          inList = true;
          listType = 'ol';
        }
        String itemContent = trimmedLine.replaceFirst(RegExp(r'^\d+\.\s+'), '');
        processedLines.add('<li>$itemContent</li>');
        continue;
      }

      // Handle bullet point character: • item
      if (trimmedLine.startsWith('• ')) {
        if (!inList || listType != 'ul') {
          if (inList) processedLines.add('</$listType>');
          processedLines.add('<ul>');
          inList = true;
          listType = 'ul';
        }
        String itemContent = trimmedLine.substring(2);
        processedLines.add('<li>$itemContent</li>');
        continue;
      }

      // Close list if we're no longer in list items
      if (inList && trimmedLine.isNotEmpty) {
        processedLines.add('</$listType>');
        inList = false;
        listType = '';
      }

      // Add regular line
      if (trimmedLine.isNotEmpty) {
        processedLines.add(line);
        processedLines.add('<br>'); // Add line break after regular text
      } else if (!inList && processedLines.isNotEmpty) {
        // Add empty line as <br> for paragraph spacing (but not inside lists)
        processedLines.add('<br>');
      }
    }

    // Close any open list
    if (inList) {
      processedLines.add('</$listType>');
    }

    // Join all elements
    result = processedLines.join('');

    // Clean up: remove <br> right before/after list tags and multiple <br>
    result = result.replaceAll('<br><ul>', '<ul>');
    result = result.replaceAll('</ul><br>', '</ul>');
    result = result.replaceAll('<br><ol>', '<ol>');
    result = result.replaceAll('</ol><br>', '</ol>');
    result = result.replaceAll('<br><blockquote>', '<blockquote>');
    result = result.replaceAll('</blockquote><br>', '</blockquote>');
    result = result.replaceAll(RegExp(r'(<br>){3,}'), '<br><br>');
    // Remove trailing <br>
    result = result.replaceAll(RegExp(r'(<br>)+$'), '');

    return result;
  }

  /// Linkify text - converts plain text URLs to clickable links
  /// Returns HTML string with links wrapped in anchor tags
  static String linkifyText(String text) {
    // URL regex pattern
    final urlPattern = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    // Email regex pattern
    final emailPattern = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    );

    // Phone regex pattern
    final phonePattern = RegExp(
      r'(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}',
    );

    String result = text;

    // Replace URLs with anchor tags
    result = result.replaceAllMapped(urlPattern, (match) {
      String url = match.group(0)!;
      String href = url;

      // Add https:// if no protocol
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        href = 'https://$url';
      }

      return '<a href="$href">$url</a>';
    });

    // Replace emails with mailto: links
    result = result.replaceAllMapped(emailPattern, (match) {
      String email = match.group(0)!;
      // Only if not already inside an anchor tag
      if (!result.contains('href="mailto:$email"')) {
        return '<a href="mailto:$email">$email</a>';
      }
      return email;
    });

    // Replace phone numbers with tel: links
    result = result.replaceAllMapped(phonePattern, (match) {
      String phone = match.group(0)!;
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      // Only if not already inside an anchor tag
      if (!result.contains('href="tel:$cleanPhone"')) {
        return '<a href="tel:$cleanPhone">$phone</a>';
      }
      return phone;
    });

    return result;
  }

  /// Apply HTML with linkify and open links in custom WebView
  static html.Html applyHtmlWithLinkify(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    int? maxLine,
    TextOverflow? textOverflow,
    Alignment alignment = Alignment.centerLeft,
    bool openInWebView = true,
    Color? linkColor, EdgeInsets? padding,
  })
  {
    final unescape = HtmlUnescape();

    // Step 1: Normalize line breaks - remove \r, limit consecutive \n
    String processedText = text
        .replaceAll('\r', '')                  // Remove all \r
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Max 2 consecutive line breaks
        .replaceAll('\n', '<br>');             // Convert \n to <br>

    // Step 2: Decode HTML entities (like &amp; -> &)
    processedText = unescape.convert(processedText);

    // Step 3: Apply WhatsApp-style markdown parsing
    processedText = parseWhatsAppMarkdown(processedText);

    // Step 4: Linkify URLs, emails, phones
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
          fontSize: html.FontSize(style.fontSize ?? 16.0),
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
        // Headings
        "h1": html.Style(
          fontSize: html.FontSize((style.fontSize ?? 16.0) * 1.5),
          fontWeight: FontWeight.bold,
          margin: html.Margins.only(top: 12, bottom: 8),
          padding: html.HtmlPaddings.zero,
        ),
        "h2": html.Style(
          fontSize: html.FontSize((style.fontSize ?? 16.0) * 1.3),
          fontWeight: FontWeight.bold,
          margin: html.Margins.only(top: 10, bottom: 6),
          padding: html.HtmlPaddings.zero,
        ),
        "h3": html.Style(
          fontSize: html.FontSize((style.fontSize ?? 16.0) * 1.15),
          fontWeight: FontWeight.w600,
          margin: html.Margins.only(top: 8, bottom: 4),
          padding: html.HtmlPaddings.zero,
        ),
        "h4": html.Style(
          fontSize: html.FontSize((style.fontSize ?? 16.0) * 1.1),
          fontWeight: FontWeight.w600,
          margin: html.Margins.only(top: 6, bottom: 4),
          padding: html.HtmlPaddings.zero,
        ),
        // Bold text
        "b": html.Style(
          fontWeight: FontWeight.bold,
        ),
        "strong": html.Style(
          fontWeight: FontWeight.bold,
        ),
        // Italic text
        "i": html.Style(
          fontStyle: FontStyle.italic,
        ),
        "em": html.Style(
          fontStyle: FontStyle.italic,
        ),
        // Underline
        "u": html.Style(
          textDecoration: TextDecoration.underline,
        ),
        // Strikethrough
        "s": html.Style(
          textDecoration: TextDecoration.lineThrough,
        ),
        "del": html.Style(
          textDecoration: TextDecoration.lineThrough,
        ),
        "strike": html.Style(
          textDecoration: TextDecoration.lineThrough,
        ),
        // Ordered list (numbered)
        "ol": html.Style(
          padding: html.HtmlPaddings.only(left: 24),
          margin: html.Margins.only(top: 4, bottom: 8),
          display: html.Display.block,
          listStyleType: html.ListStyleType.decimal,
        ),
        // Unordered list (bullet)
        "ul": html.Style(
          padding: html.HtmlPaddings.only(left: 24),
          margin: html.Margins.only(top: 4, bottom: 8),
          display: html.Display.block,
          listStyleType: html.ListStyleType.disc,
        ),
        // List item
        "li": html.Style(
          margin: html.Margins.only(bottom: 4),
          padding: html.HtmlPaddings.zero,
          display: html.Display.listItem,
        ),
        // Links
        "a": html.Style(
          color: effectiveLinkColor,
          textDecoration: TextDecoration.underline,
          padding: html.HtmlPaddings.zero,
          margin: html.Margins.zero,
        ),
        // Block quote
        "blockquote": html.Style(
          padding: html.HtmlPaddings.only(left: 12),
          margin: html.Margins.symmetric(vertical: 8),
          fontStyle: FontStyle.italic,
          border: const Border(left: BorderSide(color: Colors.grey, width: 3)),
        ),
        // Code
        "code": html.Style(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200,
          padding: html.HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
        // Pre-formatted text
        "pre": html.Style(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200,
          padding: html.HtmlPaddings.all(8),
          margin: html.Margins.symmetric(vertical: 8),
        ),
        // Images
        "img": html.Style(
          display: html.Display.block,
          width: html.Width(Get.width * 0.9),
          padding: html.HtmlPaddings.only(right: 12),
          alignment: alignment,
        ),
      },
      onLinkTap: (url, attributes, element) async {
        if (url == null || url.isEmpty) return;

        // Handle special URLs externally
        if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:')) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
          return;
        }

        // Open web URLs
        if (openInWebView) {
          // Open in custom WebView
          CustomWebView.open(url);
        } else {
          // Open in external browser
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  /// Apply Bible HTML with linkify and WebView support
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
  })
  {
    final unescape = HtmlUnescape();

    // First decode, then linkify
    String decodedText = unescape.convert(text);
    decodedText = linkifyText(decodedText);

    final baseColor = textColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final verseColor = verseNumberColor ?? Theme.of(context).primaryColor;
    final headColor = headingColor ?? baseColor;
    final redLetterColor = jesusWordsColor ?? Colors.red.shade700;
    final effectiveLinkColor = linkColor ?? Colors.blue;
    final font = fontFamily ?? GoogleFonts.merriweather().fontFamily;

    return html.Html(
      data: decodedText,
      style: {
        // Base text style
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

        // Paragraph styling
        "p": html.Style(
          margin: html.Margins.only(bottom: 12),
          padding: html.HtmlPaddings.zero,
        ),

        // Verse numbers (superscript style)
        "sup": html.Style(
          fontSize: html.FontSize(fontSize * 0.65),
          color: verseColor,
          fontWeight: FontWeight.bold,
          verticalAlign: html.VerticalAlign.sup,
          padding: html.HtmlPaddings.only(right: 4, left: 2),
        ),

        // Scripture API.Bible uses span.v for verse numbers
        "span.v": html.Style(
          fontSize: html.FontSize(fontSize * 0.65),
          color: verseColor,
          fontWeight: FontWeight.bold,
          verticalAlign: html.VerticalAlign.sup,
          padding: html.HtmlPaddings.only(right: 4, left: 2),
        ),

        // Chapter numbers
        "span.c": html.Style(
          fontSize: html.FontSize(fontSize * 2),
          color: verseColor,
          fontWeight: FontWeight.bold,
          padding: html.HtmlPaddings.only(right: 8),
        ),

        // Section headings
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

        // Scripture API.Bible section titles
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

        // Words of Jesus (red letter)
        "span.wj": html.Style(
          color: redLetterColor,
        ),
        ".wj": html.Style(
          color: redLetterColor,
        ),

        // Bold text
        "b": html.Style(
          fontWeight: FontWeight.bold,
        ),
        "strong": html.Style(
          fontWeight: FontWeight.bold,
        ),

        // Italic text
        "i": html.Style(
          fontStyle: FontStyle.italic,
        ),
        "em": html.Style(
          fontStyle: FontStyle.italic,
        ),

        // Poetry/verse indentation (Psalms, Proverbs, etc.)
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

        // Selah and other annotations
        "span.qs": html.Style(
          fontStyle: FontStyle.italic,
          color: baseColor.withValues(alpha: 0.7),
        ),

        // Footnotes
        "span.f": html.Style(
          fontSize: html.FontSize(fontSize * 0.8),
          color: baseColor.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
        ),

        // Cross references
        "span.x": html.Style(
          fontSize: html.FontSize(fontSize * 0.75),
          color: verseColor.withValues(alpha: 0.8),
        ),

        // Block quotes
        "blockquote": html.Style(
          padding: html.HtmlPaddings.only(left: 16),
          margin: html.Margins.symmetric(vertical: 12),
          fontStyle: FontStyle.italic,
          backgroundColor: verseColor.withValues(alpha: 0.05),
        ),

        // Images
        "img": html.Style(
          display: html.Display.block,
          width: html.Width(Get.width * 0.9),
          padding: html.HtmlPaddings.symmetric(vertical: 8),
          alignment: Alignment.center,
        ),

        // Links
        "a": html.Style(
          color: effectiveLinkColor,
          textDecoration: TextDecoration.underline,
        ),

        // Lists
        "ul": html.Style(
          padding: html.HtmlPaddings.only(left: 20),
          margin: html.Margins.only(bottom: 12),
        ),
        "ol": html.Style(
          padding: html.HtmlPaddings.only(left: 20),
          margin: html.Margins.only(bottom: 12),
        ),
        "li": html.Style(
          margin: html.Margins.only(bottom: 4),
        ),

        // Divine name (YHWH/LORD)
        "span.nd": html.Style(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),

        // Added text (translators' additions)
        "span.add": html.Style(
          fontStyle: FontStyle.italic,
          color: baseColor.withValues(alpha: 0.8),
        ),

        // Paragraph marker
        "span.p": html.Style(
          display: html.Display.block,
          margin: html.Margins.only(top: 8),
        ),
      },
      onLinkTap: (url, attributes, element) async {
        if (url == null || url.isEmpty) return;

        // Handle special URLs externally
        if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:')) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
          return;
        }

        // Open web URLs
        if (openInWebView) {
          CustomWebView.open(url);
        } else {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  /// Check if a string contains any URLs
  static bool containsLinks(String text) {
    final urlPattern = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(text);
  }

  /// Extract all URLs from text
  static List<String> extractUrls(String text) {
    final urlPattern = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    return urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }
}