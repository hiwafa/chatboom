class AppUser {
  final String userID;
  final String name;
  final String email;
  final String avatar;
  final bool agentEnabled;
  final String agentPrompt;

  AppUser({
    required this.userID,
    required this.name,
    required this.email,
    required this.avatar,
    this.agentEnabled = false,
    this.agentPrompt = "I am currently unavailable. Please leave a message.",
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'name': name,
      'email': email,
      'avatar': avatar,
      'agentEnabled': agentEnabled,
      'agentPrompt': agentPrompt,
    };
  }
}