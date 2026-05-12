import '../models/user.dart';

class UserRoles {
  UserRoles._();

  static const String admin = 'admin';
  static const String passportClerk = 'passport_clerk';
  static const String fieldEngineer = 'field_engineer';

  static String normalize(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'admin':
        return admin;
      case 'dispatcher':
      case 'passport_clerk':
        return passportClerk;
      case 'engineer':
      case 'field_engineer':
        return fieldEngineer;
      default:
        return fieldEngineer;
    }
  }

  static bool canExportCim(User u) =>
      u.isSuperuser || {admin, passportClerk}.contains(normalize(u.role));

  static bool canMutateEquipmentCatalog(User u) => canExportCim(u);
}
