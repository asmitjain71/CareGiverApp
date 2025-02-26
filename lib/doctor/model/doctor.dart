class Doctor {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String city;
  final String category;
  final String qualification;
  final int yearsOfExperience;
  final double averageRating;
  final int totalReviews;
  final int numberOfReviews;
  final double latitude;
  final double longitude;
  final String profileImageUrl;

  Doctor({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.city,
    required this.category,
    required this.qualification,
    required this.yearsOfExperience,
    required this.averageRating,
    required this.totalReviews,
    required this.numberOfReviews,
    required this.latitude,
    required this.longitude,
    required this.profileImageUrl,
  });

  factory Doctor.fromMap(Map<dynamic, dynamic> map, String key) {
    return Doctor(
      uid: key,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      city: map['city'] ?? '',
      category: map['category'] ?? '',
      qualification: map['qualification'] ?? '',
      yearsOfExperience: map['yearsOfExperience'] is int
          ? map['yearsOfExperience']
          : int.tryParse(map['yearsOfExperience'].toString()) ?? 0,
      averageRating: map['averageRating'] is double
          ? map['averageRating']
          : double.tryParse(map['averageRating'].toString()) ?? 0.0,
      totalReviews: map['totalReviews'] is int
          ? map['totalReviews']
          : int.tryParse(map['totalReviews'].toString()) ?? 0,
      numberOfReviews: map['numberOfReviews'] is int
          ? map['numberOfReviews']
          : int.tryParse(map['numberOfReviews'].toString()) ?? 0,
      latitude: map['latitude'] is double
          ? map['latitude']
          : double.tryParse(map['latitude'].toString()) ?? 0.0,
      longitude: map['longitude'] is double
          ? map['longitude']
          : double.tryParse(map['longitude'].toString()) ?? 0.0,
      profileImageUrl: map['profileImageUrl'] ?? '',
    );
  }
}
