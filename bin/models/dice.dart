import 'dart:math';

enum DiceSide { king, dame, ten, bube, nine, ass }

extension DiceParser on DiceSide {
  static DiceSide parse(String s) =>
      DiceSide.values.firstWhere((d) => d.toString() == s);
}

extension Dice on DiceSide {
  static DiceSide roll() => DiceSide.values[Random.secure().nextInt(5)];
}
