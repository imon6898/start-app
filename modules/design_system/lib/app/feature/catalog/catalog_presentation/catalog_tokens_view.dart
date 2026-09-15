import 'package:flutter/material.dart';
import 'package:flutter_starter/app/themes/tokens/tokens.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

/// The token gallery: every entry of tokens.json rendered as the thing it
/// controls. Reads the generated maps, so a new token shows up here for free.
class CatalogTokensView extends StatelessWidget {
  const CatalogTokensView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: R.pad(top: 12, bottom: 32),
      children: [
        _meta(),
        SectionHeader(title: 'Colour roles (${DsRole.all.length})'),
        _card(
          child: _swatches(
            {for (final e in DsRole.all.entries) e.key: e.value()},
            subtitle: 'Aliases of CustomColors — the hex lives in '
                'app_colors.dart.',
          ),
        ),
        SectionHeader(title: 'Palette roles (${DsPalette.all.length})'),
        _card(
          child: _swatches(
            {for (final e in DsPalette.all.entries) e.key: e.value.value},
            subtitle: 'Light/dark pairs the core palette has no method for.',
          ),
        ),
        SectionHeader(title: 'Spacing'),
        _card(child: _spacing()),
        SectionHeader(title: 'Radius'),
        _card(child: _radius()),
        SectionHeader(title: 'Elevation'),
        _card(child: _elevation()),
        SectionHeader(title: 'Motion'),
        _card(child: _motion()),
        SectionHeader(title: 'Border width'),
        _card(child: _borders()),
        SectionHeader(title: 'Opacity'),
        _card(child: _opacity()),
        SectionHeader(title: 'Icon size'),
        _card(child: _iconSizes()),
      ],
    );
  }

  Widget _meta() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tokens.json v${DsTokenMeta.version}',
            style: CustomTextStyles.semiBold14.copyWith(
              color: DsRole.onSurface(),
            ),
          ),
          SizedBox(height: R.h(DsSpace.xxs)),
          _caption(DsTokenMeta.source),
          SizedBox(height: R.h(DsSpace.xs)),
          _caption(
            'Edit the JSON, then: dart run tool/gen_tokens.dart. '
            'Reachable as DsSpace.lg or context.ds.space(\'lg\').',
          ),
        ],
      ),
    );
  }

  Widget _swatches(Map<String, Color> colors, {required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption(subtitle),
        SizedBox(height: R.h(DsSpace.md)),
        Wrap(
          spacing: R.w(DsSpace.sm),
          runSpacing: R.h(DsSpace.md),
          children: colors.entries
              .map((e) => _swatch(e.key, e.value))
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _swatch(String name, Color color) {
    return SizedBox(
      width: R.w(92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: R.h(44),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(R.r(DsRadius.sm)),
              border: Border.all(
                color: DsRole.border(),
                width: DsBorderWidth.hairline,
              ),
            ),
          ),
          SizedBox(height: R.h(DsSpace.xxs)),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CustomTextStyles.medium10.copyWith(
              color: DsRole.onSurface(),
            ),
          ),
          _caption(_hex(color)),
        ],
      ),
    );
  }

  Widget _spacing() {
    return Column(
      children: DsSpace.all.entries
          .map(
            (e) => Padding(
              padding: R.pad(bottom: 6),
              child: Row(
                children: [
                  _name(e.key, e.value),
                  Container(
                    width: R.w(e.value == 0 ? 1 : e.value),
                    height: R.h(12),
                    color: DsRole.accent(),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _radius() {
    return Wrap(
      spacing: R.w(DsSpace.sm),
      runSpacing: R.h(DsSpace.sm),
      children: DsRadius.all.entries
          .map(
            (e) => Column(
              children: [
                Container(
                  width: R.w(56),
                  height: R.h(44),
                  decoration: BoxDecoration(
                    color: DsRole.surfaceMuted(),
                    borderRadius: BorderRadius.circular(R.r(e.value)),
                    border: Border.all(
                      color: DsRole.border(),
                      width: DsBorderWidth.thin,
                    ),
                  ),
                ),
                SizedBox(height: R.h(DsSpace.xxs)),
                _caption('${e.key} ${_px(e.value)}'),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _elevation() {
    return Wrap(
      spacing: R.w(DsSpace.lg),
      runSpacing: R.h(DsSpace.lg),
      children: DsElevation.all.entries
          .map(
            (e) => Column(
              children: [
                Container(
                  width: R.w(72),
                  height: R.h(48),
                  decoration: BoxDecoration(
                    color: DsPalette.surfaceRaised.value,
                    borderRadius: BorderRadius.circular(R.r(DsRadius.md)),
                    boxShadow: e.value.value,
                  ),
                ),
                SizedBox(height: R.h(DsSpace.sm)),
                _caption(e.key),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _motion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('Tap a row to play it.'),
        SizedBox(height: R.h(DsSpace.sm)),
        ...DsMotion.all.entries.map(
          (e) => _MotionSample(name: e.key, token: e.value),
        ),
      ],
    );
  }

  Widget _borders() {
    return Column(
      children: DsBorderWidth.all.entries
          .map(
            (e) => Padding(
              padding: R.pad(bottom: 8),
              child: Row(
                children: [
                  _name(e.key, e.value),
                  Expanded(
                    child: Container(
                      height: e.value,
                      color: DsRole.onSurface(),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _opacity() {
    return Wrap(
      spacing: R.w(DsSpace.sm),
      runSpacing: R.h(DsSpace.sm),
      children: DsOpacity.all.entries
          .map(
            (e) => Column(
              children: [
                Container(
                  width: R.w(56),
                  height: R.h(36),
                  decoration: BoxDecoration(
                    color: DsRole.accent().withValues(alpha: e.value),
                    borderRadius: BorderRadius.circular(R.r(DsRadius.sm)),
                  ),
                ),
                SizedBox(height: R.h(DsSpace.xxs)),
                _caption('${e.key} ${e.value}'),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _iconSizes() {
    return Wrap(
      spacing: R.w(DsSpace.md),
      runSpacing: R.h(DsSpace.sm),
      crossAxisAlignment: WrapCrossAlignment.end,
      children: DsIconSize.all.entries
          .map(
            (e) => Column(
              children: [
                Icon(
                  Icons.square_rounded,
                  size: R.w(e.value),
                  color: DsRole.onSurfaceMuted(),
                ),
                SizedBox(height: R.h(DsSpace.xxs)),
                _caption('${e.key} ${_px(e.value)}'),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  // Fixed-width label so the samples next to it line up.
  Widget _name(String name, double value) => SizedBox(
    width: R.w(96),
    child: Text(
      '$name  ${_px(value)}',
      style: CustomTextStyles.regular10.copyWith(
        color: DsRole.onSurfaceMuted(),
      ),
    ),
  );

  Widget _caption(String text) => Text(
    text,
    style: CustomTextStyles.regular10.copyWith(color: DsRole.onSurfaceMuted()),
  );

  Widget _card({required Widget child}) => CardContainer(
    margin: R.margin(horizontal: 16, bottom: 12),
    padding: R.pad(all: 14),
    backgroundColor: DsRole.surface(),
    borderRadius: R.r(DsRadius.lg),
    boxShadow: DsElevation.low.value,
    child: SizedBox(width: double.infinity, child: child),
  );

  static String _px(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  static String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// One motion token, replayed on tap so the duration and curve are felt.
class _MotionSample extends StatefulWidget {
  final String name;
  final DsMotionToken token;

  const _MotionSample({required this.name, required this.token});

  @override
  State<_MotionSample> createState() => _MotionSampleState();
}

class _MotionSampleState extends State<_MotionSample> {
  bool _far = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _far = !_far),
      child: Padding(
        padding: R.pad(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: R.w(96),
              child: Text(
                '${widget.name}  ${widget.token.duration.inMilliseconds}ms',
                style: CustomTextStyles.regular10.copyWith(
                  color: DsRole.onSurfaceMuted(),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: R.h(24),
                decoration: BoxDecoration(
                  color: DsPalette.surfaceSunken.value,
                  borderRadius: BorderRadius.circular(R.r(DsRadius.pill)),
                ),
                child: AnimatedAlign(
                  alignment: _far ? Alignment.centerRight : Alignment.centerLeft,
                  duration: widget.token.duration,
                  curve: widget.token.curve,
                  child: Container(
                    width: R.w(24),
                    height: R.h(24),
                    decoration: BoxDecoration(
                      color: DsRole.accent(),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
