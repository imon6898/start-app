import 'package:flutter/material.dart';

class PaginatedGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final Future<void> Function() onLoadMore;
  final Future<void> Function()? onRefresh;
  final bool hasMore;
  final bool isLoading;
  final String? errorMessage;
  final int crossAxisCount;
  final double childAspectRatio;

  const PaginatedGridView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    required this.hasMore,
    required this.isLoading,
    this.errorMessage,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!, style: TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRefresh, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (!isLoading && items.isEmpty) {
      return const Center(child: Text("No data found"));
    }

    Widget grid = NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (hasMore &&
            !isLoading &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 100) {
          onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (hasMore ? 1 : 0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          if (index < items.length) {
            return itemBuilder(context, items[index]);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );

    if (onRefresh != null) {
      grid = RefreshIndicator(onRefresh: onRefresh!, child: grid);
    }

    return grid;
  }
}
