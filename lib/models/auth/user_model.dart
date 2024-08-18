// To parse this JSON data, do
//
//     final userModel = userModelFromJson(jsonString);

import 'dart:convert';

UserModel userModelFromJson(String str) => UserModel.fromJson(json.decode(str));

String userModelToJson(UserModel data) => json.encode(data.toJson());


class UserModel {
  final int? userId;
  final String? fullName;
  final String email;
  final String? password;
  final String? otp;
  final String? userImage;
  final bool? googleSignIn;

  UserModel({
    this.userId,
    this.fullName,
    required this.email,
    this.password,
    this.otp,
    this.userImage,
    this.googleSignIn,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    userId: json["user_id"],
    fullName: json["full_name"],
    email: json["email"],
    password: json["password"],
    otp: json["otp"],
    userImage: json["user_image"],
    googleSignIn: json["google_signin"],
  );

  Map<String, dynamic> toJson() => {
    "full_name": fullName,
    "email": email,
    "password": password,
    "user_image": userImage,
    "google_signin": googleSignIn,
  };
}