import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum SelectionMode { single, multi }

class CustomSelectSection<T> extends StatefulWidget {
  final String hintText;
  final Map<T, String> items; // Map of ID -> Name
  final List<T> selectedItems; // List of selected IDs (dynamic type)
  final String? labelText;
  final bool? filled;
  final Color? fillColor;
  final ValueChanged<List<T>> onChangedSelection;
  final bool isRequired;
  final bool labelOnBoard;
  final FormFieldValidator<List<T>>? validator;
  final bool searchRequired;
  final TextEditingController? controller;
  final AutovalidateMode autovalidateMode;
  final SelectionMode selectionMode;

  const CustomSelectSection({
    super.key,
    required this.hintText,
    required this.items,
    required this.selectedItems,
    this.labelText,
    required this.onChangedSelection,
    this.isRequired = false,
    this.labelOnBoard = false,
    this.validator,
    this.controller,
    this.filled = true,
    this.fillColor,
    this.searchRequired = false,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.selectionMode = SelectionMode.single,
  });

  @override
  State<CustomSelectSection<T>> createState() => _CustomSelectSectionState<T>();
}

class _CustomSelectSectionState<T> extends State<CustomSelectSection<T>> {
  List<T> selectedItems = [];
  bool isDropdownOpen = false;
  String searchQuery = '';
  List<T> filteredItems = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late FormFieldState<List<T>> _formFieldState;

