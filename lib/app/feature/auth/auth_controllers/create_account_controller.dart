import 'package:get/get.dart';

enum AccountRole {user, rider, merchant }

class CreateAccountController extends GetxController {
  final Rx<AccountRole?> selectedRole = Rx<AccountRole?>(null);

  void selectRole(AccountRole role) {
    selectedRole.value = role;
    update();
  }

  bool get isRoleSelected => selectedRole.value != null;
}
