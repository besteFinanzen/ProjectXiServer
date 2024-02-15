import 'dart:async';

class ValueNotifier<T> {
  final _controller = StreamController<T>.broadcast();

  T _value;
  T get value => _value;
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _controller.add(_value);
  }

  ValueNotifier(this._value);

  Stream<T> get stream => _controller.stream;

  void dispose() {
    _controller.close();
  }
}
