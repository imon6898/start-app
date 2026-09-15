import 'package:flutter/material.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_controllers/chat_controller.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_message.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/thinking_dots.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: 'AI Assistant'.tr,
              backgroundColor: CustomColors.transparent(),
              toolbarActions: [
                IconButton(
                  onPressed: c.clear,
                  tooltip: 'Clear chat'.tr,
                  icon: Icon(
                    LucideIcons.trash2,
                    size: R.sp(20),
                    color: CustomColors.textGray(),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(child: _transcript(context, c)),
                _errorBar(context, c),
                _composer(context, c),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _transcript(BuildContext context, ChatController controller) {
    return Obx(() {
      final count = controller.messages.length;
      if (count == 0 && !controller.isStreaming.value) {
        return _emptyState(context);
      }
      return ListView.builder(
        controller: controller.scrollController,
        padding: R.pad(horizontal: 16, vertical: 12),
        itemCount: count + (controller.isStreaming.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= count) return _streamingBubble(context, controller);
          return _bubble(context, controller, index, controller.messages[index]);
        },
      );
    });
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: R.pad(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.sparkles,
              size: R.sp(40),
              color: CustomColors.primary(),
            ),
            SizedBox(height: R.h(12)),
            Text(
              'Ask anything'.tr,
              style: CustomTextStyles.semiBold16.copyWith(
                color: CustomColors.textPrimary(),
              ),
            ),
            SizedBox(height: R.h(6)),
            Text(
              'Replies stream in token by token.'.tr,
              textAlign: TextAlign.center,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.paragraph(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    ChatController controller,
    int index,
    ClaudeMessage message,
  ) {
    final isUser = message.role == ClaudeRole.user;
    // A tool-result turn is a user message with no prose — render it as a chip.
    if (isUser && message.text.isEmpty && message.toolResults.isNotEmpty) {
      return _toolChip(
        context,
        '${'Tool results'.tr} (${message.toolResults.length})',
      );
    }

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!isUser && message.thinking.isNotEmpty)
          _thinkingDisclosure(context, controller, index, message.thinking),
        Container(
          margin: R.margin(bottom: 10),
          padding: R.pad(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: R.w(290)),
          decoration: BoxDecoration(
            color: isUser ? CustomColors.primary() : CustomColors.card(),
            borderRadius: BorderRadius.circular(R.r(14)),
            border: isUser
                ? null
                : Border.all(color: CustomColors.stroke(), width: 1),
          ),
          child: Text(
            message.text.isEmpty ? '…' : message.text,
            style: CustomTextStyles.regular14.copyWith(
              color: isUser
                  ? CustomColors.textInverse()
                  : CustomColors.textPrimary(),
            ),
          ),
        ),
        for (final call in message.toolUses)
          _toolChip(context, '${'Used tool'.tr}: ${call.name}'),
        if (!isUser && message.text.isNotEmpty)
          _copyButton(context, controller, message.text),
      ],
    );
  }

  Widget _streamingBubble(BuildContext context, ChatController controller) {
    return Obx(() {
      final text = controller.streamingText.value;
      final thinking = controller.streamingThinking.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isEmpty)
            Padding(
              padding: R.pad(bottom: 8, left: 4),
              child: ThinkingDots(title: 'Thinking'.tr),
            ),
          if (thinking.isNotEmpty)
            Container(
              margin: R.margin(bottom: 6),
              padding: R.pad(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxWidth: R.w(290)),
              decoration: BoxDecoration(
                color: CustomColors.badgeBlueBg(),
                borderRadius: BorderRadius.circular(R.r(10)),
              ),
              child: Text(
                thinking,
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.badgeBlue(),
                ),
              ),
            ),
          if (text.isNotEmpty)
            Container(
              margin: R.margin(bottom: 10),
              padding: R.pad(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: R.w(290)),
              decoration: BoxDecoration(
                color: CustomColors.card(),
                borderRadius: BorderRadius.circular(R.r(14)),
                border: Border.all(color: CustomColors.stroke(), width: 1),
              ),
              // The block is the streaming cursor.
              child: Text(
                '$text▌',
                style: CustomTextStyles.regular14.copyWith(
                  color: CustomColors.textPrimary(),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _thinkingDisclosure(
    BuildContext context,
    ChatController controller,
    int index,
    String thinking,
  ) {
    return Obx(() {
      final expanded = controller.expandedThinking.contains(index);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => controller.toggleThinking(index),
            borderRadius: BorderRadius.circular(R.r(8)),
            child: Padding(
              padding: R.pad(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.brain,
                    size: R.sp(14),
                    color: CustomColors.textGray(),
                  ),
                  SizedBox(width: R.w(6)),
                  Text(
                    'Reasoning summary'.tr,
                    style: CustomTextStyles.medium12.copyWith(
                      color: CustomColors.textGray(),
                    ),
                  ),
                  SizedBox(width: R.w(4)),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: R.sp(14),
                    color: CustomColors.textGray(),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              margin: R.margin(bottom: 6),
              padding: R.pad(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxWidth: R.w(290)),
              decoration: BoxDecoration(
                color: CustomColors.badgeBlueBg(),
                borderRadius: BorderRadius.circular(R.r(10)),
              ),
              child: Text(
                thinking,
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.badgeBlue(),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _toolChip(BuildContext context, String label) {
    return Container(
      margin: R.margin(bottom: 10),
      padding: R.pad(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CustomColors.lightGrey(),
        borderRadius: BorderRadius.circular(R.r(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.wrench,
            size: R.sp(13),
            color: CustomColors.textGray(),
          ),
          SizedBox(width: R.w(6)),
          Text(
            label,
            style: CustomTextStyles.regular12.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyButton(
    BuildContext context,
    ChatController controller,
    String text,
  ) {
    return Padding(
      padding: R.pad(bottom: 10, left: 2),
      child: InkWell(
        onTap: () => controller.copy(context, text),
        borderRadius: BorderRadius.circular(R.r(8)),
        child: Padding(
          padding: R.pad(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.copy,
                size: R.sp(13),
                color: CustomColors.textGray(),
              ),
              SizedBox(width: R.w(5)),
              Text(
                'Copy'.tr,
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.textGray(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBar(BuildContext context, ChatController controller) {
    return Obx(() {
      final message = controller.errorMessage.value;
      if (message == null || message.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: R.margin(horizontal: 16, bottom: 8),
        padding: R.pad(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CustomColors.errorBg(),
          borderRadius: BorderRadius.circular(R.r(10)),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: R.sp(16),
              color: CustomColors.error(),
            ),
            SizedBox(width: R.w(8)),
            Expanded(
              child: Text(
                message,
                style: CustomTextStyles.regular12.copyWith(
                  color: CustomColors.error(),
                ),
              ),
            ),
            SizedBox(width: R.w(8)),
            InkWell(
              onTap: controller.retry,
              borderRadius: BorderRadius.circular(R.r(8)),
              child: Padding(
                padding: R.pad(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.rotateCcw,
                      size: R.sp(14),
                      color: CustomColors.error(),
                    ),
                    SizedBox(width: R.w(4)),
                    Text(
                      'Retry'.tr,
                      style: CustomTextStyles.medium12.copyWith(
                        color: CustomColors.error(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _composer(BuildContext context, ChatController controller) {
    return Container(
      padding: R.pad(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CustomColors.card(),
        border: Border(top: BorderSide(color: CustomColors.stroke())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CustomTextField(
              controller: controller.inputController,
              focusNode: controller.inputFocus,
              hintText: 'Message Claude…'.tr,
              maxLines: 4,
              miniLine: 1,
              filled: true,
              fillColor: CustomColors.artboardColor(),
              borderRadius: R.r(14),
            ),
          ),
          SizedBox(width: R.w(8)),
          Obx(
            () => controller.isStreaming.value
                ? CustomButton(
                    onPressed: controller.cancel,
                    height: 42,
                    borderRadius: R.r(14),
                    backgroundColor: CustomColors.error(),
                    padding: R.pad(horizontal: 10),
                    icon: Icon(
                      LucideIcons.circleStop,
                      size: R.sp(18),
                      color: CustomColors.white(),
                    ),
                  )
                : CustomButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      controller.send();
                    },
                    height: 42,
                    borderRadius: R.r(14),
                    padding: R.pad(horizontal: 10),
                    icon: Icon(
                      LucideIcons.send,
                      size: R.sp(18),
                      color: CustomColors.white(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
