import 'models/session.dart';

sealed class AuthResult {
  const AuthResult();
}

final class AuthSuccess extends AuthResult {
  final AppSession session;
  const AuthSuccess(this.session);
}

final class AuthFailure extends AuthResult {
  final String message;
  const AuthFailure(this.message);
}
