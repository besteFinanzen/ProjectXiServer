import 'dart:math';

enum DiceSide { king, dame, ten, bube, nine, ass }

extension DiceParser on DiceSide {
  static DiceSide parse(String s) =>
      DiceSide.values.firstWhere((d) => d.toString() == s);
}

extension Dice on DiceSide {
  static DiceSide roll() => DiceSide.values[Random.secure().nextInt(5)];
  int get value {
    switch (name) {
      case "ass":
        return 5;
      case "king":
        return 4;
      case "dame":
        return 3;
      case "bube":
        return 2;
      case "ten":
        return 1;
      default:
        return 0;
    }
  }
}

extension Roll on List<DiceSide> {
  ///Return a maximum of 25
  int get sum => fold(0, (p, c) => p + c.value);
  int get calculateRoll {
    //Five of a kind 105-100
    if (toSet().length == 1) {
      return 180 + sum;
    }
    //Four of a kind 90-95
    if (where((element) => where((e) => e == element).length == 4).isNotEmpty) {
      return 150 + sum;
    }
    //Full house 70-80
    if (where((element) => where((e) => e == element).length == 3).isNotEmpty &&
        where((element) => where((e) => e == element).length == 2).isNotEmpty) {
      return 120 + sum;
    }
    //High straight
    if (toSet().length == 5 &&
        contains(DiceSide.ass) &&
        !contains(DiceSide.nine)) {
      return 90 + sum;
    }
    //Low straight
    if (toSet().length == 5 &&
        contains(DiceSide.nine) &&
        !contains(DiceSide.ass)) {
      return 60 + sum;
    }
    //One Pair
    if (where((element) => where((e) => e == element).length == 2).length ==
        2) {
      return 30 + sum;
    }
    //Runt
    return 0 + sum;
  }
}
