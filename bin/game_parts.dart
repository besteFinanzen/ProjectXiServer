import 'dart:async';
import 'dart:convert';

import 'game_handler.dart';
import 'models/dice.dart';
import 'models/user.dart';

class GameMoves {
  final GameHandler gameHandler;

  GameMoves(this.gameHandler);

  Future rolltheDice(User player) async {
    final Completer rolledDice = Completer();
    List<DiceSide> dices = List.generate(5, (index) => Dice.roll());
    print(dices);
    player.socketStream.stream.listen((event) async {
      if (event['action'] == 'endDice') {
        player.setLastRoll(dices);
        rolledDice.complete();
      } else if (event['action'] == 'reRollDice') {
        print('Rerolling dices');
        if (player.reRoll) {
          final List<int> wantedChanges = event['indexes'].cast<int>();
          print(wantedChanges);
          print(dices);
          for (int i in wantedChanges) {
            if (i < 0 || i > 4) {
              return;
            } else {
              dices[i] = Dice.roll();
            }
          }
          print('Rerolled dices: $dices');
          await gameHandler.secureSend(player, {
            'message': 'You rerolled the dice',
            'action': 'reRollDice',
            'dices': dices.map((e) => e.toString()).toList(),
            'reRollsLeft': player.reRollAmount,
          });
          print('Rerolled di3ces: $dices');
          await gameHandler.sendToAll(
            gameHandler.game.players.where((element) => element != player),
            {
              'message': '${player.username} rerolled the dice',
              'action': 'reRollDice',
              'reRollsLeft': player.reRollAmount,
              'dices': dices.map((e) => e.toString()).toList(),
            }.addUserPart(player),
          );
        }
      }
    });
    await gameHandler.secureSend(
      player,
      {
        'message': 'You roll the dice',
        'action': 'rollDice',
        'dices': dices.map((e) => e.toString()).toList(),
        'reRollsLeft': player.reRollAmount,
      },
    );
    await gameHandler.sendToAll(
      gameHandler.game.players.where((element) => element != player),
      {
        'message': '${player.username} rolls the dice',
        'action': 'otherDice',
        'reRollsLeft': player.reRollAmount,
        'dices': dices.map((e) => e.toString()).toList(),
      }.addUserPart(player),
    );
    await rolledDice.future;

    player.addToScore(calculateScore(player));

    await gameHandler.sendToAll(
      gameHandler.game.players.where((element) => element != player),
      {
        'message': '${player.username} has rolled the dice',
        'action': 'endOtherDice',
        'dices': player.lastRoll!.map((e) => e.toString()).toList(),
        'reRollsLeft': player.reRollAmount,
      }.addUserPart(player),
    );
  }

  int calculateScore(User player) {
    if (player.lastRoll == null) {
      throw Exception('The player has not rolled the dice yet');
    }
    List<DiceSide> roll = player.lastRoll!;
    //Five of a kind
    if (roll.toSet().length == 1) {
      return 50;
    }
    //Four of a kind
    if (roll
        .where((element) => roll.where((e) => e == element).length == 4)
        .isNotEmpty) {
      return 40;
    }
    //Full house
    if (roll
            .where((element) => roll.where((e) => e == element).length == 3)
            .isNotEmpty &&
        roll
            .where((element) => roll.where((e) => e == element).length == 2)
            .isNotEmpty) {
      return 30;
    }
    //High straight
    if (roll.toSet().length == 5 &&
        roll.contains(DiceSide.ass) &&
        !roll.contains(DiceSide.nine)) {
      return 20;
    }
    //Low straight
    if (roll.toSet().length == 5 &&
        roll.contains(DiceSide.nine) &&
        !roll.contains(DiceSide.ass)) {
      return 15;
    }
    //One Pair
    if (roll
            .where((element) => roll.where((e) => e == element).length == 2)
            .length ==
        2) {
      return 10;
    }
    //Runt
    return 5;
  }

  Future finishGame() async {
    await gameHandler.sendToAll(gameHandler.game.players, {
      'message': 'The game has finished',
      'action': 'finishedGame',
      'players':
          List.of(gameHandler.game.players).map((e) => e.toSendableJson()),
      'betAmount': gameHandler.game.bettedAmount
    });
  }
}
