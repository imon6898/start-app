import "package:flutter_starter/app/utils/constants/app_colors.dart";
import "package:flutter_starter/app/utils/constants/app_fonts.dart";
import "package:flutter_starter/app/utils/responsive_utils.dart";
import "package:flutter/material.dart";
import "package:get/get.dart";

class CustomDropdownButton extends StatefulWidget {
  final bool showLabel;
  final String labelText;
  final String valueText;
  final double labelFontSize;
  final double listFontSize;
  final bool isRequired;
  final CrossAxisAlignment labelAlignment;
  final List<String> itemList;
  final void Function(String value) onChange;
  final double popupWidth;
  final double popupItemHeight;
  final double borderRadius;
  final IconData dropdownIcon;
  final Color? dropdownIconColor;
  final FormFieldValidator<String>? validator;
  final bool showSearch;
  final String searchHint;
  /// Text to display when dropdown list is empty (optional)
  final String? isEmptyText;
  /// Callback for API-based search (called when user types in search field)
  /// If provided, search will be done via API instead of local filtering
  final void Function(String query)? onSearchChanged;

  const CustomDropdownButton({
    super.key,
    required this.itemList,
    required this.valueText,
    this.showLabel = true,
    this.labelFontSize = 14,
    this.listFontSize = 14,
    this.labelText = "Label",
    this.labelAlignment = CrossAxisAlignment.start,
    required this.onChange,
    this.popupWidth = 410,
    this.popupItemHeight = 50,
    this.borderRadius = 8,
    this.isRequired = false,
    this.dropdownIcon = Icons.keyboard_arrow_down_rounded,
    this.dropdownIconColor,
    this.validator,
    this.showSearch = false,
    this.searchHint = "Search...",
    this.isEmptyText,
    this.onSearchChanged,
  });

  @override
  State<CustomDropdownButton> createState() => CustomDropdownButtonState();
}

