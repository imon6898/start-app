import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_starter/app/core/enums/socket_status.dart';
import 'package:flutter_starter/app/feature/realtime/realtime_controllers/realtime_demo_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/status_badge.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';

/// Badge colour per connection state.
StatusTone _toneFor(SocketStatus status) => switch (status) {
  SocketStatus.connected => StatusTone.success,
  SocketStatus.connecting || SocketStatus.reconnecting => StatusTone.warning,
  SocketStatus.error => StatusTone.danger,
  SocketStatus.idle || SocketStatus.disconnected => StatusTone.neutral,
};

/// Example screen: shows the live status, subscribes and emits.
class RealtimeDemoScreen extends StatelessWidget {
  const RealtimeDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RealtimeDemoController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'Realtime'.tr,
              backgroundColor: CustomColors.transparent(),
              elevation: 0,
              toolbarActions: [
                IconButton(
                  onPressed: c.clearFeed,
                  icon: Icon(
                    LucideIcons.trash2,
                    size: R.w(20),
                    color: CustomColors.textGray(),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildStatusCard(context, c),
                Expanded(child: _buildFeed(context, c)),
                _buildComposer(context, c),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, RealtimeDemoController c) {
    return CardContainer(
      margin: R.pad(horizontal: 16, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Obx(
                () => StatusBadge(
                  label: c.status.value.label.tr.toUpperCase(),
                  tone: _toneFor(c.status.value),
                ),
              ),
              const Spacer(),
              Obx(
                () => Text(
                  c.status.value.isConnecting &&
                          c.socket.reconnectAttempts.value > 0
                      ? '${'Attempt'.tr} ${c.socket.reconnectAttempts.value}'
                      : c.socket.socketId ?? '—',
                  style: CustomTextStyles.regular12.copyWith(
                    color: CustomColors.textGray(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: R.h(8)),
          Text(
            c.socket.resolvedUrl.isEmpty
                ? 'SOCKET_URL is not set in .env'.tr
                : c.socket.resolvedUrl,
            style: CustomTextStyles.regular12.copyWith(
              color: CustomColors.paragraph(),
            ),
          ),
          Obx(() {
            final String error = c.socket.lastError.value;
            if (error.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: R.pad(top: 6),
              child: Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.error(),
                ),
              ),
            );
          }),
          SizedBox(height: R.h(12)),
          Row(
            children: [
              Expanded(
                child: CustomOutlinedButton(
                  text: 'Reconnect'.tr,
                  height: 44,
                  onPressed: c.reconnect,
                ),
              ),
              SizedBox(width: R.w(12)),
              Expanded(
                child: Obx(
                  () => CustomButton(
                    text: 'Ping'.tr,
                    height: 44,
                    loading: c.isLoadingPing.value,
                    onPressed: () => c.sendPing(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(BuildContext context, RealtimeDemoController c) {
    return Obx(() {
      if (c.feed.isEmpty) {
        return EmptyStateWidget(
          icon: LucideIcons.radioTower,
          title: 'No events yet'.tr,
          subtitle: 'Incoming socket events show up here.'.tr,
        );
      }
      return ListView.separated(
        padding: R.pad(horizontal: 16, vertical: 12),
        itemCount: c.feed.length,
        separatorBuilder: (_, _) => SizedBox(height: R.h(6)),
        itemBuilder: (context, index) => Text(
          c.feed[index],
          style: CustomTextStyles.regular12.copyWith(
            color: CustomColors.paragraph(),
          ),
        ),
      );
    });
  }

  Widget _buildComposer(BuildContext context, RealtimeDemoController c) {
    return Padding(
      padding: R.pad(horizontal: 16, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: CustomTextField(
              controller: c.messageController,
              hintText: 'Type a message'.tr,
              inputAction: TextInputAction.send,
              onSubmit: (_) => c.sendMessage(context),
            ),
          ),
          SizedBox(width: R.w(12)),
          CustomButton(
            text: 'Send'.tr,
            height: 48,
            onPressed: () => c.sendMessage(context),
          ),
        ],
      ),
    );
  }
}
