import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/app/core/models/country.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:get/get.dart';

class CustomPhoneTextField extends StatefulWidget {
  final String? hintText;
  final String? textHeading;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final TextInputAction inputAction;

  /// Local-digits change. Fires on every keystroke (post dial-code strip).
  final ValueChanged<String>? onChanged;

  /// E.164 change (e.g. `+8801322600847`). Fires when local digits or
  /// country change. Use this for live API submission previews.
  final ValueChanged<String>? onPhoneChanged;

  final ValueChanged<Country>? onCountryChanged;

  final bool isEnabled;
  final double? borderRadius;
  final Color? fillColor;
  final bool filled;
  final Color? focusBorderColor;
  final Color? disableBorderColor;
  final Color? enabledBorderColor;
  final bool required;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmit;

  /// Country-aware validator. Receives the local digits (no dial code).
  final FormFieldValidator<String>? validator;

  /// Initial country when the widget is first built. If null we try device
  /// locale, then fall back to US. The widget never auto-parses the
  /// controller text on init — call [CustomPhoneTextFieldState.setPhoneNumber]
  /// after build to load an existing E.164 value.
  final Country? initialCountry;

  final double? height;

  const CustomPhoneTextField({
    super.key,
    this.hintText,
    this.textHeading,
    this.controller,
    this.focusNode,
    this.nextFocus,
    this.validator,
    this.isEnabled = true,
    this.inputAction = TextInputAction.next,
    this.onChanged,
    this.onPhoneChanged,
    this.onCountryChanged,
    this.borderRadius,
    this.fillColor,
    this.filled = false,
    this.focusBorderColor,
    this.disableBorderColor,
    this.enabledBorderColor,
    this.required = false,
    this.onTap,
    this.onSubmit,
    this.initialCountry,
    this.height,
  });

  @override
  CustomPhoneTextFieldState createState() => CustomPhoneTextFieldState();
}

