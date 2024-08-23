import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:m360_career_backend/configs/constants.dart';
import 'package:shelf/shelf.dart';

String? extractToken(Request request) {
  try{
    final authorization = request.headers['Authorization'];
    if (authorization != null && authorization.startsWith("Bearer ")) {
      return authorization.substring(7);
    } else {
      return null;
    }
  }catch(e){
    print("extractToken e: $e");
    return null;
  }
}

String hashString(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

String generateAccessToken(Map<String, dynamic> payload) {
  final jwt = JWT(payload);
  return jwt.sign(SecretKey(kSecreteKey));
}

String generateRefreshToken(int userId) {
  final jwt = JWT({"user_id": userId});
  return jwt.sign(SecretKey(kRefreshSecreteKey));
}
