import 'package:flutter/widgets.dart';

/// One catalogued widget. The demo builder lives on the model so the registry
/// stays a single flat list — this feature has no API layer.
@immutable
class CatalogEntry {
  final String name;
  final String group;

  /// Installed path, shown under the name so the reader can open the source.
  final String source;

  /// A gotcha worth reading before using the widget.
  final String? note;

  final WidgetBuilder demo;

  const CatalogEntry({
    required this.name,
    required this.group,
    required this.source,
    required this.demo,
    this.note,
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        group.toLowerCase().contains(q) ||
        source.toLowerCase().contains(q);
  }
}
