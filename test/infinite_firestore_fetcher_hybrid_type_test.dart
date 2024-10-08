import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_fetcher/firestore_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

const _initialDataNum = 10;
final _currentTime = DateTime.parse("2023-10-01T15:00:00.000000+09:00");
final _baseOldTime = olderDate(_currentTime, _initialDataNum);

// flutter test --plain-name 'InfiniteFirestoreFetcher'
void main() {
  final initialDataForSortedCreatedAtOnDescend =
      List.generate(_initialDataNum, (i) {
    return _DataSortedCreatedAt.gen(i);
  });
  initialDataForSortedCreatedAtOnDescend
      .sort(((a, b) => b.sortKey.compareTo(a.sortKey)));

  final initialDataForSortedCreatedAtOnAscend =
      List.generate(_initialDataNum, (i) {
    return _DataSortedCreatedAt.gen(i);
  });
  initialDataForSortedCreatedAtOnAscend
      .sort(((a, b) => a.sortKey.compareTo(b.sortKey)));

  final initialDataForSortedUpdatedAtOnDescend =
      List.generate(_initialDataNum, (i) {
    return _DataSortedUpdateAt.gen(i);
  });
  initialDataForSortedUpdatedAtOnDescend
      .sort(((a, b) => b.sortKey.compareTo(a.sortKey)));

  final initialDataForSortedUpdatedAtOnAscend =
      List.generate(_initialDataNum, (i) {
    return _DataSortedUpdateAt.gen(i);
  });
  initialDataForSortedUpdatedAtOnAscend
      .sort(((a, b) => a.sortKey.compareTo(b.sortKey)));

  group("InfiniteFirestoreFetcher", () {
    test("正常系：作成日時（降順）", () async {
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
          (limit, offset, errorHandler) async {
            return (data: initialDataForSortedCreatedAtOnDescend, error: null);
          },
          initialDataForSortedCreatedAtOnDescend.length,
          (updatedAtOffset,
              Function(
                      List<
                          ({
                            _DataSortedCreatedAt data,
                            DocumentChangeType type
                          })>)
                  onData,
              onError) {
            return Stream.fromIterable([
              <({_DataSortedCreatedAt data, DocumentChangeType type})>[]
            ]).listen(onData, onError: onError);
          },
          () {},
          errorHandler: (error, stackTrace) => error,
        );

        await Future(() {});
        expect(fetcher.dataList!.last._createdAt,
            initialDataForSortedCreatedAtOnDescend.last._createdAt);
        expect(fetcher.dataList!.first._createdAt,
            initialDataForSortedCreatedAtOnDescend.first._createdAt);
      });
    });

    test("正常系：作成日時（降順）：更新サブスクリプション検証（既存リスト内のデータの更新）", () async {
      final updateDataStreamList = [
        [
          (
            data: _DataSortedCreatedAt.gen(
                initialDataForSortedCreatedAtOnDescend[3]._data, 1),
            type: DocumentChangeType.added
          )
        ],
        [
          (
            data: _DataSortedCreatedAt.gen(
                initialDataForSortedCreatedAtOnDescend[3]._data, 2),
            type: DocumentChangeType.modified
          )
        ],
      ];
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
            (limit, offset, errorHandler) async {
              return (
                data: initialDataForSortedCreatedAtOnDescend,
                error: null
              );
            },
            initialDataForSortedCreatedAtOnDescend.length,
            (updatedAtOffset,
                Function(
                        List<
                            ({
                              _DataSortedCreatedAt data,
                              DocumentChangeType type
                            })>)
                    onData,
                onError) {
              return Stream.fromIterable(updateDataStreamList)
                  .listen(onData, onError: onError);
            },
            () {},
            errorHandler: (error, stackTrace) => error);

        await Future(() {});
        expect(fetcher.dataList!.length,
            initialDataForSortedCreatedAtOnDescend.length);
        expect(fetcher.dataList![3]._createdAt,
            updateDataStreamList[1][0].data._createdAt);
        expect(fetcher.dataList![3]._updatedAt,
            updateDataStreamList[1][0].data._updatedAt);
      });
    });

    test("正常系：作成日時（降順）：サブスクリプション検証（既存リスト外のデータも追加されてしまう）", () async {
      final updateDataStreamList = [
        [
          (
            data: _DataSortedCreatedAt.gen(-1, 1),
            type: DocumentChangeType.added
          )
        ],
        [
          (
            data: _DataSortedCreatedAt.gen(-2, 2),
            type: DocumentChangeType.added
          )
        ],
      ];
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
            (limit, offset, errorHandler) async {
              return (
                data: initialDataForSortedCreatedAtOnDescend,
                error: null
              );
            },
            initialDataForSortedCreatedAtOnDescend.length,
            (updatedAtOffset,
                Function(
                        List<
                            ({
                              _DataSortedCreatedAt data,
                              DocumentChangeType type
                            })>)
                    onData,
                onError) {
              return Stream.fromIterable(updateDataStreamList)
                  .listen(onData, onError: onError);
            },
            () {},
            errorHandler: (error, stackTrace) => error);

        await Future(() {});
        expect(fetcher.dataList!.length,
            initialDataForSortedCreatedAtOnDescend.length + 2);
      });
    });

    test("正常系：作成日時（降順）：サブスクリプション検証（既存リスト外のデータは追加しない。(カスタマイズしたハンドラーを利用)）",
        () async {
      final updateDataStreamList = [
        [
          (
            data: _DataSortedCreatedAt.gen(-1, 1),
            type: DocumentChangeType.added
          )
        ],
        [
          (
            data: _DataSortedCreatedAt.gen(-2, 2),
            type: DocumentChangeType.added
          )
        ],
      ];
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
            (limit, offset, errorHandler) async {
              return (
                data: initialDataForSortedCreatedAtOnDescend,
                error: null
              );
            },
            initialDataForSortedCreatedAtOnDescend.length,
            (updatedAtOffset,
                Function(
                        List<
                            ({
                              _DataSortedCreatedAt data,
                              DocumentChangeType type
                            })>)
                    onData,
                onError) {
              return Stream.fromIterable(updateDataStreamList)
                  .listen(onData, onError: onError);
            },
            () {},
            errorHandler: (error, stackTrace) => error,
            changedDataHandler: _DataSortedCreatedAt.changedDataHandeler);

        await Future(() {});

        expectSameElements(
            fetcher.dataList!, initialDataForSortedCreatedAtOnDescend);
      });
    });

    test("正常系：作成日時（降順）：サブスクリプション検証（新規データ）", () async {
      final updateDataStreamList = [
        [
          (
            data: _DataSortedCreatedAt(
                "1", 1, newerDate(_currentTime, 1), newerDate(_currentTime, 1)),
            type: DocumentChangeType.added
          ),
          (
            data: _DataSortedCreatedAt(
                "2", 1, newerDate(_currentTime, 2), newerDate(_currentTime, 2)),
            type: DocumentChangeType.added
          ),
        ],
        [
          (
            data: _DataSortedCreatedAt(
                "3", 2, newerDate(_currentTime, 3), newerDate(_currentTime, 3)),
            type: DocumentChangeType.added
          ),
          (
            data: _DataSortedCreatedAt(
                "4", 3, newerDate(_currentTime, 3), newerDate(_currentTime, 3)),
            type: DocumentChangeType.added
          ),
        ],
        [
          (
            data: _DataSortedCreatedAt(
                "5", 5, newerDate(_currentTime, 5), newerDate(_currentTime, 5)),
            type: DocumentChangeType.added
          ),
        ],
      ];
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
            (limit, offset, errorHandler) async {
              return (data: <_DataSortedCreatedAt>[], error: null);
            },
            initialDataForSortedCreatedAtOnDescend.length,
            (updatedAtOffset,
                Function(
                        List<
                            ({
                              _DataSortedCreatedAt data,
                              DocumentChangeType type
                            })>)
                    onData,
                onError) {
              return Stream.fromIterable(updateDataStreamList)
                  .listen(onData, onError: onError);
            },
            () {},
            errorHandler: (error, stackTrace) => error);

        await Future(() {});

        expect(fetcher.dataList!.length, 5);
        expect(fetcher.dataList!.first._createdAt,
            updateDataStreamList.last[0].data._createdAt);
      });
    });

    test("正常系：作成日時（昇順）", () async {
      final updateDataStreamList = [
        [
          (
            data: _DataSortedCreatedAt.genFrom(
                initialDataForSortedCreatedAtOnAscend.first, 1),
            type: DocumentChangeType.added
          ),
        ],
      ];
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
            (limit, offset, errorHandler) async {
              return (data: initialDataForSortedCreatedAtOnAscend, error: null);
            },
            initialDataForSortedCreatedAtOnAscend.length,
            (updatedAtOffset,
                Function(
                        List<
                            ({
                              _DataSortedCreatedAt data,
                              DocumentChangeType type
                            })>)
                    onData,
                onError) {
              return Stream.fromIterable(updateDataStreamList)
                  .listen(onData, onError: onError);
            },
            () {},
            errorHandler: (error, stackTrace) => error,
            sortDescending: false);

        await Future(() {});

        expect(fetcher.dataList!.last._createdAt,
            initialDataForSortedCreatedAtOnAscend.last._createdAt);
        expect(fetcher.dataList!.first._createdAt,
            initialDataForSortedCreatedAtOnAscend.first._createdAt);
      });
    });

    test("正常系：更新日時（降順）：サブスクリプション検証（更新・新規）", () async {
      final updateDataStreamList = [
        [
          (
            data: _DataSortedUpdateAt.gen(_initialDataNum, 1),
            type: DocumentChangeType.added
          ),
        ],
        [
          (data: _DataSortedUpdateAt.gen(0, 2), type: DocumentChangeType.added),
        ]
      ];
      await withClock(Clock.fixed(_currentTime), () async {
        final fetcher = InfiniteFirestoreFetcherHybrid(
            (limit, offset, errorHandler) async {
              return (
                data: initialDataForSortedUpdatedAtOnDescend,
                error: null
              );
            },
            initialDataForSortedUpdatedAtOnDescend.length,
            (updatedAtOffset,
                Function(
                        List<
                            ({
                              _DataSortedUpdateAt data,
                              DocumentChangeType type
                            })>)
                    onData,
                onError) {
              return Stream.fromIterable(updateDataStreamList)
                  .listen(onData, onError: onError);
            },
            () {},
            errorHandler: (error, stackTrace) => error);

        await Future(() {});
        expect(fetcher.dataList!.length,
            initialDataForSortedUpdatedAtOnDescend.length + 1);
        expect(fetcher.dataList!.first.id,
            initialDataForSortedUpdatedAtOnDescend.last.id);
        expect(fetcher.dataList![1].id, updateDataStreamList[0][0].data.id);
      });
    });
  });
}

