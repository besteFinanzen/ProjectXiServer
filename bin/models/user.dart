import 'dart:async';
import 'dart:io';

import 'dice.dart';
import 'value_notifier.dart';

class User {
  final String username;
  final String id;
  int bankScore;
  WebSocket socket;
  StreamController socketStream;
  String? _lastInstruction;
  ValueNotifier<bool> isOffline = ValueNotifier(false);
  List<DiceSide>? _lastRoll;
  int _reRollAmount = 3; // default amount of times to reroll
  int _score = 0;

  User(
      {required this.socket,
      required this.username,
      required this.bankScore,
      required final String id,
      required this.socketStream})
      : id = id.hashCode.toString() {
    socketStream.stream.listen((event) {
      print('User $username sent: $event');
      if (event['action'] == 'sendAgain' && _lastInstruction != null) {
        send(_lastInstruction!);
      }
    });
    _checkOnline();
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

  Map<String, dynamic> toSendableJson() {
    return {
      'username': username,
      'id': id,
      'bankScore': bankScore,
      'gameScore': _score,
      'isOffline': isOffline.value,
    };
  }

  void setLastRoll(List<DiceSide> roll) {
    if (roll.length != 5) {
      throw Exception('The roll must have 5 dice');
    }
    _lastRoll = roll;
  }

  List<DiceSide>? get lastRoll => _lastRoll;

  String? get lastInstruction => _lastInstruction;

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) =>
      other is User && other.id == id && other.username == username;

  void send(String message) {
    if (isOffline.value) {
      throw OfflineException('User $username is offline', this);
    }
    _lastInstruction = message;
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
    await socketStream.close();
  }
}

class OfflineException implements Exception {
  final String message;
  final User user;

  OfflineException(this.message, this.user);
}
