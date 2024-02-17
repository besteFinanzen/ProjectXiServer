import 'dart:async';

import 'constants.dart';
import 'game_handler.dart';
import 'models/dice.dart';
import 'models/user.dart';

class GameMoves {
  final GameHandler gameHandler;

  GameMoves(this.gameHandler);

  Future<bool> rolltheDice(User player) async {
    final Completer<bool> rolledDice = Completer();
    final Completer overTime = Completer();
    List<DiceSide> dices =
        player.lastRoll ?? List.generate(5, (index) => Dice.roll());
    print(dices);
    player.socketStream.stream.listen((event) async {
      print(event);
      if (event['action'] == 'endDice') {
        if (rolledDice.isCompleted) return;
        if (player.lastRoll != null) {
          player.finishedRoll = true;
        }
        player.setLastRoll(dices);
        rolledDice.complete(false);
        print('Dice ended');
      } else if (event['action'] == 'reRollDice') {
        print('Rerolling dices');
        print(rolledDice.isCompleted);
        if (player.reRoll && !rolledDice.isCompleted) {
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
          player.setLastRoll(dices);
          rolledDice.complete(true);
          print('Rerolled dices: $dices');
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
        'isFirstRoll': (player.lastRoll == null),
      },
    );
    await gameHandler.sendToAll(
      gameHandler.game.players.where((element) => element != player),
      {
        'message': '${player.username} rolls the dice',
        'action': 'otherDice',
        'reRollsLeft': player.reRollAmount,
        'dices': dices.map((e) => e.toString()).toList(),
        'isFirstRoll': (player.lastRoll == null),
      }.addUserPart(player),
    );

    Future.delayed(Constants.maxAnswerTime).then((value) {
      if (overTime.isCompleted) return;
      overTime.complete();
      rolledDice.complete(true);
    });

    if (await rolledDice.future) {
      if (overTime.isCompleted) {
        return false;
      }
      await Future.delayed(Duration(seconds: 13));
    }
    print('sdfsdfsdfsdfsdfas');

    await gameHandler.sendToAll(
      gameHandler.game.players.where((element) => element != player),
      {
        'message': '${player.username} has rolled the dice',
        'action': 'endOtherDice',
        'dices': player.lastRoll!.map((e) => e.toString()).toList(),
        'reRollsLeft': player.reRollAmount,
      }.addUserPart(player),
    );
    await Future.delayed(Duration(seconds: 5));
    return true;
  }

  Future<bool> bet() async {
    final List<User> players = gameHandler.game.players;
    Completer overTime = Completer();
    final Completer<int> firstBetted = Completer();
    await gameHandler.sendToAll(
      players,
      {
        'message': 'Its time to bet',
        'action': 'startBet',
        'lastDices': players.map((e) => e.toSendableJson()).toList(),
        'maxBet': gameHandler.game.getMaxMoneyBetable(),
        'currentBet': gameHandler.game.bettedAmount,
      },
    );
    players.first.socketStream.stream.listen((event) async {
      if (firstBetted.isCompleted) return;
      if (event['action'] == 'raiseBet') {
        final int amount = event['amount'];
        try {
          gameHandler.game.bettedAmount += amount;
        } catch (e) {
          print(e);
          return;
        }
        firstBetted.complete(event['amount']);
      } else if (event['action'] == 'check') {
        firstBetted.complete(0);
      }
      await gameHandler.secureSend(
        players.first,
        {
          'message': 'You have made a bet',
          'action': 'startBet',
          'lastDices': players.map((e) => e.toSendableJson()).toList(),
          'maxBet': gameHandler.game.getMaxMoneyBetable(),
          'currentBet': gameHandler.game.bettedAmount,
        },
      );
    });

    await gameHandler.secureSend(
      players.first,
      {
        'message': 'You are the first to bet',
        'action': 'giveBet',
        'isFirst': true,
        'currentBet': gameHandler.game.bettedAmount,
      },
    );

    Future.delayed(Constants.maxAnswerTime).then((value) {
      if (firstBetted.isCompleted) return;
      overTime.complete();
      firstBetted.complete(0);
    });

    final int raised = await firstBetted.future;
    if (overTime.isCompleted) {
      return false;
    }
    overTime = Completer();
    final Completer<int> secondBetted = Completer();

    players[1].socketStream.stream.listen((event) async {
      if (secondBetted.isCompleted) return;
      if (event['action'] == 'raiseBet') {
        final int amount = event['amount'];
        try {
          gameHandler.game.bettedAmount += amount;
        } catch (e) {
          print(e);
          return;
        }
        secondBetted.complete(event['amount']);
      } else if (event['action'] == 'check') {
        secondBetted.complete(0);
      } else if (event['action'] == 'fold') {
        players[1].folded();
        secondBetted.complete(-1);
      }
      await gameHandler.secureSend(
        players[1],
        {
          'message': 'You have made a bet',
          'action': 'startBet',
          'lastDices': players.map((e) => e.toSendableJson()).toList(),
          'maxBet': gameHandler.game.getMaxMoneyBetable(),
          'currentBet': gameHandler.game.bettedAmount,
        },
      );
    });

    await gameHandler.secureSend(
      players[1],
      {
        'message': 'You are the second to bet',
        'action': 'giveBet',
        'raisedAmount': raised,
        'isFirst': false,
        'currentBet': gameHandler.game.bettedAmount,
      },
    );

    Future.delayed(Constants.maxAnswerTime).then((value) {
      if (secondBetted.isCompleted) return;
      overTime.complete();
      secondBetted.complete(0);
    });

    final int raised2 = await secondBetted.future;

    if (overTime.isCompleted) {
      return false;
    }

    if (raised2 == -1) {
      return false;
    }

    if (!(raised2 == 0 && raised >= 0)) {
      overTime = Completer();
      final Completer thirdBetted = Completer();

      players.first.socketStream.stream.listen((event) async {
        if (thirdBetted.isCompleted) return;
        if (event['action'] == 'check') {
          thirdBetted.complete(0);
        } else if (event['action'] == 'fold') {
          players[0].folded();
          thirdBetted.complete(-1);
        }
        await gameHandler.secureSend(
          players.first,
          {
            'message': 'You have made a bet',
            'action': 'startBet',
            'lastDices': players.map((e) => e.toSendableJson()).toList(),
            'maxBet': gameHandler.game.getMaxMoneyBetable(),
            'currentBet': gameHandler.game.bettedAmount,
          },
        );
      });

      await gameHandler.secureSend(
        players.first,
        {
          'message': 'You can check or fold',
          'action': 'giveBet',
          'raisedAmount': raised2,
          'isFirst': false,
          'currentBet': gameHandler.game.bettedAmount,
        },
      );

      Future.delayed(Constants.maxAnswerTime).then((value) {
        if (thirdBetted.isCompleted) return;
        overTime.complete();
        thirdBetted.complete(0);
      });

      final int raised3 = await thirdBetted.future;

      if (overTime.isCompleted) {
        return false;
      }

      if (raised3 == -1) {
        return false;
      }
    }

    await gameHandler.sendToAll(
      players,
      {
        'message': 'The bet has finished',
        'action': 'endBet',
        'bettedAmount': gameHandler.game.bettedAmount,
      },
    );

    return true;
  }

  static int calculateScore(User player) {
    if (player.lastRoll == null && player.score != -100) {
      throw Exception('The player has not rolled the dice');
    } else if (player.score == -100) {
      return player.score;
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

  Future<bool> finishGame() async {
    final List<User> players = gameHandler.game.players;
    final Completer<bool> wantsRematch = Completer();
    for (User player in players) {
      player.setOwnScoreBasedOnLastDices();
    }

    Future.delayed(Duration(minutes: 2))
        .then((value) => wantsRematch.complete(false));
    gameHandler.game.host.socketStream.stream.listen((event) {
      if (event['action'] == 'rematch') {
        wantsRematch.complete(true);
      }
    });
    await gameHandler.sendToAll(gameHandler.game.players, {
      'message': 'The game has finished',
      'action': 'finishedGame',
      'players': players.map((e) => e.toSendableJson()).toList(),
      'betAmount': gameHandler.game.bettedAmount
    });

    if (await wantsRematch.future) {
      return true;
    } else {
      return false;
    }
  }
}
