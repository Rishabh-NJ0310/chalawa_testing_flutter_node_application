class UserModel {
  final String phoneNumber;
  final String name;
  final String? password;

  UserModel({
    required this.phoneNumber,
    required this.name,
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'name': name,
      if (password != null) 'password': password,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      phoneNumber: json['phoneNumber'] ?? '',
      name: json['name'] ?? '',
      password: json['password'],
    );
  }
}

class DataModel {
  final String? id;
  final String name;
  final String message;

  DataModel({
    this.id,
    required this.name,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'message': message,
    };
  }

  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      message: json['message'] ?? '',
    );
  }
}
