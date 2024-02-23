import 'dart:async';
import 'dart:io';

import '../game_parts.dart';
import 'dice.dart';
import 'value_notifier.dart';

class User {
  final String username;
  final String id;
  int bankScore;
  WebSocket socket;
  StreamController socketStream;
  final List<String> _lastInstruction = [];
  ValueNotifier<bool> isOffline = ValueNotifier(false);
  List<DiceSide>? _lastDices;
  int _reRollAmount = 3; // default amount of times to reroll
  int _score = 0; // -100 when folded
  bool _finishedRoll = false;
  int _currentBet = 0;

  User(
      {required this.socket,
      required this.username,
      required this.bankScore,
      required this.id,
      required this.socketStream}) {
    socketStream.stream.listen((event) {
      print('User $username sent: $event');
      if (event['action'] == 'sendAgain' && _lastInstruction.isNotEmpty) {
        send(_lastInstruction.last);
      }
    });
    _checkOnline();
  }

  int get currentBet => _currentBet;

  set currentBet(int value) {
    if (value > bankScore) {
      throw Exception('The bet must be less than the bank score');
    }
    _currentBet = value;
    bankScore -= value;
  }

  bool get finishedRoll => _finishedRoll;

  /// Sets the finishedRoll to true
  set finishedRoll(bool value) {
    _finishedRoll = true;
  }

  int get reRollAmount => _reRollAmount;

  bool get reRoll {
    _reRollAmount -= 1;
    if (_reRollAmount < 0) {
      return false;
    } else {
      return true;
    }
  }

  int get score => _score;

  void addToScore(int newScore) {
    _score += newScore;
  }

  void folded() {
    _score = -100;
  }

  Map<String, dynamic> toSendableJson() {
    return {
      'username': username,
      'id': id.hashCode,
      'bankScore': bankScore,
      'gameScore': _score,
      'isOffline': isOffline.value,
      'lastDices': _lastDices?.map((e) => e.toString()).toList(),
    };
  }

  void setLastRoll(List<DiceSide> roll) {
    if (roll.length != 5) {
      throw Exception('The roll must have 5 dice');
    }
    _lastDices = roll;
  }

  List<DiceSide>? get lastRoll => _lastDices;

  List<String> get lastInstruction => _lastInstruction;

  @override
  int get hashCode => id.hashCode ^ username.hashCode;

  @override
  bool operator ==(Object other) => other is User && other.hashCode == hashCode;

  void send(String message) {
    _lastInstruction.add(message);
    if (isOffline.value) {
      throw OfflineException('User $username is offline', this);
    }
    socket.add(message);
  }

  Future _checkOnline() async {
    socketStream.stream.listen((_) => isOffline.value = false,
        onDone: () async {
      // The connection has been closed.
      print('User $username is offline');
      await socket.close();
      isOffline.value = true;
    });
    await socket.done.then((_) {
      isOffline.value = true;
    });
  }

  Future dispose() async {
    await socket.close();
    //await socketStream.close();
  }

  void setOwnScoreBasedOnLastDices() {
    _score = GameMoves.calculateScore(this);
  }
}

class OfflineException implements Exception {
  final String message;
  final User user;

  OfflineException(this.message, this.user);
}

extension Players on List<User> {
  bool hasEnoughPlayers() {
    return length > 1;
  }
}
