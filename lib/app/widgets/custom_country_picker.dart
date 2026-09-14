import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/widgets/custom_phone_text_field.dart';
import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

import 'package:get/get.dart';

class CustomCountryPicker extends StatefulWidget {
  final String? textHeading;
  final String? hintText;
  final Function(Country country)? onCountryChanged;
  final Country? initialCountry;
  final bool required;
  final double? borderRadius;
  final Color? fillColor;
  final bool filled;
  final Color? focusBorderColor;
  final Color? disableBorderColor;
  final Color? enabledBorderColor;
  final FormFieldValidator<String>? validator;
  final dynamic controller; // Can be any controller type
  final double? height; // Custom height for the selected box

  const CustomCountryPicker({
    super.key,
    this.textHeading = 'Country',
    this.hintText = 'Select Country',
    this.onCountryChanged,
    this.initialCountry,
    this.required = false,
    this.borderRadius,
    this.fillColor,
    this.filled = false,
    this.focusBorderColor,
    this.disableBorderColor,
    this.enabledBorderColor,
    this.validator,
    this.controller,
    this.height,
  });

  @override
  State<CustomCountryPicker> createState() => _CustomCountryPickerState();
}

class _CustomCountryPickerState extends State<CustomCountryPicker>
    with WidgetsBindingObserver {
  late Country selectedCountry;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  bool _isCountryDropdownOpen = false;
  bool _showAbove = false; // Track if overlay should show above the field
  final TextEditingController _searchController = TextEditingController();
  List<Country> filteredCountries = CountryData.countries;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedCountry = widget.initialCountry ?? CountryData.getDefaultCountry();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Rebuild overlay when keyboard appears/disappears
    if (_isCountryDropdownOpen && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    if (_isCountryDropdownOpen) {
      _removeOverlay();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredCountries = CountryData.searchCountries(_searchController.text);
    });
  }

  void _toggleCountryDropdown() {
    if (_isCountryDropdownOpen) {
      _closeCountryDropdown();
    } else {
      _showCountryOverlay();
    }
  }

  void _showCountryOverlay() {
    // Calculate if we should show above or below
    _calculateOverlayPosition();

    _overlayEntry = _createCountryOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _searchController.clear();
    filteredCountries = CountryData.countries;
    setState(() {
      _isCountryDropdownOpen = true;
    });
  }

  void _calculateOverlayPosition() {
    final RenderBox? renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset fieldPosition = renderBox.localToGlobal(Offset.zero);
    final double fieldHeight = renderBox.size.height;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Calculate available space below and above
    final double availableBelow =
        screenHeight - fieldPosition.dy - fieldHeight - keyboardHeight - R.h(20);
    final double availableAbove = fieldPosition.dy - R.h(20);

    // Overlay height (40% of screen)
    final double overlayHeight = screenHeight * 0.4;

    // Show above if not enough space below and more space above
    _showAbove = availableBelow < overlayHeight && availableAbove > availableBelow;
  }

  void _closeCountryDropdown() {
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isCountryDropdownOpen = false;
    });
  }

  Widget _buildOverlayContent(double fieldWidth, double maxOverlayHeight) {
    return StatefulBuilder(
      builder: (context, setOverlayState) {
        return Container(
          width: fieldWidth,
          constraints: BoxConstraints(maxHeight: maxOverlayHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search field
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: R.w(12),
                  vertical: R.h(8),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setOverlayState(() {
                      filteredCountries =
                          CountryData.searchCountries(value);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search country...',
                    hintStyle: CustomTextStyles.regular14.copyWith(
                      color: CustomColors.gray2(),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: CustomColors.gray2(),
                      size: R.w(20),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.r(6)),
                      borderSide: BorderSide(
                        color: CustomColors.whiteStroke(),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.r(6)),
                      borderSide: BorderSide(
                        color: CustomColors.whiteStroke(),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.r(6)),
                      borderSide: BorderSide(
                        color: CustomColors.primary(),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: R.w(12),
                      vertical: R.h(8),
                    ),
                  ),
                  style: CustomTextStyles.regular14,
                ),
              ),
              // Country list
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: filteredCountries.length,
                  itemBuilder: (context, index) {
                    final country = filteredCountries[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCountry = country;
                        });
                        widget.onCountryChanged?.call(country);
                        _closeCountryDropdown();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: R.w(16),
                          vertical: R.h(8),
                        ),
                        decoration: BoxDecoration(
                          color: selectedCountry.code == country.code
                              ? CustomColors.primary().withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Text(
                              country.flag,
                              style: TextStyle(fontSize: R.sp(20)),
                            ),
                            SizedBox(width: R.w(12)),
                            Expanded(
                              child: Text(
                                country.name,
                                style: CustomTextStyles.medium14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  OverlayEntry _createCountryOverlayEntry() {
    // Get the width and position of the field
    final RenderBox? renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double fieldWidth = renderBox?.size.width ?? Get.width - R.w(32);
    final double fieldHeight = renderBox?.size.height ?? R.h(50);
    final Offset fieldPosition =
        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final double fieldLeft = fieldPosition.dx;
    final double fieldTop = fieldPosition.dy;

    return OverlayEntry(
      builder: (context) {
        // Get keyboard height from MediaQuery
        final double keyboardHeight =
            MediaQuery.of(context).viewInsets.bottom;
        final double screenHeight = MediaQuery.of(context).size.height;
        final double statusBarHeight = MediaQuery.of(context).padding.top;

        // Check if keyboard is visible
        final bool isKeyboardVisible = keyboardHeight > 0;

        // Determine overlay height based on available space
        double maxOverlayHeight;
        double topPosition;

        if (isKeyboardVisible) {
          // Available space = screen - keyboard - statusBar - padding
          maxOverlayHeight = screenHeight - keyboardHeight - statusBarHeight - R.h(30);
          // Position at top when keyboard is visible
          topPosition = statusBarHeight + R.h(10);
        } else {
          // When no keyboard, use 40% of screen height
          maxOverlayHeight = screenHeight * 0.4;
          // Position below the field
          topPosition = fieldTop + fieldHeight + R.h(4);

          // Check if overlay would go off screen, if so show above
          if (topPosition + maxOverlayHeight > screenHeight - R.h(20)) {
            topPosition = fieldTop - maxOverlayHeight - R.h(4);
          }
        }

        // Always use Positioned to avoid widget tree recreation
        return Stack(
          children: [
            // Background barrier to close dropdown when tapped outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeCountryDropdown,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Overlay content - always use Positioned
            Positioned(
              left: fieldLeft,
              top: topPosition,
              child: Material(
                elevation: 5.0,
                borderRadius:
                    BorderRadius.circular(widget.borderRadius ?? R.r(8)),
                color: CustomColors.white(),
                child: _buildOverlayContent(fieldWidth, maxOverlayHeight),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _validateCountry(String? value) {
    if (widget.validator != null) {
      return widget.validator!(value);
    }

    if (widget.required && (value == null || value.trim().isEmpty)) {
      return 'Please select a country';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.textHeading != null) ...[
          RichText(
            text: TextSpan(
              style: CustomTextStyles.bold14,
              children: <TextSpan>[
                TextSpan(text: widget.textHeading!),
                if (widget.required)
                  TextSpan(
                    text: " *",
                    style: CustomTextStyles.semiBold14.copyWith(
                      color: CustomColors.error(),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: R.h(5)),
        ],
        FormField<String>(
          initialValue: selectedCountry.name,
          validator: _validateCountry,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
                    onTap: _toggleCountryDropdown,
                    child: Container(
                      key: _fieldKey,
                      width: double.infinity,
                      height: widget.height ?? R.h(34),
                      padding: EdgeInsets.symmetric(
                        horizontal: R.w(14),
                        vertical: R.h(4),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          widget.borderRadius ?? R.r(8),
                        ),
                        border: Border.all(
                          width: 1,
                          color: state.hasError
                              ? Colors.red
                              : widget.enabledBorderColor ??
                                    CustomColors.whiteStroke(),
                        ),
                        color: widget.fillColor ?? Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedCountry.flag,
                            style: TextStyle(fontSize: R.sp(18)),
                          ),
                          SizedBox(width: R.w(8)),
                          Expanded(
                            child: Text(
                              selectedCountry.name,
                              style: CustomTextStyles.medium16,
                            ),
                          ),
                          SizedBox(width: R.w(8)),
                          Icon(
                            _isCountryDropdownOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: CustomColors.gray2(),
                            size: R.w(20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: EdgeInsets.only(top: R.h(4), left: R.w(8)),
                    child: Text(
                      state.errorText ?? '',
                      style: TextStyle(color: Colors.red, fontSize: R.sp(12)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
