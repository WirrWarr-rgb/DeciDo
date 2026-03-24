

class TokenModel {
  final String accessToken;
  final String tokenType;
  
  const TokenModel({
    required this.accessToken,
    this.tokenType = 'bearer',
  });
  
  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      accessToken: json['access_token'],
      tokenType: json['token_type'] ?? 'bearer',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
    };
  }
}