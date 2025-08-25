// sportsverse/frontend/sportsverse_app/lib/models/branch.dart

class Branch {
  final int id;
  final String name;
  final String address;
  final bool isActive;
  final String? organizationName;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.isActive,
    this.organizationName,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      isActive: json['is_active'] ?? true,
      organizationName: json['organization_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'is_active': isActive,
      'organization_name': organizationName,
    };
  }

  // Helper method for creating a new branch (without ID)
  Map<String, dynamic> toCreateJson() {
    return {'name': name, 'address': address, 'is_active': isActive};
  }
}