DateTime olderDate(DateTime baseTime, int minutes) {
  return baseTime.subtract(Duration(minutes: minutes));
}

DateTime newerDate(DateTime baseTime, int minutes) {
  return baseTime.add(Duration(minutes: minutes));
}

abstract class _BaseDummyData<T> {
  _BaseDummyData(this._id, this._data, this._createdAt, this._updatedAt);

  _BaseDummyData.gen(T data, int createdAtOffset, [int? updatedAtOffset])
      : _id = "$data",
        _data = data,
        _createdAt = newerDate(_baseOldTime, createdAtOffset),
        _updatedAt = updatedAtOffset != null
            ? newerDate(_currentTime, updatedAtOffset)
            : newerDate(_baseOldTime, createdAtOffset);

  _BaseDummyData.genFrom(_BaseDummyData from, [int? updatedAtOffset])
      : _id = from._id,
        _data = from._data,
        _createdAt = from._createdAt,
        _updatedAt = updatedAtOffset != null
            ? newerDate(from._updatedAt, updatedAtOffset)
            : from._updatedAt;

  final String _id;
  final T _data;
  final DateTime _createdAt;
  final DateTime _updatedAt;

  @override
  String toString() {
    return "$runtimeType(id: $_id, data:$_data, createdAt: $_createdAt, updatedAt: $_updatedAt)";
  }
}

