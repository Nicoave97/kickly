import 'profile_model.dart';

class MatchParticipant {
  final String matchId;
  final String userId;
  final String status;
  final String team;
  final DateTime joinedAt;
  final ProfileModel profile;
  final double? positionX;
  final double? positionY;
  final String attendanceStatus;

  const MatchParticipant({
    required this.matchId,
    required this.userId,
    required this.status,
    required this.team,
    required this.joinedAt,
    required this.profile,
    this.positionX,
    this.positionY,
    required this.attendanceStatus,
  });

  bool get confirmed => status == 'confirmed';
  bool get waiting => status == 'waitlist';
  bool get attendanceConfirmed => attendanceStatus == 'confirmed';
  bool get attendanceMaybe => attendanceStatus == 'maybe';
  bool get attendanceDeclined => attendanceStatus == 'declined';

  factory MatchParticipant.fromMaps(
      Map<String, dynamic> row, Map<String, dynamic> profile) {
    return MatchParticipant(
      matchId: row['match_id'] as String,
      userId: row['user_id'] as String,
      status: row['status'] as String,
      team: (row['team'] as String?) ?? 'unassigned',
      joinedAt: DateTime.parse(row['joined_at'] as String).toLocal(),
      profile: ProfileModel.fromMap(profile),
      positionX: (row['position_x'] as num?)?.toDouble(),
      positionY: (row['position_y'] as num?)?.toDouble(),
      attendanceStatus: (row['attendance_status'] as String?) ?? 'pending',
    );
  }
}
