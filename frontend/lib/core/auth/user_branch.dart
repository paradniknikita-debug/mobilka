import '../services/auth_service.dart';

/// branch_id из профиля авторизованного пользователя; иначе [fallback].
int branchIdFromAuthState(AuthState auth, {int fallback = 1}) {
  if (auth is AuthStateAuthenticated) {
    final bid = auth.user.branchId;
    if (bid != null && bid > 0) return bid;
  }
  return fallback;
}