class CustomDropdownButtonState extends State<CustomDropdownButton>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;
  bool _keyboardOpen = false;

  String? selectedValue;
  late FormFieldState<String> _formFieldState;

  final TextEditingController searchController = TextEditingController();
  final ValueNotifier<List<String>> filteredItems = ValueNotifier([]);

  // GlobalKey to get the render box safely
  final GlobalKey _dropdownKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    selectedValue = widget.valueText.isNotEmpty ? widget.valueText : null;
    filteredItems.value = widget.itemList;
  }

  @override
  void didUpdateWidget(covariant CustomDropdownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update filteredItems when itemList changes (e.g., API data loaded)
    // Use post frame callback to avoid setState during build
    // Only reset filtered items when the actual list content changes,
    // not when Obx rebuilds with the same data (which creates new list instances)
    final listChanged = oldWidget.itemList.length != widget.itemList.length ||
        !_listEquals(oldWidget.itemList, widget.itemList);
    if (listChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          filteredItems.value = widget.itemList;
          // Clear search when items change
          searchController.clear();
        }
      });
    }
    // Update selectedValue when valueText changes externally
    if (oldWidget.valueText != widget.valueText) {
      final newValue = widget.valueText.isNotEmpty ? widget.valueText : null;
      if (selectedValue != newValue) {
        setState(() => selectedValue = newValue);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _formFieldState.didChange(newValue);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    filteredItems.dispose();
    _removeOverlay();
    super.dispose();
  }

  /// LISTEN FOR KEYBOARD OPEN/CLOSE
  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final wasKeyboardOpen = _keyboardOpen;
    _keyboardOpen = bottomInset > 0;

    // Only rebuild if keyboard state actually changed
    if (_isOpen && wasKeyboardOpen != _keyboardOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _overlayEntry?.markNeedsBuild();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.labelAlignment,
      children: [
        if (widget.showLabel)
          RichText(
            text: TextSpan(
              style: CustomTextStyles.medium14.copyWith(
                fontSize: widget.labelFontSize,
              ),
              children: [
                TextSpan(text: widget.labelText),
                if (widget.isRequired)
                  TextSpan(
                    text: " *",
                    style: CustomTextStyles.medium14.copyWith(
                      color: CustomColors.error(),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(height: R.h(5)),

        FormField<String>(
          initialValue: selectedValue,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (state) {
            _formFieldState = state;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
                    onTap: _toggleDropdown,
                    child: Container(
                      key: _dropdownKey,
                      constraints: BoxConstraints(
                        minHeight: R.h(28),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: R.w(14),
                        vertical: R.h(8),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          R.r(widget.borderRadius),
                        ),
                        border: Border.all(
                          width: state.hasError ? 1.5 : 1,
                          color: state.hasError
                              ? Colors.red
                              : CustomColors.whiteStroke(),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              selectedValue ?? "Select ${widget.labelText}",
                              style: CustomTextStyles.regular16.copyWith(
                                color: selectedValue != null
                                    ? CustomColors.black()
                                    : CustomColors.gray2(),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            widget.dropdownIcon,
                            color:
                                widget.dropdownIconColor ??
                                CustomColors.textGray(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 16),
                    child: Text(
                      state.errorText ?? '',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Toggle dropdown
  void _toggleDropdown() {
    if (_isOpen) {
      closeDropdown();
    } else {
      _showOverlay();
    }
  }

  void closeDropdown() {
    _removeOverlay();
    // Clear search when closing
    searchController.clear();
    filteredItems.value = widget.itemList;
  }

  void _showOverlay() {
    searchController.clear();
    filteredItems.value = widget.itemList;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
  }

  void _removeOverlay() {
    if (_isOpen) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOpen = false;
    }
  }

  /// Safe method to get render box position
  Offset? _getDropdownPosition() {
    final renderBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }
    return renderBox.localToGlobal(Offset.zero);
  }

  /// Safe method to get dropdown size
  Size? _getDropdownSize() {
    final renderBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  /// Calculate popup height based on item count (max 5 visible items)
  double _calculatePopupHeight() {
    final itemCount = widget.itemList.length;
    final maxVisibleItems = 5;
    // Ensure at least 1 item height when empty (for "No items found" message)
    final visibleItems = itemCount > maxVisibleItems
        ? maxVisibleItems
        : (itemCount == 0 ? 1 : itemCount);
    final searchHeight = widget.showSearch ? 60.0 : 0.0;
    final itemsHeight = visibleItems * widget.popupItemHeight;
    return searchHeight + itemsHeight;
  }

  /// ⭐ THIS CREATES THE OVERLAY / BOTTOM SHEET
  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final bottomInset = mediaQuery.viewInsets.bottom;
        final topSafeArea = mediaQuery.padding.top; // Status bar height
        final dropdownPosition = _getDropdownPosition();
        final dropdownSize = _getDropdownSize();
        final screenHeight = mediaQuery.size.height;

        // If we can't get the dropdown position, use a default position
        if (dropdownPosition == null || dropdownSize == null) {
          return _createFallbackOverlay(bottomInset);
        }

        final popupHeight = _calculatePopupHeight();
        final fieldBottomY = dropdownPosition.dy + dropdownSize.height;
        final spaceBelow = screenHeight - fieldBottomY - bottomInset - 16;
        // Account for safe area (status bar) when calculating space above
        final spaceAbove = dropdownPosition.dy - topSafeArea - 16;

        // Determine if popup should show above or below
        // Show above if: keyboard is open OR not enough space below
        final showAbove = _keyboardOpen || (spaceBelow < popupHeight && spaceAbove > spaceBelow);

        // Calculate effective height based on available space
        final effectiveHeight = showAbove
            ? popupHeight.clamp(0.0, spaceAbove)
            : popupHeight.clamp(0.0, spaceBelow);

        return Stack(
          children: [
            /// Close on outside tap - Full screen transparent overlay
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: closeDropdown,
                child: Container(color: Colors.transparent),
              ),
            ),

            /// ⭐ Position popup above or below field based on available space
            if (showAbove)
              Positioned(
                left: dropdownPosition.dx,
                bottom: screenHeight - dropdownPosition.dy + R.h(4),
                child: _dropdownMaterial(maxHeight: effectiveHeight),
              )
            else
              Positioned(
                left: dropdownPosition.dx,
                top: fieldBottomY + R.h(4),
                child: _dropdownMaterial(maxHeight: effectiveHeight),
              ),
          ],
        );
      },
    );
  }

  /// Fallback overlay when position can't be determined
  Widget _createFallbackOverlay(double bottomInset) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: closeDropdown,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: _keyboardOpen ? null : 100, // Default top position
          bottom: _keyboardOpen ? bottomInset + 16 : null,
          child: _dropdownMaterial(),
        ),
      ],
    );
  }

  /// Dropdown UI container
  Widget _dropdownMaterial({double? maxHeight}) {
    // Use field width if available, otherwise fall back to popupWidth
    final fieldWidth = _getDropdownSize()?.width;
    final effectiveWidth = fieldWidth ?? R.w(widget.popupWidth);
    final popupHeight = maxHeight ?? _calculatePopupHeight();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(R.r(widget.borderRadius)),
      child: Container(
        width: effectiveWidth,
        constraints: BoxConstraints(maxHeight: popupHeight),
        decoration: BoxDecoration(
          color: CustomColors.white(),
          borderRadius: BorderRadius.circular(R.r(widget.borderRadius)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _dropdownBody(),
      ),
    );
  }

  /// Main dropdown UI
  Widget _dropdownBody() {
    return Column(
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              onChanged: (value) {
                // If onSearchChanged callback is provided, call API for search
                if (widget.onSearchChanged != null) {
                  widget.onSearchChanged!(value);
                  // Don't filter locally - API will update itemList
                } else {
                  // Local filtering
                  filteredItems.value = value.isEmpty
                      ? widget.itemList
                      : widget.itemList
                            .where(
                              (e) =>
                                  e.toLowerCase().contains(value.toLowerCase()),
                            )
                            .toList();
                }
              },
            ),
          ),

        Expanded(
          child: ValueListenableBuilder<List<String>>(
            valueListenable: filteredItems,
            builder: (context, items, _) {
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.isEmptyText ?? 'No items found',
                      style: CustomTextStyles.medium16.copyWith(
                        color: CustomColors.gray2(),
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final value = items[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedValue = value);
                      widget.onChange(value);
                      _formFieldState.didChange(value);
                      closeDropdown();
                    },
                    child: Container(
                      width: double.infinity,
                      height: widget.popupItemHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: index < items.length - 1
                            ? Border(
                                bottom: BorderSide(
                                  color: CustomColors.whiteStroke(),
                                  width: 1,
                                ),
                              )
                            : null,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: CustomTextStyles.medium16.copyWith(
                            fontSize: widget.listFontSize,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
