import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

import '../handlers/handlers.dart';

class AuthRoutes{

  final Connection connection;
  AuthRoutes(this.connection);

  AuthHandler get _authHandler => AuthHandler(connection);

  Router get router => Router()
    ..post('/auth/login', _authHandler.login)
    ..post('/auth/send_otp', _authHandler.sendOtp)
    ..post('/auth/match_otp', _authHandler.matchOtp)
    ..put('/auth/reset_password', _authHandler.resetPassword)
    ..put('/auth/change_password', _authHandler.changePassword)
    ..post('/auth/refresh_token', _authHandler.refreshToken)
    ..post('/auth/registration', _authHandler.register);
}
