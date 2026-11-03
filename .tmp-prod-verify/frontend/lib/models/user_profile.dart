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
    this.username,
    this.avatarVersion,
  });

  final int id;
  final String name;
  final String email;
  final String? displayName;
  final String? jobTitle;
  final String? department;
  final String? phone;
  final String? officeLocation;
  final String? username;
  final int? avatarVersion;

  String get label => displayName ?? name;

  bool get hasAvatar => avatarVersion != null;

  UserProfile copyWith({Object? avatarVersion = _unset}) {
    return UserProfile(
      id: id,
      name: name,
      email: email,
      displayName: displayName,
      jobTitle: jobTitle,
      department: department,
      phone: phone,
      officeLocation: officeLocation,
      username: username,
      avatarVersion: identical(avatarVersion, _unset)
          ? this.avatarVersion
          : avatarVersion as int?,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final version = json['avatar_version'];
    return UserProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      jobTitle: json['job_title'] as String?,
      department: json['department'] as String?,
      phone: json['phone'] as String?,
      officeLocation: json['office_location'] as String?,
      username: json['username'] as String?,
      avatarVersion: version is num ? version.toInt() : null,
    );
  }
}

const _unset = Object();
