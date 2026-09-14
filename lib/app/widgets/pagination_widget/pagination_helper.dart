import 'dart:developer';

import 'package:get/get.dart';
import 'package:calldone/app/core/models/pagination_response.dart';

/// Result wrapper for pagination that includes metadata
class PaginationResult<T> {
  final List<T> items;
  final int? totalPages;
  final int? currentPage;
  final int? lastPage;

  PaginationResult({
    required this.items,
    this.totalPages,
    this.currentPage,
    this.lastPage,
  });
}

class PaginationHelper<T> {
  final items = <T>[].obs;

  int page = 1;
  int limit = 20;
  bool hasMore = true;
  int? totalPages;

  final isLoading = true.obs;
  final isLoadingMore = false.obs;

  /// Inject your fetch function from controller
  /// Can return either List<T>, PaginationResult<T>, or PaginationResponse<T>
  late Future<dynamic> Function(int page, int limit) fetchFunction;

  void setup(Future<dynamic> Function(int page, int limit) fetcher) {
    fetchFunction = fetcher;
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      page = 1;
      hasMore = true;
      totalPages = null;
      items.clear();
      isLoading.value = true;
    }

    // Don't fetch if we already know there are no more pages
    if (!hasMore && !refresh) {
      isLoading.value = false;
      isLoadingMore.value = false;
      return;
    }

    try {
      final result = await fetchFunction(page, limit);

      log('PaginationHelper: result type = ${result.runtimeType}, T = $T');
      log('PaginationHelper: result is PaginationResponse<T> = ${result is PaginationResponse<T>}');
      if (result is PaginationResponse) {
        log('PaginationHelper: result IS PaginationResponse (untyped), items count = ${result.items.length}');
      }

      List<T> data;

      if (result is PaginationResponse<T>) {
        // Handle PaginationResponse<T>
        data = result.items;
        totalPages = result.totalPages;

        // Determine hasMore based on API metadata
        if (result.totalPages != null) {
          hasMore = page < result.totalPages!;
        } else if (result.lastPage != null) {
          hasMore = page < result.lastPage!;
        } else {
          // Fallback to checking data length
          hasMore = data.length == limit;
        }
      } else if (result is PaginationResult<T>) {
        // Use pagination metadata from API
        data = result.items;
        totalPages = result.totalPages;

        // Determine hasMore based on API metadata
        if (result.totalPages != null) {
          hasMore = page < result.totalPages!;
        } else if (result.lastPage != null) {
          hasMore = page < result.lastPage!;
        } else {
          // Fallback to checking data length
          hasMore = data.length == limit;
        }
      } else if (result is List<T>) {
        // Legacy support: just a list
        data = result;
        hasMore = data.length == limit;
      } else {
        data = [];
        hasMore = false;
      }

      log('PaginationHelper: data.length = ${data.length}, hasMore = $hasMore');
      items.addAll(data);
      log('PaginationHelper: items.length after addAll = ${items.length}');

      if (hasMore) page++;
    } catch (e, stackTrace) {
      log("Pagination error: $e");
      log("Pagination stackTrace: $stackTrace");
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value) return;

    isLoadingMore.value = true;
    await load();
  }
}
