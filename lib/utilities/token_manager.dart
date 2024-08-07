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

