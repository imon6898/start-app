import 'package:flutter/material.dart';
import 'package:flutter_starter/app/feature/notes/notes_controllers/notes_controller.dart';
import 'package:flutter_starter/app/feature/notes/notes_models/note_model.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/delete_confirmation_dialog.dart';
import 'package:flutter_starter/app/widgets/feedback/sync_status_banner.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';
import 'package:flutter_starter/app/widgets/layout/layout_components.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Worked example: list, create and delete while offline. Pull down to sync.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotesController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: AppBarWidget(title: 'Notes'.tr),
          body: Column(
            children: [
              const SyncStatusBanner(showWhenIdle: true),
              _composer(context, c),
              Expanded(child: _list(context, c)),
            ],
          ),
        );
      },
    );
  }

  Widget _composer(BuildContext context, NotesController controller) {
    return Padding(
      padding: R.pad(horizontal: 16, vertical: 12),
      child: Form(
        key: controller.formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CustomTextField(
                controller: controller.titleController,
                hintText: 'Note title'.tr,
              ),
            ),
            SizedBox(width: R.w(8)),
            CustomButton(
              text: 'Save'.tr,
              height: 44,
              onPressed: () {
                FocusScope.of(context).unfocus();
                controller.addNote();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, NotesController controller) {
    return RefreshIndicator(
      onRefresh: controller.refreshNotes,
      child: Obx(() {
        if (controller.notes.isEmpty) {
          return ListView(
            children: [
              SizedBox(height: R.h(80)),
              EmptyStateWidget(
                icon: LucideIcons.stickyNote,
                title: 'No notes yet'.tr,
                subtitle: 'Add one — it will sync when you are back online'.tr,
              ),
            ],
          );
        }
        return ListView.separated(
          padding: R.pad(horizontal: 16, bottom: 24),
          itemCount: controller.notes.length,
          separatorBuilder: (_, _) => SizedBox(height: R.h(8)),
          itemBuilder: (_, index) => _tile(controller, controller.notes[index]),
        );
      }),
    );
  }

  Widget _tile(NotesController controller, NoteModel note) {
    return CardContainer(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title ?? '',
                  style: CustomTextStyles.semiBold14.copyWith(
                    color: CustomColors.textPrimary(),
                  ),
                ),
                if ((note.body ?? '').isNotEmpty) ...[
                  SizedBox(height: R.h(4)),
                  Text(
                    note.body!,
                    style: CustomTextStyles.regular12.copyWith(
                      color: CustomColors.paragraph(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Unsent rows are shown, never hidden — the user should know.
          if (note.pending)
            Padding(
              padding: R.pad(right: 8),
              child: Icon(
                LucideIcons.clock,
                size: R.sp(14),
                color: CustomColors.warning(),
              ),
            ),
          GestureDetector(
            onTap: () => showDeleteConfirmationDialog(
              onConfirm: () => controller.deleteNote(note),
            ),
            child: Icon(
              LucideIcons.trash2,
              size: R.sp(18),
              color: CustomColors.error(),
            ),
          ),
        ],
      ),
    );
  }
}
