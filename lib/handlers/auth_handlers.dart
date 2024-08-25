import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:m360_career_backend/configs/constants.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../models/models.dart';
import '../utilities/utilities.dart';

class AuthHandler {
  final Connection connection;

  AuthHandler(this.connection);

  //for login
  Future<Response> login(Request request) async {
    try {
      final req = userModelFromJson(await request.readAsString());

      final checkUser = await connection.execute(
          Sql.named(
              "SELECT * FROM users WHERE email=@email AND password=@password"),
          parameters: {
            "email": req.email,
            "password": hashString(req.password ?? '')
          });

      if (checkUser.isNotEmpty) {
        // Map<String, dynamic> result = {
        //   "user_id": checkUser.first[0],
        //   "full_name": checkUser.first[1],
        //   "email": checkUser.first[2],
        //   "user_image": checkUser.first[4],
        // };
        //
        // result['access_token'] = generateAccessToken(result);
        //
        // final newRefreshToken = generateRefreshToken(result['user_id']);
        // result['refresh_token'] = newRefreshToken;

        final userId = int.parse(checkUser.first[0].toString());
        final newRefreshToken = generateRefreshToken(userId);

        await connection.execute(
            Sql.named(
                "UPDATE users SET refresh_token=@refreshToken WHERE user_id=@userId"),
            parameters: {
              "userId": userId,
              "refreshToken": newRefreshToken
            });

        // final loginResponse = responseModelToJson(ResponseModel(
        //     success: true, message: "Login success.", data: result));

        return Response.ok(responseModelToJson(ResponseModel(success: true, message: "Login success.", data: userModelResponseJson(
            UserModel(
                userId: userId,
                fullName: checkUser.first[1].toString(),
                email: checkUser.first[2].toString(),
                userImage: checkUser.first[4].toString(),
                accessToken: generateAccessToken(userId),
                refreshToken: newRefreshToken
        )))));
      } else {
        return Response.notFound(responseModelToJson(ResponseModel(
            success: false,
            message: "Your email or password is incorrect.",
            data: null)));
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  //for send otp
  Future<Response> sendOtp(Request request) async {
    try {
      final req = sendOtpModelFromJson(await request.readAsString());

      final checkUsers = await connection.execute(
          Sql.named("SELECT * FROM users WHERE email=@email"),
          parameters: {"email": req.email});

      if (req.type == 0) {
        //0 for register
        if (checkUsers.isNotEmpty) {
          return Response.ok(responseModelToJson(ResponseModel(
              success: false,
              message: "User already registered.",
              data: null)));
        }

        return saveEmailOtp(req);
      } else {
        //else for forgot password
        if (checkUsers.isEmpty) {
          return Response.notFound(responseModelToJson(ResponseModel(
              success: false,
              message: "Email is not registered.",
              data: null)));
        }

        return saveEmailOtp(req);
      }
    } catch (e) {
      print("sendOtp e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to send otp code.",
              data: null)));
    }
  }

  //end for send otp

  //for register
  Future<Response> register(Request request) async {
    try {
      final req = userModelFromJson(await request.readAsString());

      if ((req.password ?? '').length < 6) {
        return Response.badRequest(
            body: responseModelToJson(ResponseModel(
                success: false,
                message: "Password length must be more than 6 digits.",
                data: null)));
      }

      final matchOtpResponse =
          await matchOtpRegistration(email: req.email, otp: req.otp.toString());
      final responseModel =
          responseModelFromJson(await matchOtpResponse.readAsString());

      if (responseModel.success) {
        await connection.execute(
            Sql.named(
                "INSERT INTO users (full_name, email, password) VALUES (@full_name, @email, @password)"),
            parameters: {
              "full_name": req.fullName,
              "email": req.email,
              "password": hashString(req.password ?? '')
            });

        final checkUserInfo = await connection.execute(
            Sql.named(
                "SELECT * FROM users WHERE email=@email AND password=@password"),
            parameters: {
              "email": req.email,
              "password": hashString(req.password ?? '')
            });

        if (checkUserInfo.isNotEmpty) {
          final userId = int.parse(checkUserInfo.first[0].toString());
          final newRefreshToken = generateRefreshToken(userId);

          await connection.execute(
              Sql.named(
                  "UPDATE users SET refresh_token=@refreshToken WHERE user_id=@userId"),
              parameters: {
                "userId": userId,
                "refreshToken": newRefreshToken
              });

          return Response.ok(
            responseModelToJson(ResponseModel(success: true, message: "User registration has been successful.", data: userModelResponseJson(UserModel(
                userId: userId,
                fullName: checkUserInfo.first[1].toString(),
                email: checkUserInfo.first[2].toString(),
                userImage: checkUserInfo.first[4].toString(),
                accessToken: generateAccessToken(userId),
                refreshToken: newRefreshToken))))
          );
        } else {
          return Response.notFound(responseModelToJson(ResponseModel(
              success: false,
              message: "User registration failed.",
              data: null)));
        }
      } else {
        return Response.ok(responseModelToJson(responseModel));
      }
    } catch (e) {
      print("register e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "User registration failed.",
              data: null)));
    }
  }

  //for send otp & save
  Future<Response> saveEmailOtp(SendOtpModel req) async {
    try {
      final otp = generateOTP();

      final checkEmailOtp = await connection.execute(
          Sql.named("SELECT * FROM email_otp WHERE email=@email"),
          parameters: {"email": req.email});

      if (checkEmailOtp.isEmpty) {
        await connection.execute(
            Sql.named(
                "INSERT INTO email_otp (email, otp_code, otp_send_time, received_otp_count) VALUES (@email, @otp_code, @otp_send_time, @received_otp_count)"),
            parameters: {
              "email": req.email,
              "otp_code": hashString(otp),
              "otp_send_time": DateTime.now().toString(),
              "received_otp_count": 1,
            });
        final sent = await sendOTPSMTP(req.email, otp);
        if (!sent) {
          return Response.internalServerError(
              body: responseModelToJson(ResponseModel(
                  success: false,
                  message: "Failed to send otp code.",
                  data: null)));
        }
        return Response.ok(responseModelToJson(ResponseModel(
            success: true, message: "OTP code sent successfully", data: null)));
      } else {
        int receivedOtpCount =
            (int.tryParse(checkEmailOtp.first[3].toString()) ?? 0) + 1;

        if (receivedOtpCount > 5) {
          Future.delayed(Duration(minutes: 2), () async {
            deleteEmailOtp(req.email.trim());
          });
          return Response.badRequest(
              body: responseModelToJson(ResponseModel(
                  success: false,
                  message:
                      "You are blocked for 2 minutes for sending OTP code.",
                  data: null)));
        }

        await connection.execute(
            Sql.named(
                "UPDATE email_otp SET email=@email, otp_code=@otp_code, otp_send_time=@otp_send_time, received_otp_count=@received_otp_count WHERE email=@email"),
            parameters: {
              "email": req.email,
              "otp_code": hashString(otp),
              "otp_send_time": DateTime.now().toString(),
              "received_otp_count": receivedOtpCount,
            });

        final sent = await sendOTPSMTP(req.email, otp);
        if (!sent) {
          return Response.internalServerError(
              body: responseModelToJson(ResponseModel(
                  success: false,
                  message: "Failed to send otp code.",
                  data: null)));
        }

        return Response.ok(responseModelToJson(ResponseModel(
            success: true, message: "OTP code sent successfully", data: null)));
      }
    } catch (e, l) {
      print("saveEmailOtp e: $e, line: $l");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to send otp code.",
              data: null)));
    }
  }

  //for match otp
  Future<Response> matchOtp(Request request) async {
    try {
      final matchOtpModel = matchOtpModelFromJson(await request.readAsString());
      final checkEmailOtp = await connection.execute(
          Sql.named("SELECT * FROM email_otp WHERE email=@email"),
          parameters: {"email": matchOtpModel.email});

      final sendOtpTime = DateTime.tryParse(checkEmailOtp.first[2].toString());
      if (sendOtpTime != null &&
          (sendOtpTime.difference(DateTime.now()).inMinutes < -3)) {
        return Response.forbidden(responseModelToJson(ResponseModel(
            success: false,
            message: "Your OTP code has expired.",
            data: null)));
      }

      final storeOtp = checkEmailOtp.first[1].toString();
      final myHashOtp = hashString(matchOtpModel.otp);

      if (storeOtp == myHashOtp) {
        deleteEmailOtp(matchOtpModel.email.trim());

        final tokenMatchOtp = generateAccessToken(0);
        return Response.ok(responseModelToJson(ResponseModel(
            success: true,
            message: "Your OTP code has been matched.",
            data: {"token": tokenMatchOtp})));
      } else {
        return Response.ok(responseModelToJson(ResponseModel(
            success: false, message: "OTP code does not match.", data: null)));
      }
    } catch (e, l) {
      print("matchOtp e: $e line: $l");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to match otp code.",
              data: null)));
    }
  }

  //for registration match otp
  Future<Response> matchOtpRegistration(
      {required String email, required String otp}) async {
    try {
      final checkEmailOtp = await connection.execute(
          Sql.named("SELECT * FROM email_otp WHERE email=@email"),
          parameters: {"email": email});

      final sendOtpTime = DateTime.tryParse(checkEmailOtp.first[2].toString());
      if (sendOtpTime != null &&
          (sendOtpTime.difference(DateTime.now()).inMinutes < -3)) {
        return Response.forbidden(responseModelToJson(ResponseModel(
            success: false,
            message: "Your OTP code has expired.",
            data: null)));
      }

      final storeOtp = checkEmailOtp.first[1].toString();
      final myHashOtp = hashString(otp);

      if (storeOtp == myHashOtp) {
        deleteEmailOtp(email.trim());
        return Response.ok(responseModelToJson(ResponseModel(
            success: true,
            message: "Your OTP code has been matched.",
            data: null)));
      } else {
        return Response.ok(responseModelToJson(ResponseModel(
            success: false, message: "OTP code does not match.", data: null)));
      }
    } catch (e) {
      print("matchOtp e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to match otp code.",
              data: null)));
    }
  }

  Future<void> deleteEmailOtp(String email) async {
    await connection.execute(
        Sql.named("DELETE FROM email_otp WHERE email=@email"),
        parameters: {"email": email});
  }

  Future<Response> resetPassword(Request request) async {
    try {
      final resetPasswordModel =
          resetPasswordModelFromJson(await request.readAsString());

      if (resetPasswordModel.password.length < 6) {
        return Response.badRequest(
            body: responseModelToJson(ResponseModel(
                success: false,
                message: "Password length must be more than 6 digits.",
                data: null)));
      }

      await connection.execute(
          Sql.named("UPDATE users SET password=@password WHERE email=@email"),
          parameters: {
            "email": resetPasswordModel.email,
            "password": hashString(resetPasswordModel.password)
          });
      return Response.ok(responseModelToJson(ResponseModel(
          success: true, message: "Password successfully reset.", data: null)));
    } catch (e) {
      print("resetPassword e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to reset password.",
              data: null)));
    }
  }

  Future<Response> changePassword(Request request) async {
    try {
      final changePasswordModel =
          changePasswordModelFromJson(await request.readAsString());

      if (changePasswordModel.currentPassword ==
          changePasswordModel.newPassword) {
        return Response.badRequest(
            body: responseModelToJson(ResponseModel(
                success: false,
                message:
                    "The current password and the new password are the same.",
                data: null)));
      }

      if (changePasswordModel.newPassword.length < 6) {
        return Response.badRequest(
            body: responseModelToJson(ResponseModel(
                success: false,
                message: "Password length must be more than 6 digits.",
                data: null)));
      }

      final token = extractToken(request);
      final decodedToken = JWT.decode(token!);
      final userId = decodedToken.payload['user_id'];

      final user = await connection.execute(
          Sql.named(
              "SELECT * FROM users WHERE user_id=@userId AND password=@currentPassword"),
          parameters: {
            "userId": userId.toString(),
            "currentPassword": hashString(changePasswordModel.currentPassword),
          });

      if (user.isEmpty) {
        return Response.notFound(responseModelToJson(ResponseModel(
            success: false,
            message: "Failed to change password.",
            data: null)));
      }

      await connection.execute(
          Sql.named(
              "UPDATE users SET password=@newPassword WHERE user_id=@userId"),
          parameters: {
            "userId": userId.toString(),
            "newPassword": hashString(changePasswordModel.newPassword)
          });

      return Response.ok(responseModelToJson(ResponseModel(
          success: true,
          message: "Password changed successfully.",
          data: null)));
    } catch (e) {
      print("changePassword e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to change password.",
              data: null)));
    }
  }

  Future<Response> refreshToken(Request request) async {
    try {
      final refreshTokenModel =
          refreshTokenModelFromJson(await request.readAsString());
      //verify refresh token
      final verify = JWT.tryVerify(
          refreshTokenModel.refreshToken ?? '', SecretKey(kRefreshSecreteKey));
      if (verify == null) {
        return Response.badRequest(
            body: responseModelToJson(ResponseModel(
                success: false,
                message: "Invalid refresh token.",
                data: null)));
      }

      //take userId
      final userId = verify.payload['user_id'];
      if (userId == null) {
        return Response.badRequest(
            body: responseModelToJson(ResponseModel(
                success: false,
                message: "Invalid refresh token.",
                data: null)));
      }

      //query from user table
      final user = await connection.execute(
          Sql.named(
              "SELECT * FROM users WHERE user_id=@userId AND refresh_token=@refreshToken"),
          parameters: {
            "userId": userId,
            "refreshToken": refreshTokenModel.refreshToken
          });

      if (user.isEmpty) {
        return Response.notFound(responseModelToJson(ResponseModel(
            success: false, message: "Invalid refresh token.", data: null)));
      }

      //update refresh token
      final newRefreshToken = generateRefreshToken(userId);
      await connection.execute(
          Sql.named(
              "UPDATE users SET refresh_token=@refreshToken WHERE user_id=@userId"),
          parameters: {"userId": userId, "refreshToken": newRefreshToken});

      return Response.ok(responseModelToJson(ResponseModel(
          success: true,
          message: "Generate new token",
          data: userModelResponseJson(UserModel(
              userId: int.parse(user.first[0].toString()),
              fullName: user.first[1].toString(),
              email: user.first[2].toString(),
              userImage: user.first[4].toString(),
              accessToken: generateAccessToken(userId),
              refreshToken: newRefreshToken)))));
    } catch (e) {
      print("refreshToken e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to refresh token.",
              data: null)));
    }
  }

  //for google sign in
  Future<Response> googleSignIn(Request request) async {
    try{
      final userModel = userModelFromJson(await request.readAsString());
      final checkUser = await connection.execute(
          Sql.named(
              "SELECT * FROM users WHERE email=@email"),
          parameters: {
            "email": userModel.email,
          });

      if(checkUser.isNotEmpty){
        final userId = int.parse(checkUser.first[0].toString());
        final newRefreshToken = generateRefreshToken(userId);
        await connection.execute(
            Sql.named(
                "UPDATE users SET refresh_token=@refreshToken WHERE user_id=@userId"),
            parameters: {"userId": userId, "refreshToken": newRefreshToken});

        return Response.ok(responseModelToJson(ResponseModel(
            success: true,
            message: "Google Sign in successfully",
            data: userModelResponseJson(UserModel(
                userId: userId,
                fullName: checkUser.first[1].toString(),
                email: checkUser.first[2].toString(),
                userImage: checkUser.first[4].toString(),
                accessToken: generateAccessToken(userId),
                refreshToken: newRefreshToken)))));
      }

      await connection.execute(
          Sql.named(
              "INSERT INTO users (full_name, email, user_image, google_signin) VALUES (@full_name, @email, @user_image, @google_signin)"),
          parameters: {
            "full_name": userModel.fullName,
            "email": userModel.email,
            "user_image": userModel.userImage,
            "google_signin": true
          });

      final checkUserInfo = await connection.execute(
          Sql.named(
              "SELECT * FROM users WHERE email=@email AND google_signin=@google_signin"),
          parameters: {
            "email": userModel.email,
            "google_signin": true
          });

      final userId = int.parse(checkUserInfo.first[0].toString());
      final newRefreshToken = generateRefreshToken(userId);

      await connection.execute(
          Sql.named(
              "UPDATE users SET refresh_token=@refreshToken WHERE user_id=@userId"),
          parameters: {
            "userId": userId,
            "refreshToken": newRefreshToken
          });

      return Response.ok(
          responseModelToJson(ResponseModel(success: true, message: "Google Sign in successfully", data: userModelResponseJson(UserModel(
              userId: userId,
              fullName: checkUserInfo.first[1].toString(),
              email: checkUserInfo.first[2].toString(),
              userImage: checkUserInfo.first[4].toString(),
              accessToken: generateAccessToken(userId),
              refreshToken: newRefreshToken))))
      );

    }catch(e){
      print("googleSignIn e: $e");
      return Response.internalServerError(
          body: responseModelToJson(ResponseModel(
              success: false,
              message: "Failed to google sign.",
              data: null)));
    }
  }

}
