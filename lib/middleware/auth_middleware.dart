import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../configs/configs.dart';
import '../models/models.dart';
import '../utilities/utilities.dart';

class AuthMiddleware {
  static Middleware checkAuthentication() => (innerHandler) {
    return (request) {
      if (request.url != Uri.parse("api/auth/login") &&
          request.url != Uri.parse("api/auth/registration")&&
          request.url != Uri.parse("api/auth/match_otp")&&
          request.url != Uri.parse("api/auth/refresh_token")&&
          request.url != Uri.parse("api/auth/google_sign_in")&&
          request.url != Uri.parse("api/auth/send_otp")) {
        final token = extractToken(request);
        if (token != null) {
          final verify = JWT.tryVerify(token, SecretKey(kSecreteKey));
          if (verify != null) {
            return innerHandler(request);
          }
        }
        return Response.unauthorized(responseModelToJson(ResponseModel(
            success: false,
            message: "Unauthorized request.",
            data: null)));
      } else {
        return innerHandler(request);
      }
    };
  };
}