import 'package:flutter/material.dart';
import 'package:flutter_starter/app/core/enums/enums.dart';
import 'package:flutter_starter/app/themes/tokens/tokens.dart';
import 'package:flutter_starter/app/utils/constants/app_assets.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/widgets.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../catalog_controllers/catalog_controller.dart';
import '../catalog_models/catalog_entry.dart';

/// Every widget in lib/app/widgets/, with a live demo each.
/// test/guardrails/catalog_coverage_test.dart fails when one is missing.
class CatalogRegistry {
  const CatalogRegistry._();

  static const String _appBar = 'App bar';
  static const String _buttons = 'Buttons';
  static const String _feedback = 'Feedback';
  static const String _inputs = 'Inputs';
  static const String _layout = 'Layout';
  static const String _media = 'Media';
  static const String _pagination = 'Pagination';

  static List<CatalogEntry> entries(CatalogController c) => <CatalogEntry>[
    // App bar
    CatalogEntry(
      name: 'AppBarWidget',
      group: _appBar,
      source: 'lib/app/widgets/appbar_widgets/appbar_widget.dart',
      note: 'Implements PreferredSizeWidget — as Scaffold.appBar wrap it in a '
          'PreferredSize sized kToolbarHeight + R.h(10).',
      demo: (context) => MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: AppBarWidget(
          title: 'Screen title',
          isBackForcefullyShow: true,
          toolbarActions: [
            Icon(
              LucideIcons.search,
              size: R.w(DsIconSize.lg),
              color: DsRole.onSurface(),
            ),
          ],
        ),
      ),
    ),
    CatalogEntry(
      name: 'AppBarLeading',
      group: _appBar,
      source: 'lib/app/widgets/appbar_widgets/app_bar_leading.dart',
      note: 'Hidden unless Navigator.canPop is true; isForcefullyShow overrides.',
      demo: (context) =>
          AppBarLeading(isForcefullyShow: true, onLeadingTap: () {}),
    ),
    CatalogEntry(
      name: 'AppStatusBar',
      group: _appBar,
      source: 'lib/app/widgets/appbar_widgets/app_status_bar.dart',
      note: 'Styles the system bars through AnnotatedRegion — no box of its '
          'own, and the innermost region on screen wins.',
      demo: (context) => AppStatusBar.darkIcons(
        child: Container(
          height: R.h(40),
          alignment: Alignment.center,
          color: DsRole.surfaceMuted(),
          child: Text('wrapped subtree', style: CustomTextStyles.regular12),
        ),
      ),
    ),

    // Buttons
    CatalogEntry(
      name: 'CustomButton',
      group: _buttons,
      source: 'lib/app/widgets/buttons/custom_primary_button.dart',
      note: 'onPressed: null and loading: true both render the disabled fill.',
      demo: (context) => _wrap([
        CustomButton(text: 'Primary', onPressed: () {}),
        CustomButton(
          text: 'With icon',
          onPressed: () {},
          icon: Icon(
            LucideIcons.check,
            size: R.w(DsIconSize.sm),
            color: DsRole.onAccent(),
          ),
        ),
        CustomButton(text: 'Loading', onPressed: () {}, loading: true),
        const CustomButton(text: 'Disabled', onPressed: null),
      ]),
    ),
    CatalogEntry(
      name: 'CustomOutlinedButton',
      group: _buttons,
      source: 'lib/app/widgets/buttons/custom_primary_button.dart',
      note: 'width defaults to double.infinity — constrain it inside a Row.',
      demo: (context) => _wrap([
        CustomOutlinedButton(
          text: 'Secondary',
          onPressed: () {},
          width: R.w(150),
        ),
        CustomOutlinedButton(
          text: 'Danger',
          onPressed: () {},
          width: R.w(150),
          borderColor: DsRole.danger(),
          textColor: DsRole.danger(),
        ),
        CustomOutlinedButton(
          text: 'Icon right',
          onPressed: () {},
          width: R.w(150),
          iconRight: true,
          icon: Icon(
            LucideIcons.chevronRight,
            size: R.w(DsIconSize.sm),
            color: DsRole.onSurface(),
          ),
        ),
      ]),
    ),

