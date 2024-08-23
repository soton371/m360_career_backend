// To parse this JSON data, do
//
//     final refreshTokenModel = refreshTokenModelFromJson(jsonString);

import 'dart:convert';

RefreshTokenModel refreshTokenModelFromJson(String str) => RefreshTokenModel.fromJson(json.decode(str));

String refreshTokenModelToJson(RefreshTokenModel data) => json.encode(data.toJson());

class RefreshTokenModel {
  final String? refreshToken;
  final String? accessToken;

  RefreshTokenModel({
    this.refreshToken,
    this.accessToken,
  });

  factory RefreshTokenModel.fromJson(Map<String, dynamic> json) => RefreshTokenModel(
    refreshToken: json["refresh_token"],
    accessToken: json["access_token"],
  );

  Map<String, dynamic> toJson() => {
    "refresh_token": refreshToken,
    "access_token": accessToken,
  };
}