final class _DataSortedCreatedAt extends _BaseDummyData<int>
    implements FirestoreInfinitableData {
  _DataSortedCreatedAt(super.id, super.data, super.createdAt, super.updatedAt);

  _DataSortedCreatedAt.gen(int data, [int? updatedAtOffset])
      : super.gen(data, data, updatedAtOffset);

  _DataSortedCreatedAt.genFrom(_DataSortedCreatedAt super.from,
      [super.updatedAtOffset])
      : super.genFrom();

  @override
  String get id => _id;

  @override
  DateTime get sortKey => _createdAt;

  static List<_DataSortedCreatedAt> changedDataHandeler(
      List<_DataSortedCreatedAt> currentDataList,
      List<({_DataSortedCreatedAt data, DocumentChangeType type})>
          changedDataList,
      int Function(_DataSortedCreatedAt a, _DataSortedCreatedAt b) sorter) {
    if (currentDataList.isEmpty) {
      final l = changedDataList.map((e) => e.data).toList();
      l.sort(sorter);
      return l;
    } else {
      final newDataList = <_DataSortedCreatedAt>[];
      for (int i = 0; i < changedDataList.length; i++) {
        if (changedDataList[i].type == DocumentChangeType.added ||
            changedDataList[i].type == DocumentChangeType.modified) {
          bool notExist = true;
          for (int j = 0; j < currentDataList.length; j++) {
            if (changedDataList[i].data.id == currentDataList[j].id) {
              currentDataList[j] = changedDataList[i].data;
              notExist = false;
              break;
            }
          }
          if (notExist &&
              sorter(currentDataList.first, (changedDataList[i].data)) == 1) {
            newDataList.add(changedDataList[i].data);
          }
        }
      }
      final l = ([...newDataList, ...currentDataList]);
      return l;
    }
  }
}

final class _DataSortedUpdateAt extends _BaseDummyData<int>
    implements FirestoreInfinitableData {
  _DataSortedUpdateAt(super.id, super.data, super.createdAt, super.updatedAt);

  _DataSortedUpdateAt.gen(int data, [int? updatedAtOffset])
      : super.gen(data, data, updatedAtOffset);

  @override
  String get id => _id;

  @override
  DateTime get sortKey => _updatedAt;
}

void expectSameElements<T>(Iterable<T> a, Iterable<T> b) {
  expect(a.length, b.length);
  expect(a.where((e) => !b.contains(e)).isEmpty, true);
}
