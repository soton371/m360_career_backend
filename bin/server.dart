import 'dart:io';
import 'package:m360_career_backend/configs/configs.dart';
import 'package:m360_career_backend/middleware/middleware.dart';
import 'package:m360_career_backend/routes/routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  await DBConfig.connection.then((connection) async {

    final router = Router();
    router.mount('/api', AuthRoutes(connection).router.call);

    // Configure a pipeline that logs requests.
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(AuthMiddleware.checkAuthentication())
        .addHandler(router.call);

    // For running in containers, we respect the PORT environment variable.
    final port = int.parse(Platform.environment['PORT'] ?? '8080');
    final server = await serve(handler, ip, port);
    print('Server listening on port ${server.port}');
  });
}