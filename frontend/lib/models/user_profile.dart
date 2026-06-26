class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.displayName,
    this.jobTitle,
    this.department,
    this.phone,
    this.officeLocation,
  });

  final int id;
  final String name;
  final String email;
  final String? displayName;
  final String? jobTitle;
  final String? department;
  final String? phone;
  final String? officeLocation;

  String get label => displayName ?? name;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      jobTitle: json['job_title'] as String?,
      department: json['department'] as String?,
      phone: json['phone'] as String?,
      officeLocation: json['office_location'] as String?,
    );
  }
}
