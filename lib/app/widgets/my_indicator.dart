import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/constants/app_colors.dart';
import '../utils/responsive_utils.dart';

enum IndicatorStatus {
  none,
  loadingMoreBusying,
  fullScreenBusying,
  error,
  fullScreenError,
  noMoreLoad,
  empty,
}

class MyIndicator extends StatelessWidget {
  const MyIndicator(
    this.status, {
    super.key,
    this.tryAgain,
    this.isSliver = false,
    this.emptyWidget,
    this.lastMessageStatus,
  });

  ///Status of indicator
  final IndicatorStatus status;

  ///call back of loading failed
  final Function? tryAgain;

  ///whether it need sliver as container
  final bool isSliver;

  ///emppty widget
  final Widget? emptyWidget;

  ///last message status
  final String? lastMessageStatus;
  @override
  @override
  Widget build(BuildContext context) {
    Widget? widget;
    switch (status) {
      case IndicatorStatus.none:
        widget = Container(height: 0.0);
        break;
      case IndicatorStatus.loadingMoreBusying:
        widget = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(right: 5.0),
              height: 15.0,
              width: 15.0,
              child: getIndicator(context),
            ),
            SizedBox(width: R.w(10)),
            Text(
              'Loading...',
              style: TextStyle(color: CustomColors.black()),
            ),
          ],
        );
        widget = _setbackground(false, widget, 35.0);
        break;
      case IndicatorStatus.fullScreenBusying:
        widget = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(right: 0.0),
              height: 30.0,
              width: 30.0,
              child: getIndicator(context),
            ),
            SizedBox(width: R.w(10)),
            Text(
              'Loading...',
              style: TextStyle(color: CustomColors.black()),
            ),
          ],
        );
        widget = _setbackground(true, widget, double.infinity);
        if (isSliver) {
          widget = SliverFillRemaining(child: widget);
        } else {
          widget = CustomScrollView(
            slivers: <Widget>[SliverFillRemaining(child: widget)],
          );
        }
        break;
      case IndicatorStatus.error:
        widget = Text(
          'No data found to load',
          style: TextStyle(color: CustomColors.black()),
        );
        widget = _setbackground(false, widget, 35.0);
        if (tryAgain != null) {
          widget = GestureDetector(
            onTap: () {
              tryAgain!();
            },
            child: widget,
          );
        }
        break;
      case IndicatorStatus.fullScreenError:
        widget = Text(
          'Failed to load data',
          style: TextStyle(color: CustomColors.black()),
        );
        widget = _setbackground(true, widget, double.infinity);
        if (tryAgain != null) {
          widget = GestureDetector(
            onTap: () {
              tryAgain!();
            },
            child: widget,
          );
        }
        if (isSliver) {
          widget = SliverFillRemaining(child: widget);
        } else {
          widget = CustomScrollView(
            slivers: <Widget>[SliverFillRemaining(child: widget)],
          );
        }
        break;
      case IndicatorStatus.noMoreLoad:
        widget = Text(
          lastMessageStatus ?? '',
          style: TextStyle(color: CustomColors.black()),
        );
        widget = _setbackground(false, widget, 35.0);
        break;
      case IndicatorStatus.empty:
        widget = emptyWidget ?? Text(('No data found'));
        widget = _setbackground(true, widget, double.infinity);
        if (isSliver) {
          widget = SliverFillRemaining(child: widget);
        } else {
          widget = CustomScrollView(
            slivers: <Widget>[SliverFillRemaining(child: widget)],
          );
        }
        break;
    }
    return widget;
  }

  Widget _setbackground(bool full, Widget widget, double height) {
    widget = Container(
      width: full ? double.infinity : null,
      height: height,
      color: CustomColors.transparent(),
      constraints: full ? null : const BoxConstraints(maxWidth: 200),
      alignment: Alignment.center,
      child: widget,
    );
    return widget;
  }

  Widget getIndicator(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.platform == TargetPlatform.iOS
        ? const CupertinoActivityIndicator(animating: true, radius: 16.0)
        : CircularProgressIndicator(
            strokeWidth: 2.0,
            color: CustomColors.primary(),
            // valueColor: AlwaysStoppedAnimation<Color>(colorPrimary),
          );
  }
}
