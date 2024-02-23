import 'dart:math';

import 'user.dart';

class Game {
  static int minimalAmountToBet = 100;

  final String gameID;
  List<User> players = [];
  User host;
  late final int _minAmount;
  late final int _maxAmount;
  bool _started = false;

  int _bettedAmount = 0;

  Game({required this.gameID, required User player, final bool started = false})
      : host = player,
        _started = started {
    players.add(player);
  }

  int get minAmount => _minAmount;
  int get maxAmount => _maxAmount;

  int get bettedAmount => _bettedAmount;

  set bettedAmount(int amount) {
    for (User player in players) {
      if (player.bankScore < amount) {
        throw Exception('The amount betted must be less than the bank score');
      }
      player.bankScore -= amount;
    }
    _bettedAmount = amount;
  }

  int getMaxMoneyAllPlayersHave() {
    if (!players.hasEnoughPlayers()) return 1000;
    int max = players.first.bankScore;
    for (User player in players) {
      if (player.bankScore < max) {
        max = player.bankScore;
      }
    }
    return max;
  }

  int getMaxMoneyBetable() {
    return min(maxAmount, getMaxMoneyAllPlayersHave());
  }

  void setBetRange(final int min, final int max) {
    if (min < minimalAmountToBet || max < 0) {
      throw Exception(
          'The minimum and maximum amount must be positive and greater than $minimalAmountToBet');
    } else if (min > max) {
      throw Exception(
          'The minimum amount must be less than the maximum amount');
    } else if (max > getMaxMoneyAllPlayersHave()) {
      throw Exception(
          'The maximum amount must be less than the maximum amount of money any player has');
    }
    _minAmount = min;
    _maxAmount = max;
  }

  void startGame() {
    if (players.length < 2) {
      throw Exception('There must be at least 2 players to start the game');
    }
    players = players..shuffle();
    _started = true;
  }

  bool get started => _started;
}