    // Feedback
    CatalogEntry(
      name: 'CustomSnackBar',
      group: _feedback,
      source: 'lib/app/widgets/feedback/custom_snack_bar.dart',
      demo: (context) => Column(
        children: SnackBarType.values
            .map(
              (type) => Padding(
                padding: R.pad(bottom: 8),
                child: CustomSnackBar(
                  title: type.name,
                  description: 'One line of supporting copy.',
                  type: type,
                ),
              ),
            )
            .toList(),
      ),
    ),
    CatalogEntry(
      name: 'showCustomSnackBar',
      group: _feedback,
      source: 'lib/app/widgets/feedback/custom_snack_bar.dart',
      note: 'Uses ScaffoldMessenger, so it needs a Scaffold above the context.',
      demo: (context) => _fit(
        CustomButton(
          text: 'Show snackbar',
          onPressed: () => showCustomSnackBar(
            context: context,
            type: SnackBarType.Success,
            title: 'Saved',
            description: 'Your changes are live.',
          ),
        ),
      ),
    ),
    CatalogEntry(
      name: 'showDeleteConfirmationDialog',
      group: _feedback,
      source: 'lib/app/widgets/feedback/delete_confirmation_dialog.dart',
      note: 'Copy defaults are null, not const, because `.tr` is not const.',
      demo: (context) => _fit(
        CustomButton(
          text: 'Confirm delete',
          onPressed: () => showDeleteConfirmationDialog(onConfirm: () {}),
        ),
      ),
    ),
    CatalogEntry(
      name: 'showSuccessDialog',
      group: _feedback,
      source: 'lib/app/widgets/feedback/success_dialog.dart',
      note: 'buttonText and onPressed are accepted but never rendered — pass '
          'your own button as `widget:`.',
      demo: (context) => _fit(
        CustomButton(
          text: 'Show success',
          onPressed: () => showSuccessDialog(
            context,
            icon: LucideIcons.circleCheck,
            title: 'Order placed',
            message: 'We sent the receipt to your email.',
          ),
        ),
      ),
    ),
    CatalogEntry(
      name: 'StatusBadge',
      group: _feedback,
      source: 'lib/app/widgets/feedback/status_badge.dart',
      note: 'StatusBadge.fromStatus maps an API string onto a tone and '
          'uppercases the label.',
      demo: (context) => _wrap([
        ...StatusTone.values.map(
          (tone) => StatusBadge(label: tone.name, tone: tone),
        ),
        StatusBadge.fromStatus('out_for_delivery'),
      ]),
    ),
    CatalogEntry(
      name: 'StripedProgressBar',
      group: _feedback,
      source: 'lib/app/widgets/feedback/striped_progress_bar.dart',
      note: 'width and height are raw logical px — scale them yourself.',
      demo: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedProgressBar(
            width: R.w(240),
            height: R.h(10),
            percent: 35,
          ),
          SizedBox(height: R.h(DsSpace.sm)),
          StripedProgressBar(
            width: R.w(240),
            height: R.h(16),
            percent: 80,
            fillColor: DsRole.success(),
          ),
        ],
      ),
    ),
    CatalogEntry(
      name: 'ThinkingDots',
      group: _feedback,
      source: 'lib/app/widgets/feedback/thinking_dots.dart',
      demo: (context) => const ThinkingDots(title: 'Thinking'),
    ),

    // Inputs
    CatalogEntry(
      name: 'CustomTextField',
      group: _inputs,
      source: 'lib/app/widgets/inputs/custom_text_field.dart',
      note: 'Email and name keyboards get a hard 60-char formatter; autofill '
          'hints only fire inside an AutofillGroup.',
      demo: (context) => Column(
        children: [
          CustomTextField(
            textHeading: 'Full name',
            required: true,
            hintText: 'Ada Lovelace',
            controller: c.demoText,
            inputType: TextInputType.name,
          ),
          SizedBox(height: R.h(DsSpace.md)),
          CustomTextField(
            textHeading: 'Password',
            isPassword: true,
            hintText: 'Password',
            controller: c.demoPassword,
          ),
          SizedBox(height: R.h(DsSpace.md)),
          CustomTextField(
            textHeading: 'Notes',
            maxLines: 3,
            hintText: 'Multiline',
            controller: c.demoNotes,
          ),
          SizedBox(height: R.h(DsSpace.md)),
          const CustomTextField(hintText: 'Disabled', isEnabled: false),
        ],
      ),
    ),
    CatalogEntry(
      name: 'CustomPhoneTextField',
      group: _inputs,
      source: 'lib/app/widgets/inputs/custom_phone_text_field.dart',
      note: 'Emits the dial code separately via onCountryChanged — store both.',
      demo: (context) => CustomPhoneTextField(
        textHeading: 'Phone',
        controller: c.demoPhone,
        onPhoneChanged: (value) {},
      ),
    ),
    CatalogEntry(
      name: 'CustomCountryPicker',
      group: _inputs,
      source: 'lib/app/widgets/inputs/custom_country_picker.dart',
      note: 'Opens an Overlay anchored to the field, not a route — it closes '
          'on scroll.',
      demo: (context) => CustomCountryPicker(
        textHeading: 'Country',
        filled: true,
        onCountryChanged: (country) {},
      ),
    ),
    CatalogEntry(
      name: 'CustomSelectSection',
      group: _inputs,
      source: 'lib/app/widgets/inputs/custom_single_and_multi_selection.dart',
      note: 'Generic over the id type; items is a {id: label} map.',
      demo: (context) => Column(
        children: [
          Obx(
            () => CustomSelectSection<int>(
              hintText: 'Pick one',
              labelText: 'Single',
              items: const {1: 'Ada', 2: 'Grace', 3: 'Katherine'},
              selectedItems: c.demoSelection.toList(),
              onChangedSelection: (values) =>
                  c.demoSelection.value = values,
            ),
          ),
          SizedBox(height: R.h(DsSpace.md)),
          Obx(
            () => CustomSelectSection<int>(
              hintText: 'Pick several',
              labelText: 'Multi + search',
              selectionMode: SelectionMode.multi,
              searchRequired: true,
              items: const {1: 'Ada', 2: 'Grace', 3: 'Katherine', 4: 'Radia'},
              selectedItems: c.demoMultiSelection.toList(),
              onChangedSelection: (values) =>
                  c.demoMultiSelection.value = values,
            ),
          ),
        ],
      ),
    ),
    CatalogEntry(
      name: 'DatePickerButton',
      group: _inputs,
      source: 'lib/app/widgets/inputs/date_time_picker.dart',
      note: 'The Material date picker needs GlobalMaterialLocalizations — '
          'already wired in app.dart.',
      demo: (context) => Obx(
        () => DatePickerButton(
          text: c.demoDate.value == null
              ? 'Pick a date'
              : c.demoDate.value!.toIso8601String().split('T').first,
          icon: LucideIcons.calendarDays,
          style: CustomButtonStyle.outlinedIcon,
          width: R.w(200),
          height: R.h(40),
          onDatePicked: (date) => c.demoDate.value = date,
        ),
      ),
    ),
    CatalogEntry(
      name: 'FileUploadWidget',
      group: _inputs,
      source: 'lib/app/widgets/inputs/file_upload_widget.dart',
      note: 'Tapping opens the real system picker; it returns a dart:io File.',
      demo: (context) => Obx(
        () => FileUploadWidget(
          title: 'Attachment',
          required: true,
          selectedFile: c.demoFile.value,
          onFilePicked: (file) => c.demoFile.value = file,
        ),
      ),
    ),

    // Layout
    CatalogEntry(
      name: 'CardContainer',
      group: _layout,
      source: 'lib/app/widgets/layout/layout_components.dart',
      demo: (context) => CardContainer(
        boxShadow: DsElevation.medium.value,
        child: Text('Card body', style: CustomTextStyles.regular14),
      ),
    ),
    CatalogEntry(
      name: 'SectionHeader',
      group: _layout,
      source: 'lib/app/widgets/layout/layout_components.dart',
      demo: (context) => SectionHeader(
        title: 'Recent orders',
        subtitle: '3 open',
        trailing: Text(
          'See all',
          style: CustomTextStyles.medium12.copyWith(color: DsRole.accent()),
        ),
      ),
    ),
    CatalogEntry(
      name: 'CustomDivider',
      group: _layout,
      source: 'lib/app/widgets/layout/layout_components.dart',
      note: 'Defaults to Colors.grey[300] — pass color: for a themed rule.',
      demo: (context) => Column(
        children: [
          Text('above', style: CustomTextStyles.regular12),
          CustomDivider(color: DsRole.border()),
          Text('below', style: CustomTextStyles.regular12),
        ],
      ),
    ),
    CatalogEntry(
      name: 'CustomTextRow',
      group: _layout,
      source: 'lib/app/widgets/layout/custom_text_row.dart',
      demo: (context) =>
          const CustomTextRow(label: 'Order total', value: '42.00 USD'),
    ),
    CatalogEntry(
      name: 'LoadingWidget',
      group: _layout,
      source: 'lib/app/widgets/layout/layout_components.dart',
      demo: (context) => LoadingWidget(message: 'Loading orders'),
    ),
    CatalogEntry(
      name: 'EmptyStateWidget',
      group: _layout,
      source: 'lib/app/widgets/layout/layout_components.dart',
      note: 'Centres itself in whatever box it gets. A fixed height overflows '
          'once the text scales — let it shrink-wrap, or give it Expanded.',
      demo: (context) => EmptyStateWidget(
        icon: LucideIcons.inbox,
        title: 'Nothing here yet',
        subtitle: 'Orders you place will show up on this screen.',
        action: _fit(CustomButton(text: 'Refresh', onPressed: () {})),
      ),
    ),
    CatalogEntry(
      name: 'showCustomBottomSheet',
      group: _layout,
      source: 'lib/app/widgets/layout/custom_bottom_sheet.dart',
      note: 'Reads Get.context! internally, so it cannot run before the first '
          'frame.',
      demo: (context) => _fit(
        CustomButton(
          text: 'Open sheet',
          onPressed: () => showCustomBottomSheet(
            sheetTitle: 'Sheet title',
            content: Padding(
              padding: R.pad(all: 16),
              child: Text('Sheet body', style: CustomTextStyles.regular14),
            ),
          ),
        ),
      ),
    ),

    // Media
    CatalogEntry(
      name: 'CustomImage',
      group: _media,
      source: 'lib/app/widgets/media/custom_image.dart',
      note: 'An existing local path wins over imageType; an empty string or a '
          'load error falls back to placeholderIcon.',
      demo: (context) => _wrap([
        CustomImage(
          image: ImageUtils.appLogo,
          imageType: ImageType.asset,
          isSvg: true,
          height: R.w(64),
          width: R.w(64),
        ),
        CustomImage(
          image: '',
          height: R.w(64),
          width: R.w(64),
          borderRadius: R.r(DsRadius.md),
          placeholderIcon: LucideIcons.image,
        ),
        CustomImage(
          image: ImageUtils.appLogo,
          imageType: ImageType.asset,
          isSvg: true,
          circular: true,
          showBorder: true,
          borderColor: DsRole.accent(),
          height: R.w(64),
          width: R.w(64),
        ),
      ]),
    ),

    // Pagination
    CatalogEntry(
      name: 'PaginationView',
      group: _pagination,
      source: 'lib/app/widgets/pagination/pagination_view.dart',
      note: 'Needs a PaginationHelper whose fetchFunction is set; this demo '
          'returns six fake rows.',
      demo: (context) => SizedBox(
        height: R.h(200),
        child: PaginationView<String>(
          helper: c.demoFeed,
          itemBuilder: (item) => CustomTextRow(label: item, value: 'ready'),
        ),
      ),
    ),
    CatalogEntry(
      name: 'PaginationGridView',
      group: _pagination,
      source: 'lib/app/widgets/pagination/pagination_view.dart',
      note: 'Same helper, grid layout; its itemBuilder also receives the index.',
      demo: (context) => SizedBox(
        height: R.h(220),
        child: PaginationGridView<String>(
          helper: c.demoFeed,
          crossAxisCount: 3,
          childAspectRatio: 1,
          itemBuilder: (item, index) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DsRole.surfaceMuted(),
              borderRadius: BorderRadius.circular(R.r(DsRadius.md)),
            ),
            child: Text('$index', style: CustomTextStyles.medium14),
          ),
        ),
      ),
    ),
  ];

  static Widget _wrap(List<Widget> children) => Wrap(
    spacing: R.w(DsSpace.sm),
    runSpacing: R.h(DsSpace.sm),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );

  // Row + MainAxisSize.min hands the child unbounded width, so a button sizes
  // to its label instead of a guessed box that overflows at 2.0x text scale.
  static Widget _fit(Widget child) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [child],
  );
}
