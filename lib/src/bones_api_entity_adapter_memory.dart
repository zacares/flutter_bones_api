import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

/// A [SQLAdapter] that stores tables data in memory.
///
/// Simulates a SQL Database adapter. Useful for tests.
class MemorySQLAdapter extends SQLAdapter<int> {
  static int _idCount = 0;

  final int id = ++_idCount;

  MemorySQLAdapter({EntityRepositoryProvider? parentRepositoryProvider})
      : super(1, 3, 'generic',
            parentRepositoryProvider: parentRepositoryProvider);

  @override
  String get sqlElementQuote => '';

  @override
  bool get sqlAcceptsOutputSyntax => false;

  @override
  bool get sqlAcceptsReturningSyntax => true;

  @override
  bool get sqlAcceptsTemporaryTableForReturning => false;

  @override
  bool get sqlAcceptsInsertIgnore => true;

  @override
  bool get sqlAcceptsInsertOnConflict => false;

  int _connectionCount = 0;

  @override
  String getConnectionURL(int connection) => 'memory://$connection';

  @override
  int createConnection() => ++_connectionCount;

  @override
  FutureOr<bool> closeConnection(int connection) => true;

  final Map<String, Map<Object, Map<String, dynamic>>> _tables =
      <String, Map<Object, Map<String, dynamic>>>{};

  final Map<String, int> _tablesIdCount = <String, int>{};

  Map<Object, Map<String, dynamic>>? _getTableMap(
      String table, bool autoCreate) {
    var map = _tables[table];
    if (map != null) {
      return map;
    } else if (autoCreate) {
      _tables[table] = map = <int, Map<String, dynamic>>{};
      return map;
    } else {
      return null;
    }
  }

  Map<String, dynamic>? _getByID(String table, Object id) {
    var map = _getTableMap(table, false);
    return map?[id];
  }

  @override
  FutureOr<int> doCountSQL(String table, SQL sql, int connection) {
    var map = _getTableMap(table, false);
    return map == null ? 0 : map.length;
  }

  @override
  FutureOr doInsertRelationshipSQL(String table, SQL sql, int connection) {
    var entry = sql.parameters;

    var map = _getTableMap(table, true)!;

    var prevEntry =
        map.entries.firstWhereOrNull((e) => isEqualsDeep(e.value, entry));
    if (prevEntry != null) {
      return prevEntry.key;
    }

    var id = nextID(table);
    map[id] = entry;

    return id;
  }

  @override
  FutureOr doInsertSQL(String table, SQL sql, int connection) {
    var map = _getTableMap(table, true)!;

    var id = nextID(table);

    var entry = sql.parameters;

    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    entry[idField] = id;

    map[id] = entry;

    return id;
  }

  @override
  FutureOr doUpdateSQL(String table, SQL sql, Object id, int connection) {
    var map = _getTableMap(table, true)!;

    var entry = sql.parameters;

    var prevEntry = map[id];

    prevEntry!.addAll(entry);

    return id;
  }

  Object nextID(String table) {
    return _tablesIdCount.update(table, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String table, SQL sql, int connection) {
    var map = _getTableMap(table, false);
    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme = getTableScheme(table) as TableScheme?;

    var entityHandler = getEntityRepository(name: table)?.entityHandler;

    if (tableScheme == null || tableScheme.fieldsReferencedTables.isEmpty) {
      var sel = map.values.where((e) {
        return sql.condition!.matchesEntityMap(e,
            namedParameters: sql.parameters, entityHandler: entityHandler);
      }).toList();

      sel = _filterReturnColumns(sql, sel);
      return sel;
    }

    var fieldsReferencedTables = tableScheme.fieldsReferencedTables;

    var sel = map.values.where((obj) {
      obj = _resolveEntityMap(obj, fieldsReferencedTables);

      return sql.condition!.matchesEntityMap(obj,
          namedParameters: sql.parameters, entityHandler: entityHandler);
    }).toList();

    sel = _filterReturnColumns(sql, sel);
    return sel;
  }

  List<Map<String, dynamic>> _filterReturnColumns(
      SQL sql, List<Map<String, dynamic>> sel) {
    var returnColumns = sql.returnColumns;

    if (returnColumns != null && returnColumns.isNotEmpty) {
      return sel.map((e) {
        return Map<String, dynamic>.fromEntries(
            e.entries.where((e) => returnColumns.contains(e.key)));
      }).toList();
    } else {
      return sel;
    }
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
      String table, SQL sql, int connection) {
    var map = _getTableMap(table, false);
    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme = getTableScheme(table) as TableScheme?;

    var entityHandler = getEntityRepository(name: table)?.entityHandler;

    if (tableScheme == null || tableScheme.fieldsReferencedTables.isEmpty) {
      var entries = map.entries.where((e) {
        return sql.condition!.matchesEntityMap(e.value,
            namedParameters: sql.parameters, entityHandler: entityHandler);
      }).toList();

      return _removeEntries(entries, map);
    }

    var fieldsReferencedTables = tableScheme.fieldsReferencedTables;

    var entries = map.entries
        .map((e) {
          var obj = _resolveEntityMap(e.value, fieldsReferencedTables);

          var match = sql.condition!.matchesEntityMap(obj,
              namedParameters: sql.parameters, entityHandler: entityHandler);

          return match ? MapEntry(e.key, obj) : null;
        })
        .whereNotNull()
        .toList(growable: false);

    return _removeEntries(entries, map);
  }

  List<Map<String, dynamic>> _removeEntries(
      List<MapEntry<Object, Map<String, dynamic>>> entries,
      Map<Object, Map<String, dynamic>> map) {
    var del = entries.map((e) => e.value).toList();

    for (var e in entries) {
      map.remove(e.key);
    }

    return del;
  }

  Map<String, dynamic> _resolveEntityMap(Map<String, dynamic> obj,
      Map<String, TableFieldReference> fieldsReferencedTables) {
    return obj.map((key, value) {
      var refField = fieldsReferencedTables[key];
      if (refField != null) {
        var id = obj[key];

        if (id != null) {
          var obj2 = _getByID(refField.targetTable, id);

          if (obj2 != null) {
            var tableScheme2 =
                getTableScheme(refField.targetTable) as TableScheme?;

            if (tableScheme2 != null &&
                tableScheme2.fieldsReferencedTables.isNotEmpty) {
              obj2 =
                  _resolveEntityMap(obj2, tableScheme2.fieldsReferencedTables);
            }
          }

          value = obj2;
        }
      }

      return MapEntry(key, value);
    });
  }

  final Map<String, TableScheme> tablesSchemes = <String, TableScheme>{};

  void addTableSchemes(Iterable<TableScheme> tablesSchemes) {
    for (var s in tablesSchemes) {
      this.tablesSchemes[s.name] = s;
    }
  }

  @override
  FutureOr<TableScheme?> getTableSchemeImpl(String table) =>
      tablesSchemes[table];

  @override
  FutureOr<bool> isConnectionValid(connection) => true;

  @override
  String toString() {
    var tablesSizes = _tables.map((key, value) => MapEntry(key, value.length));
    return 'MemorySQLAdapter{id: $id, tables: $tablesSizes}';
  }
}
