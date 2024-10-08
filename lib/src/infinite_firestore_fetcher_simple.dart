import 'dart:async';

class InfiniteStreamFetcherSimple<T, E> {
  InfiniteStreamFetcherSimple(
    this._limitOffset,
    this.getSubscription,
    this._notify,
  ) : _limit = _limitOffset {
    _setSubScription();
  }

  final int _limitOffset;
  int _limit;

  List<T>? _dataList;
  List<T>? get dataList => _dataList;

  E? _error;
  E? get error => _error;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  final void Function() _notify;

  late StreamSubscription<List<T>> _subscription;
  final StreamSubscription<List<T>> Function(
      void Function(List<T>) onListen,
      void Function(E? error, StackTrace st) onError,
      int limit) getSubscription;

  void _setSubScription() {
    _subscription = getSubscription((event) {
      _hasMore = false;
      if (event.isEmpty) {
        _dataList = [];
      } else {
        _dataList = event;
        if (event.length > _limit) {
          _hasMore = true;
          dataList!.removeLast();
        }
      }
      _resetError();
      _notify();
    }, (err, st) {
      _error = err;
      _notify();
    }, _limit + 1);
  }

  void more() {
    _limit += _limitOffset;
    _resetWithoutData();
  }

  void retry() {
    _resetData();
    _resetError();
    _resetSubscription();
  }

  void retryMore() {
    _resetWithoutData();
  }

  void _resetWithoutData() {
    _resetError();
    _resetSubscription();
  }

  void _resetSubscription() {
    _subscription.cancel();
    _setSubScription();
  }

  void _resetData() {
    _error = null;
  }

  void _resetError() {
    _error = null;
  }

  void dispose() {
    _subscription.cancel();
  }
}
