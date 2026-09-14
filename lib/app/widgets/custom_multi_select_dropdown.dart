import 'package:calldone/app/utils/constants/app_colors.dart';
import 'package:calldone/app/utils/constants/app_fonts.dart';
import 'package:calldone/app/utils/responsive_utils.dart';
import 'package:flutter/material.dart';

class CustomMultiSelectDropdown extends StatefulWidget {
  final String labelText;
  final List<String> itemList;
  final List<String> selectedItems;
  final Function(String) onItemToggle;
  final bool isRequired;
  final bool isSearchRequired;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Function(String)? onChangedSearch;
  final Function(String)? onSubmitSearch;
  final VoidCallback? onScrollEnd;
  final String? Function(List<String>?)? validator;

  const CustomMultiSelectDropdown({
    Key? key,
    required this.labelText,
    required this.itemList,
    required this.selectedItems,
    required this.onItemToggle,
    this.isRequired = false,
    this.isSearchRequired = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onChangedSearch,
    this.onSubmitSearch,
    this.onScrollEnd,
    this.validator,
  }) : super(key: key);

  @override
  State<CustomMultiSelectDropdown> createState() => _CustomMultiSelectDropdownState();
}

class _CustomMultiSelectDropdownState extends State<CustomMultiSelectDropdown> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.itemList;
  }

  @override
  void didUpdateWidget(CustomMultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update filtered items with new data from API
    if (oldWidget.itemList != widget.itemList) {
      _filteredItems = widget.itemList;
      // Rebuild overlay if it's open to show new data
      if (_isOpen && _overlayEntry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _overlayEntry?.markNeedsBuild();
        });
      }
    }
    // Also rebuild if loading state changes
    if (oldWidget.isLoading != widget.isLoading ||
        oldWidget.isLoadingMore != widget.isLoadingMore) {
      if (_isOpen && _overlayEntry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _overlayEntry?.markNeedsBuild();
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _filterItems(String query) {
    _searchQuery = query;
    // When using API search (onChangedSearch is provided), don't do local filtering
    // The API will return the filtered results
    if (widget.onChangedSearch != null) {
      _filteredItems = widget.itemList;
    } else {
      // Local filtering only when not using API search
      if (query.isEmpty) {
        _filteredItems = widget.itemList;
      } else {
        _filteredItems = widget.itemList
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    }
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    // Reset search when opening
    _searchController.clear();
    _searchQuery = '';
    _filteredItems = widget.itemList;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  /// Safe method to get render box position using context
  Offset? _getDropdownPosition() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }
    return renderBox.localToGlobal(Offset.zero);
  }

  /// Safe method to get dropdown size using context
  Size? _getDropdownSize() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  /// Calculate popup height
  double _calculatePopupHeight() {
    final itemCount = _filteredItems.length;
    final maxVisibleItems = 5;
    final visibleItems = itemCount > maxVisibleItems ? maxVisibleItems : itemCount;
    final searchHeight = widget.isSearchRequired ? 60.0 : 0.0;
    final selectedChipsHeight = widget.selectedItems.isNotEmpty ? 60.0 : 0.0;
    final loadingHeight = widget.isLoading ? 60.0 : 0.0;
    final itemsHeight = widget.isLoading ? 0.0 : (visibleItems * 44.0);
    final emptyHeight = (!widget.isLoading && _filteredItems.isEmpty) ? 50.0 : 0.0;
    return searchHeight + selectedChipsHeight + loadingHeight + itemsHeight + emptyHeight + 8;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final dropdownPosition = _getDropdownPosition();
        final dropdownSize = _getDropdownSize();
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        // If we can't get the dropdown position, use a default position
        if (dropdownPosition == null || dropdownSize == null) {
          return _createFallbackOverlay(bottomInset);
        }

        final popupHeight = _calculatePopupHeight();
        final fieldBottomY = dropdownPosition.dy + dropdownSize.height;

        // Calculate available space considering keyboard
        final availableScreenHeight = screenHeight - bottomInset;
        final spaceBelow = availableScreenHeight - fieldBottomY - 16;
        final spaceAbove = dropdownPosition.dy - 16;

        // When keyboard is open, position overlay above keyboard
        final bool keyboardIsOpen = bottomInset > 0;

        return Stack(
          children: [
            // Close on outside tap - Full screen transparent overlay
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeOverlay,
                child: Container(color: Colors.transparent),
              ),
            ),

            // When keyboard is open, show overlay just above keyboard
            if (keyboardIsOpen)
              Positioned(
                left: dropdownPosition.dx,
                right: screenWidth - dropdownPosition.dx - dropdownSize.width,
                bottom: bottomInset + 8,
                child: _dropdownMaterial(dropdownSize.width, maxHeight: spaceAbove.clamp(R.h(200), R.h(200))),
              )
            // When keyboard is closed, show below field if space available
            else if (spaceBelow >= popupHeight || spaceBelow > spaceAbove)
              Positioned(
                left: dropdownPosition.dx,
                top: fieldBottomY + R.h(4),
                child: _dropdownMaterial(dropdownSize.width),
              )
            // Show above field if more space above
            else
              Positioned(
                left: dropdownPosition.dx,
                bottom: screenHeight - dropdownPosition.dy + R.h(4),
                child: _dropdownMaterial(dropdownSize.width),
              ),
          ],
        );
      },
    );
  }

  /// Fallback overlay when position can't be determined
  Widget _createFallbackOverlay(double bottomInset) {
    final keyboardIsOpen = bottomInset > 0;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeOverlay,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: keyboardIsOpen ? null : 100,
          bottom: keyboardIsOpen ? bottomInset + 16 : null,
          child: _dropdownMaterial(null),
        ),
      ],
    );
  }

  /// Dropdown UI container
  Widget _dropdownMaterial(double? fieldWidth, {double? maxHeight}) {
    final effectiveWidth = fieldWidth ?? MediaQuery.of(context).size.width - 32;
    final popupHeight = _calculatePopupHeight();
    final effectiveMaxHeight = maxHeight ?? popupHeight.clamp(R.h(200), R.h(350));

    // Wrap in GestureDetector to prevent taps from closing the overlay
    return GestureDetector(
      onTap: () {}, // Absorb taps to prevent closing
      behavior: HitTestBehavior.opaque,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(R.r(8)),
        child: Container(
          width: effectiveWidth,
          constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
          decoration: BoxDecoration(
            color: CustomColors.white(),
            borderRadius: BorderRadius.circular(R.r(8)),
            border: Border.all(color: CustomColors.stroke()),
          ),
          child: _dropdownBody(),
        ),
      ),
    );
  }

  /// Main dropdown UI
  Widget _dropdownBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Field
        if (widget.isSearchRequired)
          Container(
            padding: EdgeInsets.all(R.w(8)),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CustomColors.stroke()),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: CustomTextStyles.regular14.copyWith(
                  color: Colors.grey,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: R.w(20),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _filterItems('');
                              _overlayEntry?.markNeedsBuild();
                              widget.onChangedSearch?.call('');
                            },
                            child: Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: R.w(18),
                            ),
                          )
                        : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: R.w(12),
                  vertical: R.h(8),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.r(8)),
                  borderSide: BorderSide(color: CustomColors.stroke()),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.r(8)),
                  borderSide: BorderSide(color: CustomColors.stroke()),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.r(8)),
                  borderSide: BorderSide(color: CustomColors.primary()),
                ),
                filled: true,
                fillColor: CustomColors.BGColor(),
                isDense: true,
              ),
              style: CustomTextStyles.regular14,
              onChanged: (value) {
                _filterItems(value);
                _overlayEntry?.markNeedsBuild();
                widget.onChangedSearch?.call(value);
              },
              onSubmitted: (value) {
                _filterItems(value);
                _overlayEntry?.markNeedsBuild();
                widget.onSubmitSearch?.call(value);
              },
            ),
          ),


        // Loading indicator
        if (widget.isLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: R.h(16)),
            child: Center(
              child: SizedBox(
                width: R.w(24),
                height: R.w(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CustomColors.primary(),
                ),
              ),
            ),
          )
        // Items List
        else
          Flexible(
            child: _filteredItems.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(R.w(16)),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No items available'
                          : 'No items found for "$_searchQuery"',
                      style: CustomTextStyles.regular14.copyWith(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollEndNotification) {
                        final metrics = scrollNotification.metrics;
                        if (metrics.pixels >= metrics.maxScrollExtent - 100) {
                          // Near bottom, trigger load more
                          if (widget.hasMore && !widget.isLoadingMore) {
                            widget.onScrollEnd?.call();
                          }
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredItems.length + (widget.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at the bottom
                        if (index == _filteredItems.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: R.h(12)),
                            child: Center(
                              child: SizedBox(
                                width: R.w(20),
                                height: R.w(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: CustomColors.primary(),
                                ),
                              ),
                            ),
                          );
                        }

                        final item = _filteredItems[index];
                        final isSelected = widget.selectedItems.contains(item);

                        return InkWell(
                          onTap: () {
                            widget.onItemToggle(item);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_isOpen && _overlayEntry != null && mounted) {
                                _overlayEntry?.markNeedsBuild();
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: R.w(16),
                              vertical: R.h(10),
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? CustomColors.primary().withValues(alpha: 0.05)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: index < _filteredItems.length - 1
                                      ? CustomColors.stroke()
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: isSelected
                                      ? CustomColors.primary()
                                      : Colors.grey,
                                  size: R.w(20),
                                ),
                                SizedBox(width: R.w(12)),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: CustomTextStyles.regular14.copyWith(
                                      color: isSelected
                                          ? CustomColors.primary()
                                          : CustomColors.black(),
                                      fontWeight: isSelected
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (_isOpen) {
          _closeOverlay();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: FormField<List<String>>(
          validator: widget.validator,
          initialValue: widget.selectedItems,
          builder: (FormFieldState<List<String>> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                if (widget.labelText.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: R.h(8)),
                    child: Row(
                      children: [
                        Text(
                          widget.labelText,
                          style: CustomTextStyles.medium14.copyWith(
                            color: CustomColors.black(),
                          ),
                        ),
                        if (widget.isRequired)
                          Text(
                            ' *',
                            style: CustomTextStyles.medium14.copyWith(
                              color: CustomColors.error(),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Multi-select field
                GestureDetector(
                  onTap: () {
                    _toggleOverlay();
                    state.didChange(widget.selectedItems);
                  },
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: R.h(28),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: R.w(16), vertical: R.h(8)),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state.hasError
                            ? CustomColors.error()
                            : CustomColors.whiteStroke(),
                      ),
                      borderRadius: BorderRadius.circular(R.r(8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: widget.selectedItems.isEmpty
                              ? Text(
                                  'Select ${widget.labelText.toLowerCase()}',
                                  style: CustomTextStyles.regular14.copyWith(
                                    color: Colors.grey,
                                  ),
                                )
                              : Wrap(
                                  spacing: R.w(6),
                                  runSpacing: R.h(6),
                                  children: widget.selectedItems
                                      .map(
                                        (item) => Chip(
                                          label: Text(
                                            item,
                                            style: CustomTextStyles.regular12.copyWith(
                                              color: CustomColors.white(),
                                            ),
                                          ),
                                          backgroundColor: CustomColors.primary(),
                                          deleteIcon: Icon(
                                            Icons.close,
                                            size: R.w(14),
                                            color: CustomColors.white(),
                                          ),
                                          onDeleted: () => widget.onItemToggle(item),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: R.w(6),
                                            vertical: R.h(2),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        SizedBox(width: R.w(8)),
                        Icon(
                          _isOpen ? Icons.keyboard_arrow_up_sharp : Icons.keyboard_arrow_down_sharp,
                          color: CustomColors.textGray(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Error message
                if (state.hasError)
                  Padding(
                    padding: EdgeInsets.only(top: R.h(4), left: R.w(12)),
                    child: Text(
                      state.errorText ?? '',
                      style: CustomTextStyles.regular12.copyWith(
                        color: CustomColors.error(),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}