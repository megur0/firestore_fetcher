import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class FirestoreInfinitableData<S extends Comparable> {
  S get sortKey;
  String get id;
}

class InfiniteFirestoreFetcherHybrid<T extends FirestoreInfinitableData<S>,
    S extends Comparable, E> {
  InfiniteFirestoreFetcherHybrid(
    this._getMoreData,
    this._limit,
    this.getChangedDataSubscription,
    this._notify, {
    bool sortDescending = true,
    E? Function(E? error, StackTrace? stackTrace)? errorHandler,
    List<T> Function(
            List<T> currentDataList,
            List<({T data, DocumentChangeType type})> changedDataList,
            int Function(T a, T b) sorter)?
        changedDataHandler,
  })  : _sortDescending = sortDescending,
        _errorHandler = errorHandler,
        _changedDataHandler = changedDataHandler {
    _initialLoad();
  }

  final int _limit;

  S? _offset;

  List<T>? _dataList;
  List<T>? get dataList => _dataList;

  E? _errorOnMoreLoad;
  E? get errorOnMoreLoad => _errorOnMoreLoad;
  E? _errorOnLoadChangedData;
  E? get errorOnLoadChangedData => _errorOnLoadChangedData;
  final E? Function(E? error, StackTrace? stackTrace)? _errorHandler;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  final Future<({List<T>? data, E? error})> Function(int limit, S? offset,
          E? Function(E? error, StackTrace? stackTrace)? errorHandler)
      _getMoreData;

  final void Function() _notify;

  final bool _sortDescending;

  final List<T> Function(
      List<T> currentDataList,
      List<({T data, DocumentChangeType type})> changedDataList,
      int Function(T a, T b) sorter)? _changedDataHandler;

  StreamSubscription<List<({T data, DocumentChangeType type})>>?
      _changedDataSubscription;
  final StreamSubscription<List<({T data, DocumentChangeType type})>> Function(
          DateTime offset,
          Function(List<({T data, DocumentChangeType type})> l) onData,
          Function(E? error, StackTrace? stackTrace)? onError)
      getChangedDataSubscription;

  void _initialLoad() async {
    await more();
    if (_errorOnMoreLoad != null) {
      return;
    }
    _changedDataSubscription =
        getChangedDataSubscription(clock.now(), (changes) {
      _errorOnLoadChangedData = null;
      if (changes.isEmpty) {
        return;
      }
      if (_changedDataHandler != null) {
        _dataList = _changedDataHandler(_dataList!, changes, _sorter);
      } else {
        final addOrModifiedList = <T>[];
        for (final change in changes) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            _dataList!.removeWhere((e) => e.id == change.data.id);
            addOrModifiedList.add(change.data);
          }
        }
        _dataList = _sort([...addOrModifiedList, ..._dataList!]);
      }
      _notify();
    }, (
      err,
      st,
    ) {
      if (_errorHandler != null) {
        _errorOnLoadChangedData = _errorHandler(err, st);
      } else {
        _errorOnLoadChangedData = err;
      }
      _notify();
    });
  }

  Future<void> more() async {
    _offset = _dataList?.last.sortKey;
    final result = await _getMoreData(_limit + 1, _offset, _errorHandler);

    if (result.error != null) {
      _errorOnMoreLoad = result.error;
      _notify();
      return;
    }

    _hasMore = false;
    final resultList = result.data!;
    if (resultList.length > _limit) {
      _hasMore = true;
      resultList.removeLast();
    }
    _dataList = [..._dataList ?? [], ...resultList];
    _notify();
  }

  void retry() {
    _resetData();
    _resetError();
    _cancelSubscription();
    _initialLoad();
  }

  void retryMore() {
    more();
  }

  void _resetData() {
    _dataList = null;
  }

  void _cancelSubscription() {
    if (_changedDataSubscription != null) {
      _changedDataSubscription!.cancel();
    }
  }

  List<T> _sort(List<T> l) {
    l.sort(_sorter);
    return l;
  }

  int _sorter(T a, T b) {
    if (_sortDescending) {
      return b.sortKey.compareTo(a.sortKey);
    } else {
      return a.sortKey.compareTo(b.sortKey);
    }
  }

  void _resetError() {
    _errorOnMoreLoad = null;
    _errorOnLoadChangedData = null;
  }

  void dispose() {
    _cancelSubscription();
  }
}
