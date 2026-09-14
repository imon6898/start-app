import 'package:get/get.dart';

/// Example account types. Rename/extend for your app.
enum AccountRole { personal, business }

class CreateAccountController extends GetxController {
  final Rx<AccountRole?> selectedRole = Rx<AccountRole?>(null);

  void selectRole(AccountRole role) {
    selectedRole.value = role;
    update();
  }

  bool get isRoleSelected => selectedRole.value != null;
}
