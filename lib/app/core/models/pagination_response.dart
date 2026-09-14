import 'dart:convert';

/// Generic Pagination Response that supports both:
/// - Flat pagination (e.g., `current_page`, `last_page` at top-level)
/// - Nested pagination (e.g., under `"pagination": {...}`)
PaginationResponse<T> paginationResponseFromJson<T>(
  String str,
  T Function(Map<String, dynamic>) fromJsonT,
) => PaginationResponse<T>.fromJson(json.decode(str), fromJsonT);

String paginationResponseToJson<T>(
  PaginationResponse<T> data,
  Map<String, dynamic> Function(T) toJsonT,
) => json.encode(data.toJson(toJsonT));

class PaginationResponse<T> {
  final List<T> items;
  final int? currentPage;
  final int? lastPage;
  final int? totalCount;
  final int? perPage;
  final int? totalPages;

  const PaginationResponse({
    this.items = const [],
    this.currentPage,
    this.lastPage,
    this.totalCount,
    this.perPage,
    this.totalPages,
  });

  /// Factory to parse both flat and nested paginated responses
  factory PaginationResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    // Detect whether pagination meta is nested
    final paginationData =
        json['pagination'] ?? json['meta'] ?? json['data'] ?? json;

    // Handle various possible keys for item lists
    final itemsJson =
        (json['items'] ??
                json['item'] ??
                paginationData['items'] ??
                paginationData['data'] ??
                json['results'] ??
                json['data'])
            as List<dynamic>? ??
        [];

    return PaginationResponse<T>(
      items: itemsJson
          .map((x) => fromJsonT(x as Map<String, dynamic>))
          .toList(),
      currentPage: _toInt(paginationData['current_page']),
      lastPage: _toInt(paginationData['last_page']),
      totalCount: _toInt(
        paginationData['total_count'] ?? paginationData['total'],
      ),
      perPage: _toInt(paginationData['per_page']),
      totalPages: _toInt(paginationData['total_pages']),
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) => {
    'items': items.map((x) => toJsonT(x)).toList(),
    'current_page': currentPage,
    'last_page': lastPage,
    'total_count': totalCount,
    'per_page': perPage,
    'total_pages': totalPages,
  };

  PaginationResponse<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? lastPage,
    int? totalCount,
    int? perPage,
    int? totalPages,
  }) => PaginationResponse<T>(
    items: items ?? this.items,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    totalCount: totalCount ?? this.totalCount,
    perPage: perPage ?? this.perPage,
    totalPages: totalPages ?? this.totalPages,
  );

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
