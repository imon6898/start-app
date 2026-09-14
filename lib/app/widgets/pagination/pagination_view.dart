import 'package:flutter_starter/app/core/helpers/pagination_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../utils/constants/app_colors.dart';
import '../../utils/responsive_utils.dart';

/// Pagination view that supports both ListView and GridView
class PaginationView<T> extends StatelessWidget {
  final PaginationHelper<T> helper;
  final Widget Function(T item) itemBuilder;
  final bool isGrid;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget Function()? skeletonBuilder;
  final int skeletonCount;
  final ScrollPhysics? physics;
  final Future<void> Function()? onRefresh;

  const PaginationView({
    super.key,
    required this.helper,
    required this.itemBuilder,
    this.isGrid = false,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.childAspectRatio = 0.7,
    this.padding,
    this.emptyWidget,
    this.loadingWidget,
    this.skeletonBuilder,
    this.skeletonCount = 6,
    this.physics,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (helper.isLoading.value && helper.items.isEmpty) {
        if (skeletonBuilder != null) {
          return _buildSkeletonLoading();
        }
        return loadingWidget ??
            const Center(child: CircularProgressIndicator());
      }

      if (helper.items.isEmpty) {
        return RefreshIndicator(
          onRefresh: onRefresh ?? () => helper.load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child:
                    emptyWidget ?? const Center(child: Text('No Data Found')),
              ),
            ],
          ),
        );
      }

      return LazyLoadScrollView(
        isLoading: helper.isLoadingMore.value,
        onEndOfPage: helper.loadMore,
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () => helper.load(refresh: true),
          child: isGrid ? _buildGridView() : _buildListView(),
        ),
      );
    });
  }

  Widget _buildSkeletonLoading() {
    return Skeletonizer(
      enabled: true,
      child: isGrid
          ? GridView.builder(
              itemCount: skeletonCount,
              padding:
                  padding ??
                  EdgeInsets.symmetric(vertical: R.h(8), horizontal: R.h(12)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) => skeletonBuilder!(),
            )
          : ListView.separated(
              itemCount: skeletonCount,
              padding: padding ?? EdgeInsets.symmetric(vertical: R.h(6)),
              separatorBuilder: (_, _) => SizedBox(height: R.h(2)),
              itemBuilder: (context, index) => skeletonBuilder!(),
            ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      itemCount: helper.items.length + (helper.isLoadingMore.value ? 1 : 0),
      padding: padding ?? EdgeInsets.symmetric(vertical: R.h(6)),
      separatorBuilder: (_, _) =>
          Container(color: CustomColors.BGColor(), height: R.h(6)),
      physics: physics,
      //separatorBuilder: (_, __) => SizedBox(height: 2.h),
      itemBuilder: (context, index) {
        if (index == helper.items.length) {
          return _buildLoadingMoreIndicator();
        }
        return itemBuilder(helper.items[index]);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      itemCount: helper.items.length + (helper.isLoadingMore.value ? 1 : 0),
      padding:
          padding ??
          EdgeInsets.symmetric(vertical: R.h(8), horizontal: R.h(12)),
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        if (index == helper.items.length) {
          return _buildLoadingMoreIndicator();
        }
        return itemBuilder(helper.items[index]);
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.h(8)),
        child: SizedBox(
          width: R.w(24),
          height: R.h(24),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Pagination grid view with waterfall/masonry layout support
class PaginationGridView<T> extends StatelessWidget {
  final PaginationHelper<T> helper;
  final Widget Function(T item, int index) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget Function()? skeletonBuilder;
  final int skeletonCount;
  final ScrollPhysics? physics;

  const PaginationGridView({
    super.key,
    required this.helper,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.childAspectRatio = 0.7,
    this.padding,
    this.emptyWidget,
    this.loadingWidget,
    this.skeletonBuilder,
    this.skeletonCount = 6,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (helper.isLoading.value && helper.items.isEmpty) {
        if (skeletonBuilder != null) {
          return Skeletonizer(
            enabled: true,
            child: GridView.builder(
              itemCount: skeletonCount,
              padding:
                  padding ??
                  EdgeInsets.symmetric(vertical: R.h(8), horizontal: R.w(12)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) => skeletonBuilder!(),
            ),
          );
        }
        return loadingWidget ??
            const Center(child: CircularProgressIndicator());
      }

      if (helper.items.isEmpty) {
        return RefreshIndicator(
          onRefresh: () => helper.load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child:
                    emptyWidget ?? const Center(child: Text('No Data Found')),
              ),
            ],
          ),
        );
      }

      return LazyLoadScrollView(
        isLoading: helper.isLoadingMore.value,
        onEndOfPage: helper.loadMore,
        child: RefreshIndicator(
          onRefresh: () => helper.load(refresh: true),
          child: GridView.builder(
            itemCount: helper.items.length,
            padding:
                padding ??
                EdgeInsets.symmetric(vertical: R.h(8), horizontal: R.w(12)),
            physics: physics,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              return itemBuilder(helper.items[index], index);
            },
          ),
        ),
      );
    });
  }
}
