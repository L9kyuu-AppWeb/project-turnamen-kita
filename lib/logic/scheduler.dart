import '../models/match_model.dart';
import '../models/team_model.dart';

class Scheduler {
  /// Generates Round Robin schedule using the Circle Method.
  /// If [isHomeAway] is true, generates both legs (home & away).
  /// Automatically handles odd team counts by adding a BYE.
  static List<MatchModel> generateRoundRobin({
    required List<TeamModel> teams,
    required int groupId,
    required bool isHomeAway,
  }) {
    if (teams.length < 2) return [];

    // Work with team IDs
    final List<int> ids = teams.map((t) => t.id!).toList();

    // If odd number of teams, add a BYE placeholder (id = -1)
    if (ids.length % 2 != 0) {
      ids.add(-1); // BYE team
    }

    final int n = ids.length;
    final int totalRounds = n - 1;
    final List<MatchModel> matches = [];

    // Circle Method: fix first team, rotate the rest
    final int fixed = ids[0];
    List<int> rotating = ids.sublist(1);

    for (int round = 0; round < totalRounds; round++) {
      // Build the full list for this round: fixed + rotating
      final List<int> current = [fixed, ...rotating];

      // Pair up: first with last, second with second-to-last, etc.
      for (int i = 0; i < n ~/ 2; i++) {
        final int home = current[i];
        final int away = current[n - 1 - i];

        // Skip matches involving the BYE team
        if (home == -1 || away == -1) continue;

        matches.add(MatchModel(
          groupId: groupId,
          round: round + 1,
          homeTeamId: home,
          awayTeamId: away,
        ));
      }

      // Rotate: move last element to front of the rotating list
      final int lastElement = rotating.removeLast();
      rotating.insert(0, lastElement);
    }

    // If Home & Away, generate the reverse fixtures as additional rounds
    if (isHomeAway) {
      final int firstLegCount = matches.length;
      for (int i = 0; i < firstLegCount; i++) {
        final m = matches[i];
        matches.add(MatchModel(
          groupId: groupId,
          round: m.round + totalRounds,
          homeTeamId: m.awayTeamId,
          awayTeamId: m.homeTeamId,
        ));
      }
    }

    return matches;
  }
}
