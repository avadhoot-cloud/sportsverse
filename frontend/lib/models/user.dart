// sportsverse/frontend/sportsverse_app/lib/models/user.dart

class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? gender;
  final String? dateOfBirth; // YYYY-MM-DD format
  final String userType;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.gender,
    this.dateOfBirth,
    required this.userType,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phoneNumber: json['phone_number'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'],
      userType: json['user_type'],
    );
  }
}

class Organization {
  final int id;
  final String fullName;
  final String academyName;
  final String location;
  final String mobileNumber;
  final String emailAddress;
  final String slug;
  final List<int> sportsOfferedIds; // Only IDs for now, fetch full Sport objects separately
  final String? logoUrl;

  Organization({
    required this.id,
    required this.fullName,
    required this.academyName,
    required this.location,
    required this.mobileNumber,
    required this.emailAddress,
    required this.slug,
    required this.sportsOfferedIds,
    this.logoUrl,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'],
      fullName: json['full_name'],
      academyName: json['academy_name'],
      location: json['location'],
      mobileNumber: json['mobile_number'],
      emailAddress: json['email_address'],
      slug: json['slug'],
      sportsOfferedIds: List<int>.from(json['sports_offered']),
      logoUrl: json['logo'],
    );
  }
}

class ProfileDetails {
  final int? organizationId;
  final String? organizationName;
  final String? slug; // For Academy Admin
  final List<int>? assignedBranches; // For Coach
  final int? studentId; // For Student

  ProfileDetails({
    this.organizationId,
    this.organizationName,
    this.slug,
    this.assignedBranches,
    this.studentId,
  });

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    return ProfileDetails(
      organizationId: json['organization_id'],
      organizationName: json['organization_name'],
      slug: json['slug'],
      assignedBranches: json['assigned_branches'] != null ? List<int>.from(json['assigned_branches']) : null,
      studentId: json['student_id'],
    );
  }
}

class AuthResponse {
  final String token;
  final User user;
  final ProfileDetails? profileDetails;

  AuthResponse({
    required this.token,
    required this.user,
    this.profileDetails,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      user: User.fromJson(json['user']),
      profileDetails: json['profile_details'] != null
          ? ProfileDetails.fromJson(json['profile_details'])
          : null,
    );
  }
}

class Sport {
  final int id;
  final String name;
  final String? description;
  final String? iconUrl;

  Sport({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
  });

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['icon'],
    );
  }
}