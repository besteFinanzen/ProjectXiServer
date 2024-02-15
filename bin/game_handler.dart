import 'dart:async';
import 'dart:convert';

import 'game_parts.dart';
import 'models/dice.dart';
import 'models/game.dart';
import 'models/user.dart';
import 'server.dart';

extension UserPart on Map<String, dynamic> {
  Map<String, dynamic> addUserPart(User player) {
    Map<String, dynamic> userPart = player.toSendableJson();
    userPart.addAll(this);
    return userPart;
  }
}

class GameHandler {
  final Game game;

  GameHandler(this.game);

  Future start() async {
    final User host = game.host;
    await secureSend(host, {
      'message': 'You are the host of the game',
      'gameID': game.gameID,
      'action': 'waiting',
    });
    print('Host is ${host.username}');
    host.isOffline.stream.listen((event) async {
      if (event && !game.started && host == game.host) {
        await _quitGame('The host has left the game');
        return;
      } else if (event) {
        await removePlayerFromGame(host);
        return;
      }
    });
    final Completer startGameListener = Completer();
    host.socketStream.stream.listen((event) {
      if (event['action'] == 'startGame') {
        startGameListener.complete();
      }
    });
    await startGameListener.future;

    startGame();

    //TODO what to do with betting max/min
    game.setBetRange(200, 500);

    //First player to play
    for (User player in game.players) {
      await GameMoves(this).rolltheDice(player);
      await Future.delayed(Duration(seconds: 10));
    }
    await dispose();
  }

  void startGame() async {
    game.startGame();
  }

  Future secureSend(User player, Map<String, dynamic> message) async {
    try {
      player.send(jsonEncode(
        message,
      ));
    } on OfflineException {
      await removePlayerFromGame(player);
    } catch (e) {
      print(e);
    }
  }

  Future sendToAll(Iterable<User> players, Map<String, dynamic> message) async {
    final List<Future> futures =
        players.map((e) => secureSend(e, message)).toList();
    await Future.wait(futures);
  }

  Future dispose() async {
    currentGames.remove(game.gameID);
    final List<Future> futures = game.players
        .map((e) => e.dispose().onError((error, stackTrace) => print(error)))
        .toList();
    await Future.wait(futures);
    return;
  }

  Future _quitGame(String? reason) async {
    await sendToAll(game.players, {
      'message': reason ?? 'The game has ended',
      'action': 'endGame',
    });
    await dispose();
    return;
  }

  Future removePlayerFromGame(User player) async {
    game.players.remove(player);
    if (game.started) {
      await sendToAll(
          game.players,
          {
            'message': 'A player has left the game',
            'action': 'removePlayer',
          }.addUserPart(player));
    } else {
      if (game.players.length < 2) {
        //TODO Give the money to the remaining player
        await sendToAll(game.players, {
          'message': 'The game has ended',
          'action': 'endGame',
        });
        await dispose();
        return;
      }
      if (game.host == player) {
        game.host = game.players.first;
        await secureSend(game.host, {
          'message': 'You are now the host of the game',
          'action': 'gotHost',
        });
      }
      await sendToAll(
          game.players,
          ({'message': 'A player has left the game', 'action': 'removePlayer'}
              .addUserPart(player)));
    }
  }

  Future addPlayerToGame(User player) async {
    if (game.players.contains(player)) {
      await secureSend(player, {
        'message': 'You are already in the game',
        'action': 'waiting',
      });
      return;
    }
    await secureSend(player, {
      'message': 'You are a player in the game',
      'action': 'waiting',
    });

    await sendToAll(
        game.players,
        {
          'message': 'A new player has joined the game',
          'action': 'addPlayer',
        }.addUserPart(player));
    for (User competitor in game.players) {
      if (competitor == player) continue;
      await secureSend(
          player,
          {
            'message': 'You are playing with ${competitor.username}',
            'action': 'addPlayer',
          }.addUserPart(competitor));
    }
    game.players.add(player);
    player.isOffline.stream.listen((event) async {
      if (event) await removePlayerFromGame(player);
    });
  }
}