  @override
  void initState() {
    super.initState();
    selectedItems = List.from(widget.selectedItems);
    _updateFilteredItems();

    if (widget.controller != null && selectedItems.isNotEmpty) {
      widget.controller!.text = widget.items[selectedItems.first] ?? '';
    }

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && !isDropdownOpen) {
        setState(() {
          isDropdownOpen = true;
        });
      }
      // When search field gains focus, ensure widget is visible
      if (_searchFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _containerKey.currentContext != null) {
              Scrollable.ensureVisible(
                _containerKey.currentContext!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.3,
              );
              // Refresh overlay position after scrolling
              if (isDropdownOpen && _overlayEntry != null) {
                _removeOverlay();
                _showOverlay();
              }
            }
          });
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomSelectSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.items != oldWidget.items) {
      _updateFilteredItems();
    }

    if (widget.selectedItems != oldWidget.selectedItems) {
      setState(() {
        selectedItems = List.from(widget.selectedItems);
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_overlayEntry == null) {
      FocusScope.of(Get.context!).unfocus();
      _showOverlay();
    } else {
      _removeOverlay();
    }
    setState(() {
      if (isDropdownOpen) {
        FocusScope.of(Get.context!).requestFocus(_searchFocusNode);
      } else {
        _searchFocusNode.unfocus();
      }
    });
  }

  void _onItemChanged(T item) {
    setState(() {
      if (widget.selectionMode == SelectionMode.single) {
        selectedItems = [item];
      } else {
        if (selectedItems.contains(item)) {
          selectedItems.remove(item);
        } else {
          selectedItems.add(item);
        }
      }
      widget.onChangedSelection(selectedItems);
      _formFieldState.didChange(selectedItems);
    });

    if (widget.selectionMode == SelectionMode.single) {
      _removeOverlay();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _removeOverlay();
        _showOverlay();
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      searchQuery = query;
      _updateFilteredItems();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removeOverlay();
      _showOverlay();
    });
  }

  void _updateFilteredItems() {
    setState(() {
      filteredItems = widget.items.keys
          .where(
            (item) =>
                widget.items[item]?.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ??
                false,
          )
          .toList();
    });
  }

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showOverlay() {
    setState(() {
      isDropdownOpen = true;
    });
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisible();
    });
  }

  void _ensureVisible() {
    final RenderBox? renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      Scrollable.ensureVisible(
        _containerKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (mounted) {
      isDropdownOpen = false;
    }
  }

  void _removeSelectedItem(T item) {
    setState(() {
      selectedItems.remove(item);
      widget.onChangedSelection(selectedItems);
      _formFieldState.didChange(selectedItems);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removeOverlay();
    });
  }

  final GlobalKey _containerKey = GlobalKey();

  OverlayEntry _createOverlayEntry() {
    final RenderBox? renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final double containerHeight = renderBox?.size.height ?? R.h(70);

    final Offset containerPosition =
        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topSafeArea = MediaQuery.of(context).padding.top;

    final double estimatedDropdownHeight = (filteredItems.length * R.h(40))
        .clamp(R.h(50), R.h(250));

    final double availableSpaceAbove =
        containerPosition.dy - topSafeArea - R.h(16);
    final bool isExpanded = selectedItems.isNotEmpty;

    return OverlayEntry(
      builder: (overlayContext) {
        final double currentKeyboardHeight = MediaQuery.of(
          overlayContext,
        ).viewInsets.bottom;
        final double currentAvailableSpaceBelow =
            screenHeight -
            containerPosition.dy -
            containerHeight -
            currentKeyboardHeight -
            R.h(16);
        final bool shouldShowAbove =
            isExpanded ||
            (currentAvailableSpaceBelow < estimatedDropdownHeight &&
                availableSpaceAbove > estimatedDropdownHeight);

        // Recalculate effective height for current state
        final double currentEffectiveHeight = shouldShowAbove
            ? estimatedDropdownHeight.clamp(0.0, availableSpaceAbove)
            : estimatedDropdownHeight.clamp(0.0, currentAvailableSpaceBelow);

        return Positioned(
          width: MediaQuery.of(overlayContext).size.width * 0.923,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: shouldShowAbove
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: shouldShowAbove
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, shouldShowAbove ? -R.h(5) : R.h(5)),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(R.r(8)),
              child: Container(
                constraints: BoxConstraints(maxHeight: currentEffectiveHeight),
                decoration: BoxDecoration(
                  color: CustomColors.white(),
                  borderRadius: BorderRadius.circular(R.r(8)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: R.h(8),
                    horizontal: R.w(8),
                  ),
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: R.h(16)),
                            child: Text(
                              'Not found',
                              style: CustomTextStyles.regular14,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Wrap(
                            spacing: R.w(8),
                            runSpacing: R.h(8),
                            children: filteredItems.map((itemId) {
                              final itemName = widget.items[itemId];
                              if (itemName == null) {
                                return const SizedBox.shrink();
                              }
                              final isSelected = selectedItems.contains(itemId);
                              return GestureDetector(
                                onTap: () => _onItemChanged(itemId),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: R.w(4),
                                    vertical: R.h(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? CustomColors.primary()
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(R.r(8)),
                                    border: Border.all(
                                      color: CustomColors.primary(),
                                    ),
                                  ),
                                  child: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: R.sp(13),
                                      color: isSelected
                                          ? CustomColors.white()
                                          : CustomColors.black(),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<T>>(
      initialValue: selectedItems,
      validator: widget.isRequired
          ? (value) => value == null || value.isEmpty
                ? '${widget.hintText} is required'
                : null
          : widget.validator,
      autovalidateMode: widget.autovalidateMode,
      builder: (FormFieldState<List<T>> state) {
        _formFieldState = state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.labelText != null && !widget.labelOnBoard) ...[
              Text(
                widget.labelText!,
                style: TextStyle(
                  fontSize: R.sp(16),
                  fontWeight: FontWeight.bold,
                  color: state.hasError ? Colors.red : CustomColors.black(),
                ),
              ),
              SizedBox(height: R.h(5)),
            ],
            CompositedTransformTarget(
              link: _layerLink,
              child: GestureDetector(
                key: _containerKey,
                onTap: _toggleDropdown,
                child: widget.labelOnBoard
                    ? InputDecorator(
                        decoration: InputDecoration(
                          fillColor: widget.fillColor ?? CustomColors.white(),
                          filled: widget.filled,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: R.w(12),
                          ),
                          label: !isDropdownOpen
                              ? selectedItems.isNotEmpty
                                    ? Text(
                                        widget.labelText!,
                                        style: TextStyle(
                                          fontSize: R.sp(16),
                                          fontWeight: FontWeight.bold,
                                          color: state.hasError
                                              ? Colors.red
                                              : CustomColors.black(),
                                        ),
                                      )
                                    : RichText(text: const TextSpan())
                              : Text(widget.hintText),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          labelStyle: TextStyle(
                            color: CustomColors.black(),
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(R.r(10)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  selectedItems.isNotEmpty
                                      ? Container(
                                          margin: EdgeInsets.symmetric(
                                            vertical: R.h(10),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: R.w(12),
                                            vertical: R.h(6),
                                          ),
                                          decoration: BoxDecoration(
                                            color: CustomColors.white(),
                                            borderRadius: BorderRadius.circular(
                                              R.r(8),
                                            ),
                                            border: Border.all(
                                              width: 1,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: selectedItems.map((item) {
                                              final itemName =
                                                  widget.items[item];
                                              return Text(
                                                itemName ?? '',
                                                style: TextStyle(
                                                  fontSize: R.sp(13),
                                                  color: CustomColors.black(),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        )
                                      : !isDropdownOpen
                                      ? Text(
                                          widget.hintText,
                                          style: TextStyle(
                                            color: CustomColors.black(),
                                          ),
                                        )
                                      : Container(),
                                  if (isDropdownOpen &&
                                      widget.searchRequired) ...[
                                    SizedBox(height: R.h(5)),
                                    TextField(
                                      focusNode: _searchFocusNode,
                                      controller: _searchController,
                                      onChanged: _filterItems,
                                      decoration: InputDecoration(
                                        hintText: 'Search...',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(
                                          color: CustomColors.black(),
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: CustomColors.black(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              isDropdownOpen
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              color: CustomColors.black(),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        constraints: BoxConstraints(minHeight: R.h(40)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(R.r(8)),
                          border: Border.all(
                            width: state.hasError ? 1.5 : 1,
                            color: state.hasError
                                ? Colors.red
                                : CustomColors.gray(),
                          ),
                          color: widget.fillColor ?? CustomColors.white(),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: R.w(8),
                          vertical: R.h(8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  selectedItems.isNotEmpty
                                      ? Wrap(
                                          alignment: WrapAlignment.start,
                                          spacing: R.w(8),
                                          runSpacing: 0.0,
                                          children: selectedItems.map((item) {
                                            final itemName = widget.items[item];
                                            if (itemName == null) {
                                              return const SizedBox();
                                            }
                                            return Chip(
                                              backgroundColor:
                                                  CustomColors.white(),
                                              labelPadding: EdgeInsets.all(
                                                R.w(2),
                                              ),
                                              padding: EdgeInsets.all(R.w(5)),
                                              label: SizedBox(
                                                height: R.h(20),
                                                child: Text(
                                                  itemName,
                                                  style: CustomTextStyles
                                                      .medium12
                                                      .copyWith(
                                                        color:
                                                            CustomColors.black(),
                                                      ),
                                                ),
                                              ),
                                              deleteIcon: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.redAccent,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Icon(
                                                  LucideIcons.x,
                                                  size: R.h(12),
                                                  color: Colors.red,
                                                ),
                                              ),
                                              onDeleted: () =>
                                                  _removeSelectedItem(item),
                                            );
                                          }).toList(),
                                        )
                                      : (!isDropdownOpen ||
                                            (isDropdownOpen &&
                                                !widget.searchRequired))
                                      ? Text(
                                          widget.hintText,
                                          style: TextStyle(
                                            fontSize: R.sp(16),
                                            color: CustomColors.gray2(),
                                          ),
                                        )
                                      : const SizedBox(),
                                  if (isDropdownOpen &&
                                      widget.searchRequired) ...[
                                    Container(
                                      height: R.h(40),
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.5,
                                      padding: EdgeInsets.symmetric(
                                        vertical: R.h(4),
                                      ),
                                      child: TextField(
                                        focusNode: _searchFocusNode,
                                        controller: _searchController,
                                        onChanged: _filterItems,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: R.h(6),
                                            horizontal: R.w(6),
                                          ),
                                          hintText: 'Search...',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: R.sp(14),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              R.r(12),
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              R.r(12),
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey,
                                              width: 1.0,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              R.r(12),
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: CustomColors.white(),
                                        ),
                                        style: CustomTextStyles.regular14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              isDropdownOpen
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              color: CustomColors.gray2(),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: EdgeInsets.only(top: R.h(4), left: R.w(16)),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