// Public state class — accessible via GlobalKey<CustomPhoneTextFieldState>.
class CustomPhoneTextFieldState extends State<CustomPhoneTextField>
    with WidgetsBindingObserver {
  late Country _selectedCountry;

  /// Tracks whether the user has explicitly picked a country (via the
  /// dropdown or via parsing). Once true, we stop overriding it from
  /// `widget.initialCountry` updates in [didUpdateWidget].
  bool _userPickedCountry = false;

  /// Re-entrancy guard. The controller listener triggers `_parseAndApply`,
  /// which writes back to the controller — without this flag we'd loop.
  bool _isInternalWrite = false;

  // Overlay / dropdown state
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  bool _isDropdownOpen = false;
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filteredCountries = CountryData.countries;

  /// E.164 max is 15 digits total. We allow a temporary `+` while the user
  /// is typing/pasting so [_parseAndApply] can detect and strip it.
  static const int _kMaxRawLength = 16; // 15 digits + 1 leading '+'

  Country get selectedCountry => _selectedCountry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedCountry = _resolveInitialCountry();
    widget.controller?.addListener(_onControllerChanged);
    // Intentionally NOT parsing controller.text here — the spec requires
    // parsing only on user input or explicit setPhoneNumber() calls.
  }

  Country _resolveInitialCountry() {
    // Priority: explicit prop → device locale → IP-geo cache (from
    // IpLocationService.preload) → US fallback. The IP step is read
    // synchronously from cache only — never a live fetch — so there's
    // no flicker on first paint.
    return widget.initialCountry ??
        CountryData.fromDeviceLocale() ??
        CountryData.fromIpCached() ??
        CountryData.getDefaultCountry();
  }

  @override
  void didUpdateWidget(covariant CustomPhoneTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }

    // Honour `initialCountry` updates only if the user hasn't taken over.
    if (!_userPickedCountry &&
        widget.initialCountry != null &&
        widget.initialCountry != oldWidget.initialCountry) {
      setState(() => _selectedCountry = widget.initialCountry!);
      // Notify after build so parents aren't called during their own build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCountryChanged?.call(_selectedCountry);
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  // Public API
  // Call via GlobalKey<CustomPhoneTextFieldState>().currentState?.setPhoneNumber(...)

  /// Programmatically load an E.164-style value (e.g. `+8801322600847`).
  /// Splits the dial code, updates the country, and writes the local
  /// digits into the controller.
  void setPhoneNumber(String phone) {
    if (phone.isEmpty) {
      _isInternalWrite = true;
      widget.controller?.text = '';
      _isInternalWrite = false;
      _emitPhoneChanged();
      return;
    }
    _parseAndApply(phone, userInitiated: false);
  }

  /// Returns the full E.164 number (`+<dial><local>`). Returns just the
  /// dial code if local digits are empty.
  String getFullPhoneNumber() {
    final local = widget.controller?.text.replaceAll(RegExp(r'\D'), '') ?? '';
    return '${_selectedCountry.dialCode}$local';
  }

  // Listeners

  void _onControllerChanged() {
    if (_isInternalWrite) return;
    final text = widget.controller?.text ?? '';
    // External programmatic write that includes a dial code — split it.
    if (text.startsWith('+') || text.startsWith('00')) {
      // Defer to post-frame to avoid setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _parseAndApply(text, userInitiated: false);
      });
    }
  }

  /// Splits `phone`, updates state + controller, and notifies callbacks.
  /// Caller controls whether this counts as a user-initiated change (which
  /// flips `_userPickedCountry` so [didUpdateWidget] stops overriding).
  void _parseAndApply(String phone, {required bool userInitiated}) {
    final parsed = CountryData.splitPhone(phone);
    final country = parsed.country;
    if (country == null) return;

    final countryChanged = _selectedCountry != country;
    if (countryChanged) {
      setState(() {
        _selectedCountry = country;
        if (userInitiated) _userPickedCountry = true;
      });
      widget.onCountryChanged?.call(country);
    }

    final controller = widget.controller;
    if (controller != null && controller.text != parsed.number) {
      _isInternalWrite = true;
      controller.value = TextEditingValue(
        text: parsed.number,
        selection: TextSelection.collapsed(offset: parsed.number.length),
      );
      _isInternalWrite = false;
    }
    _emitPhoneChanged();
  }

  void _emitPhoneChanged() {
    final cb = widget.onPhoneChanged;
    if (cb != null) cb(getFullPhoneNumber());
  }

  void _onTextChanged(String value) {
    widget.onChanged?.call(value);
    // Auto-detect when the user types or pastes a `+`/`00` prefix.
    if (value.startsWith('+') || value.startsWith('00')) {
      _parseAndApply(value, userInitiated: true);
    }
    _emitPhoneChanged();
  }

  // Overlay handling

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_isDropdownOpen) _overlayEntry?.markNeedsBuild();
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    _filteredCountries = CountryData.countries;
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted && _isDropdownOpen) {
      setState(() => _isDropdownOpen = false);
    } else {
      _isDropdownOpen = false;
    }
  }

  void _selectCountry(Country country) {
    if (_selectedCountry != country) {
      setState(() {
        _selectedCountry = country;
        _userPickedCountry = true;
      });
      widget.onCountryChanged?.call(country);
      _emitPhoneChanged();
    }
    _removeOverlay();
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (overlayCtx) {
        final renderBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final fieldSize = renderBox?.size ?? const Size(280, 44);
        final mq = MediaQuery.of(overlayCtx);
        final keyboardHeight = mq.viewInsets.bottom;
        final screenHeight = mq.size.height;

        // Compute max overlay height based on remaining space below the
        // field after subtracting the keyboard.
        final fieldGlobalTop = renderBox?.localToGlobal(Offset.zero).dy ?? 0;
        final spaceBelow =
            screenHeight - fieldGlobalTop - fieldSize.height - keyboardHeight;
        final spaceAbove = fieldGlobalTop - mq.padding.top;
        // Prefer below; flip above if it doesn't fit.
        final goesAbove = spaceBelow < R.h(220) && spaceAbove > spaceBelow;
        final maxH = (goesAbove ? spaceAbove : spaceBelow).clamp(
          R.h(180),
          R.h(360),
        );

        return Stack(
          children: [
            // Tap-outside barrier
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeOverlay,
                child: const SizedBox.shrink(),
              ),
            ),
            // Scroll/resize-safe positioning via CompositedTransformFollower
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: goesAbove
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: goesAbove
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              offset: Offset(0, goesAbove ? -R.h(4) : R.h(4)),
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(
                  widget.borderRadius ?? R.r(8),
                ),
                color: Theme.of(overlayCtx).colorScheme.surface,
                child: SizedBox(
                  width: fieldSize.width,
                  child: _DropdownContent(
                    maxHeight: maxH,
                    selectedCountry: _selectedCountry,
                    searchController: _searchController,
                    initialList: _filteredCountries,
                    onCountryTap: _selectCountry,
                    borderRadius: widget.borderRadius ?? R.r(8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Validation

  String? _runValidator(String? value) {
    if (widget.validator != null) return widget.validator!(value);
    if (!widget.required && (value == null || value.trim().isEmpty)) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.'.tr;
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Phone number is too short.'.tr;
    if (digits.length > 15) return 'Phone number is too long.'.tr;
    return null;
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.textHeading != null) ...[
          RichText(
            text: TextSpan(
              style: CustomTextStyles.medium14,
              children: [
                TextSpan(text: widget.textHeading),
                if (widget.required)
                  TextSpan(
                    text: ' *',
                    style: CustomTextStyles.semiBold14.copyWith(
                      color: CustomColors.error(),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: R.h(5)),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: ConstrainedBox(
            key: _fieldKey,
            constraints: BoxConstraints(minHeight: widget.height ?? R.h(44)),
            child: TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.isEnabled,
              keyboardType: TextInputType.phone,
              textInputAction: widget.inputAction,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _runValidator,
              inputFormatters: [
                // Allow `+` so users can paste/type +880... (auto-detected).
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(_kMaxRawLength),
              ],
              style: CustomTextStyles.regular16,
              decoration: InputDecoration(
                errorMaxLines: 2,
                isDense: true,
                hintText: widget.hintText ?? 'Enter phone number'.tr,
                hintStyle: CustomTextStyles.regular16.copyWith(
                  color: CustomColors.gray2(),
                ),
                filled: widget.filled,
                fillColor: widget.fillColor,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: R.w(14),
                  vertical: R.h(8),
                ),
                prefixIcon: GestureDetector(
                  onTap: widget.isEnabled ? _toggleDropdown : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: R.w(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedCountry.flag,
                          style: TextStyle(fontSize: R.sp(18)),
                        ),
                        SizedBox(width: R.w(4)),
                        Text(
                          _selectedCountry.dialCode,
                          style: CustomTextStyles.medium14,
                        ),
                        SizedBox(width: R.w(4)),
                        Icon(
                          _isDropdownOpen
                              ? LucideIcons.chevronUp
                              : LucideIcons.chevronDown,
                          color: CustomColors.gray2(),
                          size: R.w(20),
                        ),
                      ],
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                enabledBorder: _border(
                  widget.enabledBorderColor ?? CustomColors.whiteStroke(),
                ),
                focusedBorder: _border(
                  widget.focusBorderColor ?? CustomColors.whiteStroke(),
                ),
                focusedErrorBorder: _border(Colors.red, width: 1.5),
                disabledBorder: _border(
                  widget.disableBorderColor ?? CustomColors.gray(),
                ),
                errorBorder: _border(Colors.red, width: 1.5),
                errorStyle: TextStyle(color: CustomColors.error()),
              ),
              onFieldSubmitted: (text) {
                final onSubmit = widget.onSubmit;
                if (onSubmit != null) {
                  onSubmit(text);
                } else if (widget.nextFocus != null) {
                  FocusScope.of(context).requestFocus(widget.nextFocus);
                }
              },
              onChanged: _onTextChanged,
              onTap: widget.onTap,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? R.r(8)),
        borderSide: BorderSide(width: width, color: color),
      );
}

// Dropdown content (extracted so its TextField rebuilds locally without
// rebuilding the whole phone field).
class _DropdownContent extends StatefulWidget {
  final double maxHeight;
  final Country selectedCountry;
  final TextEditingController searchController;
  final List<Country> initialList;
  final ValueChanged<Country> onCountryTap;
  final double borderRadius;

  const _DropdownContent({
    required this.maxHeight,
    required this.selectedCountry,
    required this.searchController,
    required this.initialList,
    required this.onCountryTap,
    required this.borderRadius,
  });

  @override
  State<_DropdownContent> createState() => _DropdownContentState();
}

class _DropdownContentState extends State<_DropdownContent> {
  late List<Country> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.initialList;
  }

  void _onSearch(String value) {
    setState(() => _filtered = CountryData.searchCountries(value));
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = CustomColors.primary().withValues(alpha: 0.1);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: R.w(12),
              vertical: R.h(8),
            ),
            child: TextField(
              controller: widget.searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search country...'.tr,
                hintStyle: CustomTextStyles.regular14.copyWith(
                  color: CustomColors.gray2(),
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: CustomColors.gray2(),
                  size: R.w(20),
                ),
                border: _searchBorder(CustomColors.whiteStroke()),
                enabledBorder: _searchBorder(CustomColors.whiteStroke()),
                focusedBorder: _searchBorder(CustomColors.primary()),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: R.w(12),
                  vertical: R.h(8),
                ),
              ),
              style: CustomTextStyles.regular14,
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final country = _filtered[index];
                final isSelected = widget.selectedCountry == country;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${country.name} ${country.dialCode}',
                  child: InkWell(
                    onTap: () => widget.onCountryTap(country),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: R.w(16),
                        vertical: R.h(8),
                      ),
                      color: isSelected ? highlightColor : Colors.transparent,
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            country.dialCode,
                            style: CustomTextStyles.medium14.copyWith(
                              color: CustomColors.gray2(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(R.r(6)),
    borderSide: BorderSide(color: color),
  );
}
