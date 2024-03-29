import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'constants.dart';
import 'game_handler.dart';
import 'models/game.dart';
import 'models/user.dart';

final Map<String, GameHandler> currentGames = {};
Future<void> main() async {
  var server = await HttpServer.bind(InternetAddress.anyIPv4, 1234);
  print('Listening on ${server.address.host}:${server.port}');

  await for (HttpRequest request in server) {
    if (request.uri.path == '/ws') {
      try {
        final Completer<Map<String, dynamic>> completer = Completer();
        final Completer overTime = Completer();
        // Upgrade an HttpRequest to a WebSocket connection
        var socket = await WebSocketTransformer.upgrade(request);
        print('Client connected!');

        final StreamController<Map<String, dynamic>> streamController =
            StreamController.broadcast(sync: true);

        streamController
            .addStream(secureStream(socket).asBroadcastStream(onCancel: (sub) {
          sub.cancel();
        }));

        Future.delayed(Constants.maxAnswerTime).then((value) {
          if (!completer.isCompleted) {
            overTime.complete();
            completer.complete({});
          }
        });

        // Listen for incoming messages from the client
        streamController.stream.listen((message) {
          if (completer.isCompleted) {
            return;
          }
          completer.complete(message);
          print('Received message: $message');
        });

        final Map<String, dynamic> firstAnswer = await completer.future;
        if (overTime.isCompleted) {
          //request.response.statusCode = HttpStatus.requestTimeout;
          await socket.close();
          continue;
        }

        if (firstAnswer['username'] == null ||
            firstAnswer['bankScore'] == null ||
            firstAnswer['id'] == null) {
          //requst.response.statusCode = HttpStatus.badRequest;
          await socket.close();
          continue;
        }
        if (firstAnswer['gameID'] != null) {
          if (!(currentGames.containsKey(firstAnswer['gameID']))) {
            //request.response.statusCode = HttpStatus.notFound;
            await socket.close();
            continue;
          }
          final User user = User(
              bankScore: firstAnswer['bankScore'],
              username: firstAnswer['username'],
              socket: socket,
              id: firstAnswer['id'],
              socketStream: streamController);
          currentGames[firstAnswer['gameID']]!.addPlayerToGame(user);
          continue;
        } else {
          String? gameID;
          while (gameID == null || currentGames.containsKey(gameID)) {
            gameID = (Random().nextInt(8999) + 1000).toString();
          }
          final User user = User(
              bankScore: firstAnswer['bankScore'],
              username: firstAnswer['username'],
              socket: socket,
              id: firstAnswer['id'],
              socketStream: streamController);
          user.send(jsonEncode({
            'message': 'Game created successfully',
            'gameID': gameID,
            'action': 'create',
          }));
          print('Game created with ID: $gameID');
          final Game game = Game(gameID: gameID, player: user);
          final GameHandler gameHandler = GameHandler(game);
          currentGames.addAll({gameID: gameHandler});
          gameHandler.start();
          continue;
        }
      } catch (e) {
        print(e);
        continue;
      }
    } else {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      continue;
    }
  }
}

Stream<Map<String, dynamic>> secureStream(Stream stream) async* {
  await for (var event in stream) {
    final Map<String, dynamic>? message = convertToMessage(event);
    if (message != null) {
      yield message;
    }
  }
}

Map<String, dynamic>? convertToMessage(String event) {
  try {
    return jsonDecode(event);
  } catch (e) {
    print('Error decoding message: $e, message: $event');
    return null;
  }
}
