import 'dart:convert' as dart_convert;

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart' show Decimal, DynamicInt;

import 'bones_api_condition.dart';
import 'bones_api_error_zone.dart';
import 'bones_api_extension.dart';
import 'bones_api_mixin.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('Entity');

typedef JsonToEncodable = Object? Function(dynamic object);

typedef JsonReviver = Object? Function(Object? key, Object? value);

abstract class Entity {
  V? getID<V>() => getField('id');

  void setID<V>(V id) => setField('id', id);

  String get idFieldName;

  List<String> get fieldsNames;

  V? getField<V>(String key);

  TypeInfo? getFieldType(String key);

  void setField<V>(String key, V? value);

  Map<String, dynamic> toJson();

  String toJsonEncoded() => dart_convert.json.encode(toJson());
}

class EntityHandlerProvider {
  static final EntityHandlerProvider _globalProvider = EntityHandlerProvider();

  static EntityHandlerProvider get globalProvider => _globalProvider;

  final Map<Type, EntityHandler> _entityHandlers = <Type, EntityHandler>{};

  void _register<O>(EntityHandler<O> entityHandler) {
    _entityHandlers[entityHandler.type] = entityHandler;
  }

  EntityHandler<O>? getEntityHandler<O>({O? obj, Type? type}) =>
      _getEntityHandlerImpl<O>(obj: obj, type: type) ??
      _globalProvider._getEntityHandlerImpl<O>(obj: obj, type: type);

  EntityHandler<O>? _getEntityHandlerImpl<O>({O? obj, Type? type}) {
    var entityHandler = _entityHandlers[O];

    if (entityHandler == null && obj != null) {
      entityHandler = _entityHandlers[obj.runtimeType];
    }

    if (entityHandler == null && type != null) {
      entityHandler = _entityHandlers[type];
    }

    return entityHandler as EntityHandler<O>?;
  }

  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj,
      Type? type,
      String? name,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    var entityHandler = getEntityHandler<O>(obj: obj, type: type);

    if (entityHandler != null) {
      var entityRepository = entityHandler.getEntityRepository<O>(
          obj: obj,
          type: type,
          name: name,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: this);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    for (var entityHandler in _entityHandlers.values) {
      var entityRepository = entityHandler.getEntityRepository<O>(
          obj: obj,
          type: type,
          name: name,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: this);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    return null;
  }
}

/// Entity provider interface.
abstract class EntityProvider {
  FutureOr<O?> getEntityByID<O>(dynamic id, {Type? type});
}

typedef EntityCache = JsonEntityCache;

abstract class EntityHandler<O> with FieldsFromMap {
  final EntityHandlerProvider provider;
  final Type type;

  EntityHandler(EntityHandlerProvider? provider, {Type? type})
      : provider = provider ?? EntityHandlerProvider.globalProvider,
        type = type ?? O {
    if (!isValidType(this.type)) {
      throw StateError('Invalid EntityHandler type: $type (O: $O)');
    }

    if (O != type) {
      throw StateError(
          'EntityHandler generic type `O` should be the same of parameter `type`: O:$O != type:$type');
    }

    Json.boot();

    _jsonReviver = _defaultJsonReviver;

    ensureRegistered();
  }

  void ensureRegistered() => provider._register(this);

  static bool isValidType<T>([Type? type]) {
    type ??= T;
    return type != Object && type != dynamic && !isPrimitiveType(type);
  }

  static bool isPrimitiveType<T>([Type? type]) =>
      TypeParser.isPrimitiveType<T>(type);

  EntityHandler<T>? getEntityHandler<T>({T? obj, Type? type}) {
    if (T == O && isValidType<T>()) {
      return this as EntityHandler<T>;
    } else if (obj != null && obj.runtimeType == O && isValidType<O>()) {
      return this as EntityHandler<T>;
    } else if (type != null && type == O && isValidType<O>()) {
      return this as EntityHandler<T>;
    } else {
      return provider.getEntityHandler<T>(obj: obj, type: type);
    }
  }

  V? getID<V>(O o) => getField(o, idFieldsName(o));

  void setID<V>(O o, V id) => setField(o, idFieldsName(o), id);

  Map<dynamic, O> toEntitiesByIdMap(Iterable<O> entities) =>
      Map<dynamic, O>.fromEntries(entities.map((o) => MapEntry(getID(o), o)));

  String idFieldsName([O? o]);

  List<String> fieldsNames([O? o]);

  Map<String, TypeInfo> fieldsTypes([O? o]);

  Map<String, TypeInfo>? _fieldsWithTypeList;

  Map<String, TypeInfo> fieldsWithTypeList([O? o]) => _fieldsWithTypeList ??=
      fieldsWithType((_, fieldType) => fieldType.isList, o);

  Map<String, TypeInfo>? _fieldsWithTypeEntity;

  Map<String, TypeInfo> fieldsWithTypeEntity([O? o]) =>
      _fieldsWithTypeEntity ??=
          fieldsWithType((_, fieldType) => !fieldType.isBasicType, o);

  Map<String, TypeInfo>? _fieldsWithTypeListEntity;

  Map<String, TypeInfo> fieldsWithTypeListEntity([O? o]) =>
      _fieldsWithTypeListEntity ??=
          fieldsWithType((_, fieldType) => fieldType.isListEntity, o);

  Map<String, TypeInfo> fieldsWithType(
      bool Function(String fieldName, TypeInfo fieldType) typeFilter,
      [O? o]) {
    return Map<String, TypeInfo>.unmodifiable(
        Map<String, TypeInfo>.fromEntries(fieldsTypes(o).entries.where((e) {
      return typeFilter(e.key, e.value);
    })));
  }

  void inspectObject(O? o);

  FutureOr<Map<String, Object?>> resolveFieldsValues(
      Map<String, Object?> fields,
      {O? o,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    entityCache ??= JsonEntityCacheSimple();

    var fieldsTypes = this.fieldsTypes(o);

    var resolved = fields.map((f, v) {
      var t = fieldsTypes[f];
      var v2 = resolveFieldValue(f, t, v,
          entityProvider: entityProvider,
          entityCache: entityCache,
          entityHandlerProvider: entityHandlerProvider,
          entityRepositoryProvider: entityRepositoryProvider);
      return MapEntry(f, v2);
    });

    return resolved.resolveAllValuesNullable();
  }

  FutureOr<Object?> resolveFieldValue(
      String fieldName, TypeInfo? fieldType, Object? value,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    return resolveValueByType(fieldType, value,
        entityProvider: entityProvider,
        entityCache: entityCache,
        entityHandlerProvider: entityHandlerProvider,
        entityRepositoryProvider: entityRepositoryProvider);
  }

  FutureOr<Map<String, Object?>> resolveFieldsNamesAndValues(
      Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider,
      List<String>? returnFieldsUsedKeys}) {
    var fieldsNames = this.fieldsNames();

    var fieldsValues = getFieldsValuesFromMap(fieldsNames, fields,
        fieldsNamesIndexes: fieldsNamesIndexes(),
        fieldsNamesLC: fieldsNamesLC(),
        fieldsNamesSimple: fieldsNamesSimple(),
        returnMapUsedKeys: returnFieldsUsedKeys);

    return resolveFieldsValues(fieldsValues,
        entityProvider: entityProvider,
        entityCache: entityCache,
        entityHandlerProvider: entityHandlerProvider,
        entityRepositoryProvider: entityRepositoryProvider);
  }

  FutureOr<dynamic> resolveEntityFieldValue(O o, String key, dynamic value,
      {EntityProvider? entityProvider, EntityCache? entityCache}) {
    entityCache ??= JsonEntityCacheSimple();
    var fieldType = getFieldType(o, key);
    return resolveValueByType(fieldType, value,
        entityProvider: entityProvider, entityCache: entityCache);
  }

  static final TypeInfo _typeInfoTime = TypeInfo(Time);
  static final TypeInfo _typeInfoDecimal = TypeInfo(Decimal);
  static final TypeInfo _typeInfoDynamicInt = TypeInfo(DynamicInt);

  FutureOr<T?> resolveValueByType<T>(TypeInfo? type, Object? value,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    if (type == null) {
      return value as T?;
    }

    var tType = TypeInfo.from(T);
    var valueType = value != null ? TypeInfo.from(value) : null;

    if (type.equalsType(valueType) &&
        value is T &&
        (!tType.isAnyType && type.equalsType(tType) && !type.hasArguments)) {
      return value;
    }

    if (type.equalsType(_typeInfoTime)) {
      return Time.from(value) as T?;
    } else if (type.equalsType(_typeInfoDecimal)) {
      return Decimal.from(value) as T?;
    } else if (type.equalsType(_typeInfoDynamicInt)) {
      return DynamicInt.from(value) as T?;
    }

    entityCache ??= JsonEntityCacheSimple();

    if (value is Map<String, Object?>) {
      if (type.isMap) {
        return type.parse<T>(value);
      } else {
        var valEntityHandler = _resolveEntityHandler(type);
        var resolved = valEntityHandler != null
            ? valEntityHandler.createFromMap(value,
                entityProvider: entityProvider, entityCache: entityCache)
            : value;
        return resolved as T?;
      }
    } else if (value is List<Object?>) {
      if (type.isList && type.hasArguments) {
        var elementType = type.arguments.first;
        var valEntityHandler = _resolveEntityHandler(elementType);

        if (!elementType.isBasicType) {
          var totalEntitiesToResolve = 0;
          var totalResolvedEntities = 0;

          value = value.map((e) {
            if (e.isEntityIDBasicType) {
              totalEntitiesToResolve++;
              var entity =
                  entityCache!.getCachedEntityByID(e, type: elementType.type);

              if (entity != null) {
                totalResolvedEntities++;
                return entity;
              } else {
                return e;
              }
            } else {
              return e;
            }
          }).toList();

          if (totalResolvedEntities == totalEntitiesToResolve &&
              value.length == totalResolvedEntities) {
            if (valEntityHandler != null) {
              return valEntityHandler.castList(value, elementType.type)! as T;
            } else {
              return value as T;
            }
          }
        }

        if (valEntityHandler != null) {
          var listFutures = TypeParser.parseList(value,
              elementParser: (e) => valEntityHandler.resolveValueByType(
                  elementType, e,
                  entityProvider: entityProvider, entityCache: entityCache));

          if (listFutures == null) return null;

          return listFutures.resolveAll().resolveMapped((l) {
            return valEntityHandler.castList(l, elementType.type)! as T;
          });
        } else {
          var listFutures = TypeParser.parseList(value,
              elementParser: (e) => resolveValueByType(elementType, e,
                  entityProvider: entityProvider, entityCache: entityCache));

          if (listFutures == null) return null;
          return listFutures.resolveAll().resolveMapped((l) => l as T);
        }
      } else {
        return type.parse<T>(value);
      }
    } else if (value != null && !type.isBasicType) {
      if (value.isEntityIDBasicType) {
        var entity = entityCache.getCachedEntityByID(value, type: type.type);
        if (entity != null) return entity as T;
      }

      var parsed = type.parse<T>(value);
      if (parsed != null) return parsed;

      if (entityProvider != null) {
        var entityAsync = entityProvider.getEntityByID(value, type: type.type);

        if (entityAsync != null) {
          return entityAsync.resolveMapped<T?>((entity) {
            if (entity != null) return entity as T?;
            return _resolveValueByEntityHandler<T>(value!, type, entityProvider,
                entityCache, entityHandlerProvider, entityRepositoryProvider);
          });
        }
      }

      return _resolveValueByEntityHandler<T>(value, type, entityProvider,
          entityCache, entityHandlerProvider, entityRepositoryProvider);
    } else {
      return type.parse<T>(value);
    }
  }

  FutureOr<T?> _resolveValueByEntityHandler<T>(
      Object value,
      TypeInfo type,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider) {
    var valEntityHandler = _resolveEntityHandler(type);
    var entityRepository = valEntityHandler?.getEntityRepository(
        type: type.type,
        entityRepositoryProvider: entityRepositoryProvider,
        entityHandlerProvider: entityHandlerProvider ?? provider);

    if (entityRepository != null) {
      var transaction = entityProvider is Transaction ? entityProvider : null;
      var retEntity =
          entityRepository.selectByID(value, transaction: transaction);
      return retEntity.resolveMapped((val) => val as T?);
    }

    try {
      var value2 = Json.fromJson(value,
          type: type.type,
          entityHandlerProvider: provider,
          entityCache: entityCache);

      if (value2 != null) {
        return value2 as T?;
      } else {
        return value as T?;
      }
    } catch (e) {
      return value as T?;
    }
  }

  List? castList(List list, Type type) {
    if (type == this.type) {
      return List<O>.from(list);
    }
    return null;
  }

  Iterable? castIterable(Iterable itr, Type type) {
    if (type == this.type) {
      return itr.cast<O>();
    }
    return null;
  }

  EntityHandler? _resolveEntityHandler(TypeInfo fieldType) {
    var valEntityHandler = getEntityHandler(type: fieldType.type);
    valEntityHandler ??= getEntityRepository(
            type: fieldType.type, entityHandlerProvider: provider)
        ?.entityHandler;
    return valEntityHandler;
  }

  Map<String, int>? _fieldsNamesIndexes;

  Map<String, int> fieldsNamesIndexes([O? o]) {
    if (_fieldsNamesIndexes == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesIndexes = buildFieldsNamesIndexes(fieldsNames);
    }
    return _fieldsNamesIndexes!;
  }

  List<String>? _fieldsNamesLC;

  List<String> fieldsNamesLC([O? o]) {
    if (_fieldsNamesLC == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesLC = buildFieldsNamesLC(fieldsNames);
    }
    return _fieldsNamesLC!;
  }

  List<String>? _fieldsNamesSimple;

  List<String> fieldsNamesSimple([O? o]) {
    if (_fieldsNamesSimple == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesSimple = buildFieldsNamesSimple(fieldsNames);
    }
    return _fieldsNamesSimple!;
  }

  TypeInfo? getFieldType(O? o, String key);

  V? getField<V>(O o, String key);

  Map<String, dynamic> getFields(O o) {
    return Map<String, dynamic>.fromEntries(fieldsNames(o)
        .map((key) => MapEntry<String, dynamic>(key, getField(o, key))));
  }

  void setField<V>(O o, String key, V? value);

  bool trySetField<V>(O o, String key, V? value) {
    try {
      setField(o, key, value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates a copy of [obj].
  ///
  /// - The default implementation uses JSON to copy the internal data.
  FutureOr<O?> copy(O obj) {
    var json = toJson(obj);

    if (json is Map<String, dynamic>) {
      return createFromMap(json);
    }

    return null;
  }

  late JsonReviver _jsonReviver;

  JsonReviver get jsonReviver => _jsonReviver;

  set jsonReviver(JsonReviver? value) {
    _jsonReviver = value ?? _defaultJsonReviver;
  }

  Object? _defaultJsonReviver(Object? key, Object? value) {
    if (key != null) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      return createFromMap(value,
          entityProvider: EntityRepositoryProvider.globalProvider);
    }

    return value;
  }

  O decodeObjectJson(String json) => decodeJson<O>(json)!;

  List<O> decodeObjectListJson(String json) {
    var itr = decodeObjectJson(json) as Iterable<O>;
    return itr is List<O> ? itr : itr.toList();
  }

  T? decodeJson<T>(String json) {
    return dart_convert.json.decode(json, reviver: jsonReviver) as T?;
  }

  JsonToEncodable? jsonToEncodable;

  String encodeObjectJson(O o) =>
      Json.encode(o, toEncodable: jsonToEncodable, removeNullFields: true);

  String encodeObjectListJson(Iterable<O> list) => Json.encode(list.toList(),
      toEncodable: jsonToEncodable, removeNullFields: true);

  String encodeJson(dynamic o) =>
      Json.encode(o, toEncodable: jsonToEncodable, removeNullFields: true);

  dynamic toJson(dynamic o) =>
      Json.toJson(o, toEncodable: jsonToEncodable, removeNullFields: true);

  bool equalsFieldValues(String field, Object? value1, Object? value2, [O? o]) {
    if (field == idFieldsName(o)) {
      return isEqualsDeep(value1, value2);
    }

    return equalsValues(value1, value2);
  }

  bool equalsValues(Object? value1, Object? value2) {
    if (value1 == null) return value2 == null;
    if (value2 == null) return false;
    if (identical(value1, value2) || value1 == value2) return true;

    var equals = equalsValuesDateTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesPrimitive(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesEnum(value1, value2);
    if (equals != null) return equals;

    var collection1 = TypeParser.isCollectionValue(value1);
    var collection2 = TypeParser.isCollectionValue(value2);

    if (collection1 && collection2) {
      return isEqualsDeep(value1, value2, valueEquality: equalsValues);
    }

    var maybeEntity1 = !collection1 && !TypeParser.isPrimitiveValue(value1);
    var maybeEntity2 = !collection2 && !TypeParser.isPrimitiveValue(value2);

    var entityHandler1 = maybeEntity1 ? getEntityHandler(obj: value1) : null;
    var entityHandler2 = maybeEntity2 ? getEntityHandler(obj: value2) : null;

    if (entityHandler1 != null || entityHandler2 != null) {
      Object? id1;
      Object? id2;
      if (entityHandler1 == entityHandler2) {
        id1 = entityHandler1!.getID(value1);
        id2 = entityHandler1.getID(value2);
      } else if (entityHandler1 == null) {
        id1 = value1;
        id2 = entityHandler2!.getID(value2);
      } else if (entityHandler2 == null) {
        id1 = entityHandler1.getID(value1);
        id2 = value2;
      }

      if (id1 == null && id2 == null) {
        return isEqualsDeep(value1, value2);
      } else {
        return isEqualsDeep(id1, id2);
      }
    }

    return false;
  }

  static bool equalsValuesBasic(Object? value1, Object? value2) {
    if (value1 == null) return value2 == null;
    if (value2 == null) return false;
    if (identical(value1, value2) || value1 == value2) return true;

    var equals = equalsValuesDateTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesPrimitive(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesEnum(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesCollection(value1, value2);
    if (equals != null) return equals;

    return false;
  }

  static bool? equalsValuesDateTime(Object value1, Object value2) {
    if (value1 is DateTime || value2 is DateTime) {
      var t1 = TypeParser.parseInt(value1);
      var t2 = TypeParser.parseInt(value2);
      return t1 == t2;
    }

    return null;
  }

  static bool? equalsValuesTime(Object value1, Object value2) {
    if (value1 is Time || value2 is Time) {
      var t1 = value1 is Time
          ? value1.totalMilliseconds
          : TypeParser.parseInt(value1);
      var t2 = value2 is Time
          ? value2.totalMilliseconds
          : TypeParser.parseInt(value2);
      return t1 == t2;
    }

    return null;
  }

  static bool? equalsValuesPrimitive(Object value1, Object value2) {
    var primitive1 = TypeParser.isPrimitiveValue(value1);
    var primitive2 = TypeParser.isPrimitiveValue(value2);

    if (primitive1 && primitive2) {
      return value1 == value2;
    }

    return null;
  }

  static bool? equalsValuesEnum(Object value1, Object value2) {
    var enum1 = value1 is Enum;
    var enum2 = value2 is Enum;

    if (enum1 && enum2) {
      return value1 == value2;
    } else if (enum1 || enum2) {
      var enumName1 = value1 is Enum ? enumToName(value1) : value1.toString();
      var enumName2 = value2 is Enum ? enumToName(value2) : value2.toString();

      return equalsIgnoreAsciiCase(enumName1, enumName2);
    }

    return null;
  }

  static bool? equalsValuesCollection(Object value1, Object value2) {
    var collection1 = TypeParser.isCollectionValue(value1);
    var collection2 = TypeParser.isCollectionValue(value2);

    if (collection1 && collection2) {
      return isEqualsDeep(value1, value2, valueEquality: equalsValuesBasic);
    }

    return null;
  }

  FutureOr<O> createFromMap(Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider});

  FutureOr<O> setFieldsFromMap(O o, Map<String, dynamic> fields,
      {EntityProvider? entityProvider, EntityCache? entityCache}) {
    entityCache ??= JsonEntityCacheSimple();

    var fieldsNames = this.fieldsNames(o);

    var fieldsValues = getFieldsValuesFromMap(fieldsNames, fields,
        fieldsNamesIndexes: fieldsNamesIndexes(o),
        fieldsNamesLC: fieldsNamesLC(o),
        fieldsNamesSimple: fieldsNamesSimple(o));

    var setFutures = fieldsValues.entries.map((e) {
      return setFieldValueDynamic(o, e.key, e.value,
              entityProvider: entityProvider, entityCache: entityCache)
          .resolveWithValue(true);
    });

    return setFutures.resolveAllWithValue(o);
  }

  FutureOr<dynamic> setFieldValueDynamic(O o, String key, dynamic value,
      {EntityProvider? entityProvider, EntityCache? entityCache}) {
    var retValue2 = resolveEntityFieldValue(o, key, value,
        entityProvider: entityProvider, entityCache: entityCache);
    return retValue2.resolveMapped((value2) {
      setField(o, key, value2);
      return value2;
    });
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    if (!identical(provider, EntityHandlerProvider.globalProvider)) {
      _knownEntityRepositoryProviders.add(provider);
    }
  }

  EntityRepository<T>? getEntityRepository<T extends Object>(
          {T? obj,
          Type? type,
          String? name,
          EntityHandlerProvider? entityHandlerProvider,
          EntityRepositoryProvider? entityRepositoryProvider}) =>
      _knownEntityRepositoryProviders.getEntityRepository<T>(
          obj: obj,
          type: type,
          name: name,
          entityHandlerProvider: entityHandlerProvider ?? provider,
          entityRepositoryProvider: entityRepositoryProvider);
}

typedef InstantiatorDefault<O> = FutureOr<O> Function();

typedef InstantiatorFromMap<O> = FutureOr<O> Function(Map<String, dynamic>);

class GenericEntityHandler<O extends Entity> extends EntityHandler<O> {
  final InstantiatorDefault<O>? instantiatorDefault;

  final InstantiatorFromMap<O>? instantiatorFromMap;

  GenericEntityHandler(
      {this.instantiatorDefault,
      this.instantiatorFromMap,
      Type? type,
      O? sampleEntity,
      EntityHandlerProvider? provider})
      : super(provider, type: type ?? O) {
    if (instantiatorDefault == null && instantiatorFromMap == null) {
      throw ArgumentError(
          "Null instantiators: `instantiatorDefault`, `instantiatorFromMap`");
    }

    if (sampleEntity != null) {
      inspectObject(sampleEntity);
    }
  }

  String? _idFieldsName;

  @override
  String idFieldsName([O? o]) {
    var idFieldsName = _idFieldsName;

    if (idFieldsName == null) {
      if (o != null) {
        inspectObject(o);
        idFieldsName = _idFieldsName;
      }

      if (idFieldsName == null) {
        throw StateError("`idFieldsName` Not populated yet for type `$type`! "
            "No Entity instance presented to this EntityHandler yet.");
      }
    }

    return idFieldsName;
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) {
    var fieldsNames = _fieldsNames;

    if (fieldsNames == null && o != null) {
      inspectObject(o);
      fieldsNames = _fieldsNames;
    }

    if (fieldsNames == null) {
      throw StateError(
          "`fieldsNames` Not populated yet! No Entity instance presented to this EntityHandler yet. Type: $type");
    }

    return fieldsNames;
  }

  Map<String, TypeInfo>? _fieldsTypes;

  @override
  Map<String, TypeInfo> fieldsTypes([O? o]) {
    var fieldsTypes = _fieldsTypes;

    if (fieldsTypes == null && o != null) {
      inspectObject(o);
      fieldsTypes = _fieldsTypes;
    }

    if (fieldsTypes == null) {
      throw StateError(
          "`fieldsTypes` Not populated yet! No Entity instance presented to this EntityHandler yet. Type: $type");
    }

    return fieldsTypes;
  }

  @override
  void inspectObject(O? o) {
    if (o != null && _idFieldsName == null) {
      _idFieldsName = o.idFieldName;
      _fieldsNames ??= List<String>.unmodifiable(o.fieldsNames);
      _fieldsTypes ??= Map<String, TypeInfo>.unmodifiable(
          Map<String, TypeInfo>.fromEntries(
              _fieldsNames!.map((f) => MapEntry(f, o.getFieldType(f)!))));
    }
  }

  @override
  String encodeObjectJson(O o) {
    inspectObject(o);
    return super.encodeObjectJson(o);
  }

  @override
  String encodeJson(o) {
    inspectObject(o);
    return super.encodeJson(o);
  }

  @override
  String encodeObjectListJson(Iterable<O> list) {
    if (list.isNotEmpty) {
      inspectObject(list.first);
    }
    return super.encodeObjectListJson(list);
  }

  @override
  V? getID<V>(O o) {
    inspectObject(o);
    return o.getID();
  }

  @override
  void setID<V>(O o, V id) {
    inspectObject(o);
    o.setID(id);
  }

  @override
  V? getField<V>(O o, String key) {
    inspectObject(o);
    return o.getField<V>(key);
  }

  @override
  TypeInfo? getFieldType(O? o, String key) {
    inspectObject(o);
    if (o != null) {
      return o.getFieldType(key);
    } else {
      return _fieldsTypes?[key];
    }
  }

  @override
  void setField<V>(O o, String key, V? value) {
    inspectObject(o);
    try {
      return o.setField<V>(key, value);
    } catch (e, s) {
      var message = "Error setting `$type` field: $key = $value";
      _log.severe(message, e, s);
      throw StateError(message);
    }
  }

  @override
  FutureOr<O> createFromMap(Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    if (instantiatorFromMap != null) {
      var fieldsNames = this.fieldsNames();

      var fieldsValues = getFieldsValuesFromMap(fieldsNames, fields,
          fieldsNamesIndexes: fieldsNamesIndexes(),
          fieldsNamesLC: fieldsNamesLC(),
          fieldsNamesSimple: fieldsNamesSimple());

      var retFieldsResolved = resolveFieldsValues(fieldsValues,
          entityProvider: entityProvider,
          entityCache: entityCache,
          entityHandlerProvider: entityHandlerProvider,
          entityRepositoryProvider: entityRepositoryProvider);

      return retFieldsResolved.resolveMapped((fieldsResolved) {
        return instantiatorFromMap!(fieldsResolved);
      });
    } else {
      var oRet = instantiatorDefault!();
      return oRet.resolveMapped((o) => setFieldsFromMap(o, fields,
          entityProvider: entityProvider, entityCache: entityCache));
    }
  }

  @override
  String toString() {
    return 'GenericEntityHandler{$type}';
  }
}

class ClassReflectionEntityHandler<O> extends EntityHandler<O> {
  Type classType;

  ClassReflection<O>? _reflection;

  ClassReflectionEntityHandler(this.classType,
      {EntityHandlerProvider? provider, ClassReflection<O>? reflection})
      : _reflection = reflection,
        super(provider, type: classType);

  ClassReflection<O> get reflection => _reflection ??=
      ReflectionFactory().getRegisterClassReflection<O>(classType)!;

  ClassReflection<O> reflectionWithObject([O? o]) =>
      o == null ? reflection : reflection.withObject(o);

  List<ClassReflectionEntityHandler>? _siblingsEntityHandlers;

  List<ClassReflectionEntityHandler> siblingsEntityHandlers() =>
      _siblingsEntityHandlers ??=
          List<ClassReflectionEntityHandler>.unmodifiable(
              reflection.siblingsClassReflection().map((c) => c.entityHandler));

  @override
  EntityHandler<T>? getEntityHandler<T>({T? obj, Type? type}) {
    var entityHandler = super.getEntityHandler(obj: obj, type: type);
    if (entityHandler != null) {
      return entityHandler;
    }

    var classReflectionForType =
        reflection.siblingClassReflectionFor<T>(obj: obj, type: type);

    if (classReflectionForType != null) {
      return classReflectionForType.entityHandler;
    }

    entityHandler = ReflectionFactory()
        .getRegisterEntityHandler<T>(type ?? obj?.runtimeType);
    return entityHandler;
  }

  @override
  void inspectObject(O? o) {}

  @override
  V? getField<V>(O o, String key) => reflection.getField(key, o);

  @override
  TypeInfo? getFieldType(O? o, String key) {
    var field = reflection.field(key, o);
    return field != null ? TypeInfo.from(field) : null;
  }

  @override
  void setField<V>(O o, String key, V? value) {
    try {
      reflection.setField(key, value, o);
    } catch (e, s) {
      var message =
          "Error setting `$type` field using reflection[$reflection]: $key = $value";
      _log.severe(message, e, s);
      throw StateError(message);
    }
  }

  @override
  bool trySetField<V>(O o, String key, V? value) {
    var field = reflection.field<V>(key, o);
    if (field == null) return false;

    if (value == null) {
      if (field.nullable) {
        field.set(value);
        return true;
      } else {
        return false;
      }
    }

    if (field.type.type == value.runtimeType) {
      field.set(value);
      return true;
    } else {
      return false;
    }
  }

  @override
  FutureOr<O?> copy(O obj) {
    var reflection = this.reflection;
    var json = reflection.toJson(obj);
    return reflection.fromJson(json);
  }

  String? _idFieldsName;

  @override
  String idFieldsName([O? o]) {
    if (_idFieldsName == null) {
      // Just to populate:
      if (_fieldsNames == null) {
        fieldsNames(o);
      }

      var fieldName = findIdFieldName(o);
      _idFieldsName = fieldName ?? 'id';
    }
    return _idFieldsName!;
  }

  String? findIdFieldName([O? o]) {
    var reflection = reflectionWithObject(o);

    var possibleFields = reflection.fieldsWhere((f) {
      return f.type.isPrimitiveType;
    }).toList(growable: false);

    if (possibleFields.isEmpty) {
      throw StateError(
          "Class without candidate for ID field: ${fieldsNames()}");
    }

    if (possibleFields.length == 1) {
      return possibleFields.first.name;
    }

    possibleFields.sort((a, b) {
      var n1 = a.nullable;
      var n2 = b.nullable;
      return n1 == n2 ? 0 : (n1 ? -1 : 1);
    });

    var idField = possibleFields.firstWhereOrNull((f) {
      var name = f.name.toLowerCase();
      return name == 'id' || name == 'key' || name == 'primary';
    });

    if (idField != null) {
      return idField.name;
    }

    idField = possibleFields.firstWhereOrNull((f) => f.type.isNumericType);

    if (idField != null) {
      return idField.name;
    }

    idField = possibleFields.firstWhereOrNull((f) => f.nullable);

    if (idField != null) {
      return idField.name;
    }

    return null;
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) =>
      _fieldsNames ??= fieldsTypes(o).keys.toList();

  Map<String, TypeInfo>? _fieldsTypes;

  @override
  Map<String, TypeInfo> fieldsTypes([O? o]) {
    if (_fieldsTypes == null) {
      var reflection = reflectionWithObject(o);

      var types = reflection.fieldsNames.map((f) {
        var field = reflection.field(f, o);
        if (field == null || !field.hasSetter) return null;
        var type = TypeInfo.from(field);
        return MapEntry(f, type);
      });

      _fieldsTypes = Map<String, TypeInfo>.unmodifiable(
          Map<String, TypeInfo>.fromEntries(types.whereNotNull()));
    }
    return _fieldsTypes!;
  }

  @override
  FutureOr<O> createFromMap(Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    entityCache ??= JsonEntityCacheSimple();

    var returnFieldsUsedKeys = <String>[];

    return resolveFieldsNamesAndValues(fields,
            entityProvider: entityProvider,
            entityCache: entityCache,
            entityHandlerProvider: entityHandlerProvider,
            entityRepositoryProvider: entityRepositoryProvider,
            returnFieldsUsedKeys: returnFieldsUsedKeys)
        .resolveMapped((resolvedFields) {
      try {
        var fieldsUnusedKeys = fields.keys
            .whereNot((f) => returnFieldsUsedKeys.contains(f))
            .toList();

        // Add unresolved fields, to allow non field parameters,
        // constructors with parameters different from class field name.
        resolvedFields.addEntries(fieldsUnusedKeys
            .map((f) => MapEntry<String, Object?>(f, fields[f])));

        var o = reflection.createInstanceFromMap(resolvedFields,
            fieldNameResolver: (f, m) => m.containsKey(f) ? f : null);

        if (o != null) {
          return o;
        } else {
          return _createFromMapDefaultImpl(
              resolvedFields, entityProvider, entityCache);
        }
      } catch (e, s) {
        print(e);
        print(s);
        return _createFromMapDefaultImpl(fields, entityProvider, entityCache);
      }
    });
  }

  FutureOr<O> _createFromMapDefaultImpl(Map<String, dynamic> fields,
      EntityProvider? entityProvider, EntityCache? entityCache) {
    var o = reflection.createInstance();
    if (o == null) {
      throw StateError(
          "Can't call `createInstance` for type `${reflection.className}`");
    }

    return setFieldsFromMap(o, fields,
        entityProvider: entityProvider, entityCache: entityCache);
  }

  @override
  T? decodeJson<T>(String json) {
    try {
      return Json.decode<T>(json, type: type);
    } catch (_) {
      return dart_convert.json.decode(json, reviver: jsonReviver) as T?;
    }
  }

  @override
  String toString() {
    return 'ClassReflectionEntityHandler{$classType}';
  }
}

mixin EntityFieldAccessor<O> {
  dynamic getID(O o, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.getID();
    } else if (entityHandler != null) {
      return entityHandler.getID(o);
    } else if (o is Map) {
      return o['id'];
    } else {
      throw StateError('getID: No EntityHandler provided for: $o');
    }
  }

  void setID(O o, Object id, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.setID(id);
    } else if (entityHandler != null) {
      return entityHandler.setID(o, id);
    } else if (o is Map) {
      o['id'] = id;
    } else {
      throw StateError('setID: No EntityHandler provided for: $o');
    }
  }

  dynamic getField(O o, String key, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.getField(key);
    } else if (entityHandler != null) {
      return entityHandler.getField(o, key);
    } else if (o is Map) {
      return o[key];
    } else {
      throw StateError('getField($key): No EntityHandler provided for: $o');
    }
  }

  void setField(O o, String key, Object? value,
      {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      o.setField(key, value);
    } else if (entityHandler != null) {
      entityHandler.setField(o, key, value);
    } else if (o is Map) {
      o[key] = value;
    } else {
      throw StateError('setField($key): No EntityHandler provided for: $o');
    }
  }
}

class EntityFieldAccessorGeneric<O> with EntityFieldAccessor<O> {}

abstract class EntityAccessor<O extends Object> {
  final String name;

  EntityAccessor(this.name);
}

abstract class EntitySource<O extends Object> extends EntityAccessor<O> {
  EntitySource(String name) : super(name);

  FutureOr<O?> selectByID(dynamic id, {Transaction? transaction}) {
    return select(ConditionID(id)).resolveMapped((sel) {
      return sel.isNotEmpty ? sel.first : null;
    });
  }

  FutureOr<List<O?>> selectByIDs(List<dynamic> ids,
      {Transaction? transaction}) {
    var ret = ids.map((id) => selectByID(id, transaction: transaction));
    return ret.resolveAll();
  }

  FutureOr<int> length({Transaction? transaction}) =>
      count(transaction: transaction);

  FutureOr<int> countByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    var condition = _parseCache.parseQuery(query);

    return count(
        matcher: condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  FutureOr<int> count(
      {EntityMatcher<O>? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction});

  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  FutureOr<Iterable<O>> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        limit: limit);
  }

  FutureOr<Iterable<O>> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit});

  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
      {Object? oId, TypeInfo? fieldType, Transaction? transaction});

  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
      List<O>? os, String field,
      {List<dynamic>? oIds, TypeInfo? fieldType, Transaction? transaction});

  FutureOr<Iterable<O>> deleteByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    var condition = _parseCache.parseQuery(query);

    return delete(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction});
}

abstract class EntityStorage<O extends Object> extends EntityAccessor<O> {
  EntityStorage(String name) : super(name);

  bool isStored(O o, {Transaction? transaction});

  FutureOr<dynamic> store(O o, {Transaction? transaction});

  FutureOr<Iterable> storeAll(Iterable<O> o, {Transaction? transaction});

  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction});
}

class EntityRepositoryProvider with Closable implements EntityProvider {
  static final EntityRepositoryProvider _globalProvider =
      EntityRepositoryProvider._global();

  static EntityRepositoryProvider get globalProvider => _globalProvider;

  final Map<Type, EntityRepository> _entityRepositories =
      <Type, EntityRepository>{};

  EntityRepositoryProvider() {
    _globalProvider.notifyKnownEntityRepositoryProvider(this);
  }

  EntityRepositoryProvider._global();

  void registerEntityRepository<O extends Object>(
      EntityRepository<O> entityRepository) {
    checkNotClosed();

    _entityRepositories[entityRepository.type] = entityRepository;
  }

  List<EntityRepository> get registeredEntityRepositories =>
      _entityRepositories.values.toList();

  bool _callingGetEntityRepository = false;

  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj, Type? type, String? name}) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    try {
      var entityRepository =
          _getEntityRepositoryImpl<O>(obj: obj, type: type, name: name);
      if (entityRepository != null) {
        return entityRepository;
      }

      if (!identical(this, _globalProvider)) {
        return _globalProvider._getEntityRepositoryImpl<O>(
            obj: obj, type: type, name: name);
      }

      return null;
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryImpl<O extends Object>(
      {O? obj, Type? type, String? name}) {
    if (!isClosed) {
      var entityRepository = _entityRepositories[O];
      if (entityRepository != null && entityRepository.isClosed) {
        entityRepository = null;
      }

      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      } else if (obj != null) {
        entityRepository = _entityRepositories[obj.runtimeType];
        if (entityRepository != null && entityRepository.isClosed) {
          entityRepository = null;
        }
      }

      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      } else if (type != null) {
        entityRepository = _entityRepositories[type];
        if (entityRepository != null && entityRepository.isClosed) {
          entityRepository = null;
        }
      }

      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      } else if (name != null) {
        entityRepository =
            _entityRepositories.values.where((e) => e.name == name).firstOrNull;
        if (entityRepository != null && entityRepository.isClosed) {
          entityRepository = null;
        }

        if (entityRepository != null) {
          return entityRepository as EntityRepository<O>;
        }
      }
    }

    return _knownEntityRepositoryProviders.getEntityRepository<O>(
        obj: obj, type: type, name: name, entityRepositoryProvider: this);
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    if (!identical(provider, globalProvider)) {
      _knownEntityRepositoryProviders.add(provider);
    }
  }

  @override
  FutureOr<O?> getEntityByID<O>(dynamic id, {Type? type}) {
    if (id == null) return null;
    var entityRepository = getEntityRepository(type: type);
    return entityRepository?.selectByID(id).resolveMapped((o) => o as O?);
  }

  Map<Type, EntityRepository> allRepositories(
      {Map<Type, EntityRepository>? allRepositories,
      Set<EntityRepositoryProvider>? traversedProviders}) {
    allRepositories ??= <Type, EntityRepository>{};
    traversedProviders ??= <EntityRepositoryProvider>{};

    if (traversedProviders.contains(this)) {
      return allRepositories;
    }

    traversedProviders.add(this);

    for (var e in _entityRepositories.entries) {
      allRepositories.putIfAbsent(e.key, () => e.value);
    }

    for (var e in _knownEntityRepositoryProviders) {
      e.allRepositories(allRepositories: allRepositories);
    }

    return allRepositories;
  }
}

extension IterableEntityRepositoryProviderExtension
    on Iterable<EntityRepositoryProvider> {
  EntityRepository<T>? getEntityRepository<T extends Object>(
      {T? obj,
      Type? type,
      String? name,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider}) {
    var entityRepositories =
        map((e) => e.getEntityRepository<T>(obj: obj, type: type, name: name))
            .whereNotNull()
            .toList();

    var entityRepositoriesLength = entityRepositories.length;

    if (entityRepositoriesLength > 1) {
      entityRepositories = entityRepositories.toSet().toList();
    }

    if (entityRepositoriesLength == 1) {
      return entityRepositories.first;
    } else if (entityRepositoriesLength > 1) {
      EntityHandler? entityHandler;
      if (entityHandlerProvider != null) {
        entityHandler = entityHandlerProvider.getEntityHandler(type: type);
      }

      if (entityRepositoryProvider != null) {
        var sameProvider = entityRepositories
            .where((r) =>
                r.provider == entityRepositoryProvider &&
                (entityHandler == null || r.entityHandler == entityHandler))
            .toList();
        if (sameProvider.length == 1) {
          return sameProvider.first;
        }
      } else if (entityHandler != null) {
        var sameProvider = entityRepositories
            .where((r) => r.entityHandler == entityHandler)
            .toList();
        if (sameProvider.length == 1) {
          return sameProvider.first;
        }
      }

      throw StateError(
          "Multiple `EntityRepository` candidates: $entityRepositories");
    } else {
      return null;
    }
  }
}

extension EntityRepositoryProviderExtension on EntityRepositoryProvider {
  FutureOr<Map<String, List<Object>>> storeAllFromJson(
      Map<String, Iterable<Map<String, dynamic>>> entries,
      {Transaction? transaction}) {
    var results = <String, FutureOr<List<Object>>>{};

    for (var e in entries.entries) {
      var typeName = e.key;
      var typeEntries = e.value;
      var entityRepository = getEntityRepository(name: typeName);
      if (entityRepository == null) {
        throw StateError(
            "Can't find `EntityRepository` for type name: $typeName");
      }

      var os = entityRepository.storeAllFromJson(typeEntries);
      results[typeName] = os;
    }

    return results.resolveAllValues();
  }
}

abstract class EntityRepository<O extends Object> extends EntityAccessor<O>
    with Initializable, Closable
    implements EntitySource<O>, EntityStorage<O> {
  static FutureOr<Map<String, dynamic>> resolveSubEntitiesFields(
      Map<String, dynamic> fields, Map<String, Type> subEntitiesFields,
      {Object? Function(String field, Map<String, dynamic> map)? fromMap,
      Object? Function(String field)? empty,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityProvider? entityProvider,
      EntityCache? entityCache}) {
    if (subEntitiesFields.isEmpty) return fields;

    entityCache ??= JsonEntityCacheSimple();

    var entries = subEntitiesFields.entries.toList(growable: false);

    var futures = entries.map((e) {
      var f = e.key;
      var t = e.value;

      var fromMapField = fromMap != null ? (m) => fromMap(f, m) : null;
      var emptyField = empty != null ? () => empty(f) : null;

      return resolveEntityFromMap(
          parentMap: fields,
          entityField: f,
          fromMap: fromMapField,
          empty: emptyField,
          entityType: t,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entityCache: entityCache);
    });

    return futures.resolveAllJoined((resolvedEntities) {
      var map2 = Map<String, dynamic>.from(fields);

      for (var i = 0; i < entries.length; ++i) {
        var f = entries[i].key;
        var o = resolvedEntities[i];
        map2[f] = o;
      }

      return map2;
    });
  }

  static FutureOr<E?> resolveEntityFromMap<E extends Object>(
      {Object? entityMap,
      Map<String, dynamic>? parentMap,
      String? entityField,
      E? Function(Map<String, dynamic> map)? fromMap,
      E? Function()? empty,
      Type? entityType,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityProvider? entityProvider,
      EntityCache? entityCache}) {
    entityCache ??= JsonEntityCacheSimple();

    if (entityMap == null) {
      if (parentMap == null || entityField == null) {
        throw ArgumentError(
            'If `entityValue` is null, `parentMap` and `entityField` should be provided');
      }

      entityMap = parentMap[entityField];
    }

    FutureOr<E?> entity;

    if (entityMap is Map<String, dynamic>) {
      if (fromMap != null) {
        entity = fromMap(entityMap);
      }

      if (entity == null) {
        var entityRepository = _resolveEntityRepository<E>(entityField,
            entityType, entityRepositoryProvider, entityHandlerProvider);
        entity = entityRepository?.fromMap(entityMap,
            entityProvider: entityProvider, entityCache: entityCache);
      }

      if (entity == null) {
        entityHandlerProvider ??= EntityHandlerProvider.globalProvider;
        var entityHandler =
            entityHandlerProvider.getEntityHandler<E>(type: entityType);
        entity = entityHandler?.createFromMap(entityMap,
            entityProvider: entityProvider, entityCache: entityCache);
      }
    } else if (entityMap is num || entityMap is String) {
      var entityRepository = _resolveEntityRepository<E>(entityField,
          entityType, entityRepositoryProvider, entityHandlerProvider);
      entity = entityRepository?.selectByID(entityMap);
    }

    if (entity == null && empty != null) {
      return empty();
    } else {
      return entity;
    }
  }

  static EntityRepository<E>? _resolveEntityRepository<E extends Object>(
      String? entityField,
      Type? entityType,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider) {
    if (entityRepositoryProvider == null && entityHandlerProvider != null) {
      var entityRepository = entityHandlerProvider.getEntityRepository<E>(
          type: entityType, name: entityField);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    entityRepositoryProvider ??= EntityRepositoryProvider.globalProvider;

    var entityRepository = entityRepositoryProvider.getEntityRepository<E>(
        type: entityType, name: entityField);
    return entityRepository;
  }

  final EntityRepositoryProvider provider;

  final EntityHandler<O> entityHandler;
  final Type type;

  late final InstanceTracker<O, Map<String, Object?>> _entitiesTracker;

  EntityRepository(
      EntityRepositoryProvider? provider, String name, this.entityHandler,
      {Type? type})
      : provider = provider ?? EntityRepositoryProvider.globalProvider,
        type = type ?? O,
        super(name) {
    if (!EntityHandler.isValidType(this.type)) {
      throw StateError('Invalid EntityRepository type: $type ?? $O');
    }

    _entitiesTracker =
        InstanceTracker<O, Map<String, Object?>>(name, getEntityFields);

    this.provider.registerEntityRepository(this);

    entityHandler.notifyKnownEntityRepositoryProvider(this.provider);
  }

  FutureOr<List<O>> storeAllFromJson(
      Iterable<Map<String, dynamic>> entitiesJson,
      {Transaction? transaction}) {
    transaction ??= Transaction.autoCommit();

    var osAsync = entitiesJson
        .map((e) => createFromMap(e, entityCache: transaction))
        .resolveAll();

    return osAsync.resolveMapped((os) {
      return storeAll(os, transaction: transaction).resolveWithValue(os);
    });
  }

  FutureOr<O> storeFromJson(Map<String, dynamic> json,
      {Transaction? transaction}) {
    transaction ??= Transaction.autoCommit();

    var oAsync = createFromMap(json, entityCache: transaction);

    return oAsync.resolveMapped((o) {
      return store(o, transaction: transaction).resolveWithValue(o);
    });
  }

  FutureOr<O> createFromMap(Map<String, dynamic> fields,
          {EntityProvider? entityProvider, EntityCache? entityCache}) =>
      entityHandler.createFromMap(fields,
          entityProvider: entityProvider, entityCache: entityCache);

  Object? getEntityID(O o) => entityHandler.getID(o);

  Map<String, Object?> getEntityFields(O o) => entityHandler.getFields(o);

  FutureOr<O> fromMap(Map<String, dynamic> fields,
          {EntityProvider? entityProvider, EntityCache? entityCache}) =>
      entityHandler.createFromMap(fields,
          entityProvider: entityProvider, entityCache: entityCache);

  O trackEntity(O o) => _entitiesTracker.trackInstance(o);

  void untrackEntity(O? o) => _entitiesTracker.untrackInstance(o);

  O? trackEntityNullable(O? o) => _entitiesTracker.trackInstanceNullable(o);

  List<O> trackEntities(Iterable<O> os) => _entitiesTracker.trackInstances(os);

  List<O?> trackEntitiesNullable(Iterable<O?> os) =>
      _entitiesTracker.trackInstancesNullable(os);

  void untrackEntities(Iterable<O?> os) =>
      _entitiesTracker.untrackInstances(os);

  List<String>? getEntityChangedFields(O o) {
    var prevFields = _entitiesTracker.getTrackedInstanceInfo(o);
    if (prevFields == null) {
      return null;
    }

    var fields = getEntityFields(o);

    var changed = fields.entries.where((e) {
      var key = e.key;
      var val = e.value;
      var prevVal = prevFields[key];
      var eq = entityHandler.equalsFieldValues(key, val, prevVal);
      return !eq;
    });

    var changedFields = changed.map((e) => e.key).toList();
    return changedFields;
  }

  bool entityHasChangedFields(O o) {
    var prevFields = _entitiesTracker.getTrackedInstanceInfo(o);
    if (prevFields == null) {
      return false;
    }

    var fields = getEntityFields(o);

    var changed = fields.entries.any((e) {
      var key = e.key;
      var val = e.value;
      var prevVal = prevFields[key];
      var eq = entityHandler.equalsFieldValues(key, val, prevVal);
      return !eq;
    });

    return changed;
  }

  @override
  FutureOr<O?> selectByID(dynamic id, {Transaction? transaction}) {
    checkNotClosed();

    var cachedEntity = transaction?.getCachedEntityByID(id, type: type);
    if (cachedEntity != null) {
      return cachedEntity;
    }

    return select(ConditionID(id), transaction: transaction)
        .resolveMapped((sel) {
      return sel.isNotEmpty ? sel.first : null;
    }).resolveMapped(trackEntityNullable);
  }

  @override
  FutureOr<List<O?>> selectByIDs(List<dynamic> ids,
      {Transaction? transaction}) {
    if (ids.isEmpty) return <O?>[];

    var idsUnique = ids.length == 1 ? ids : ids.toSet().toList();

    if (idsUnique.length == 1) {
      var id = idsUnique.first;

      var cachedEntity = transaction?.getCachedEntityByID(id, type: type);
      if (cachedEntity != null) {
        return <O>[cachedEntity];
      }

      var ret = selectByID(id, transaction: transaction);
      return ret.resolveMapped((o) => _idsToUniqueEntityList(ids, o));
    }

    var cachedEntities = transaction?.getCachedEntitiesByIDs<O>(idsUnique,
        type: type, removeCachedIDs: true);

    if (idsUnique.isEmpty) {
      var entities = _idsToEntitiesList(ids, null, cachedEntities);
      trackEntitiesNullable(entities);
      return entities;
    }

    var ret = select(ConditionIdIN(idsUnique), transaction: transaction);

    return ret
        .resolveMapped((results) => _idsToEntitiesList(
            ids, entityHandler.toEntitiesByIdMap(results), cachedEntities))
        .resolveMapped(trackEntitiesNullable);
  }

  List<O?> _idsToEntitiesList(List<dynamic> ids, Map<dynamic, O>? entitiesByID,
          [Map<dynamic, Object>? cachedEntities]) =>
      ids.map((id) => entitiesByID?[id] ?? cachedEntities?[id] as O?).toList();

  List<O?> _idsToUniqueEntityList(List<dynamic> ids, O? o) {
    if (o == null) return List<O?>.filled(ids.length, null);
    var oID = getEntityID(o);
    if (ids.length == 1) return <O?>[o];
    return ids.map((id) => id == oID ? o : null).toList();
  }

  FutureOr<dynamic> ensureStored(O o, {Transaction? transaction});

  FutureOr<bool> ensureReferencesStored(O o, {Transaction? transaction});

  @override
  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  @override
  FutureOr<int> countByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var condition = _parseCache.parseQuery(query);

    return count(
        matcher: condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  @override
  FutureOr<Iterable<O>> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    checkNotClosed();

    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        limit: limit);
  }

  @override
  FutureOr<Iterable<O>> deleteByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var condition = _parseCache.parseQuery(query);

    return delete(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  Map<String, dynamic> information();

  @override
  String toString() {
    var info = information();
    return 'EntityRepository{ name: $name, provider: $provider, type: $type, information: $info }';
  }
}

/// A [Transaction] abortion error.
class TransactionAbortedError extends Error {
  String? reason;
  Object? payload;

  TransactionAbortedError({this.reason, this.payload});

  @override
  String toString() {
    return 'TransactionAbortedError{reason: $reason, payload: $payload}';
  }
}

typedef ErrorFilter = bool Function(Object, StackTrace);

typedef TransactionExecution<R, C> = FutureOr<R> Function(C context);

/// An [EntityRepository] transaction.
class Transaction extends JsonEntityCacheSimple implements EntityProvider {
  static Transaction? _executingTransaction;

  static Transaction? get executingTransaction => _executingTransaction;

  static int _idCount = 0;
  final int id = ++_idCount;

  final List<TransactionOperation> _operations = <TransactionOperation>[];

  final List<TransactionOperation> _executedOperations =
      <TransactionOperation>[];

  final bool autoCommit;

  late final Completer _transactionCompleter;

  Future get transactionFuture => _transactionCompleter.future;

  late final Completer _resultCompleter;

  Future get resultFuture => _resultCompleter.future;

  late final Completer<bool> _openCompleter;

  Transaction({this.autoCommit = false}) : super() {
    _transactionCompleter = _errorZone.createCompleter();
    _resultCompleter = _errorZone.createCompleter();
    _openCompleter = _errorZone.createCompleter<bool>();
  }

  Transaction.autoCommit() : this(autoCommit: true);

  factory Transaction.executingOrNew({bool autoCommit = true}) {
    return _executingTransaction ?? Transaction(autoCommit: autoCommit);
  }

  static Zone? _errorZoneInstance;

  static Zone get _errorZone {
    return _errorZoneInstance ??= createErrorZone(
        uncaughtErrorTitle: '', onUncaughtError: _onErrorZoneUncaughtError);
  }

  static void _onErrorZoneUncaughtError(Object error, StackTrace stackTrace) {
    if (error is TransactionAbortedError ||
        isFilteredError(error, stackTrace)) {
      return;
    }

    printZoneError(error, stackTrace, title: '[Transaction ERROR]');
  }

  static final Set<ErrorFilter> _errorFilters = <ErrorFilter>{};

  static void registerErrorFilter(ErrorFilter errorFilter) {
    _errorFilters.add(errorFilter);
  }

  static bool isFilteredError(Object error, StackTrace stackTrace) {
    if (_errorFilters.isEmpty) return false;

    for (var f in _errorFilters) {
      if (f(error, stackTrace)) {
        return true;
      }
    }

    return false;
  }

  bool get isExecuting => identical(Transaction.executingTransaction, this);

  bool _committed = false;

  bool get isCommitted => _committed;

  int get length => _operations.length;

  bool get isEmpty => _operations.isEmpty;

  bool get isNotEmpty => _operations.isNotEmpty;

  int get notExecutedOperationsSize =>
      _operations.length - _executedOperations.length;

  bool isLastExecutingOperation(TransactionOperation op) {
    if (isEmpty) return false;

    var notExecuted = notExecutedOperationsSize;
    if (notExecuted > 1) {
      return false;
    }

    if (!_operations.contains(op)) {
      throw StateError("Operation not in transaction: $op");
    }

    if (notExecuted == 1) {
      return !_executedOperations.contains(op);
    } else {
      return _executedOperations.last == op;
    }
  }

  bool _opening = false;

  bool get isOpening => _opening;

  void open(FutureOr<Object> Function() opener) {
    _opening = true;

    asyncTry(opener, then: (c) {
      _setContext(c!);
      return c;
    }, onError: (e, s) {
      print(e);
      print(s);
    });
  }

  bool _open = false;

  bool get isOpen => _open;

  Object? _context;

  Object? get context => _context;

  void _setContext(Object context) {
    _context = context;
    _open = true;
    _openCompleter.complete(true);
  }

  FutureOr<R> onOpen<R>(FutureOr<R> Function() f) {
    if (_open) {
      return f();
    } else {
      return _openCompleter.future.then((_) {
        return f();
      });
    }
  }

  FutureOr? transactionResult;

  Object? _result;

  Object? get result => _result;

  void addOperation(TransactionOperation op) {
    if (_operations.contains(op)) {
      throw StateError("Operation already in transaction: $op");
    }
    _operations.add(op);
    op.id = _operations.length;
  }

  FutureOr<R> finishOperation<R>(TransactionOperation op, R result) {
    _markOperationExecuted(op, result);

    if (op.transactionRoot && !op.externalTransaction && length > 1) {
      return resultFuture.then((_) => result);
    } else {
      return result;
    }
  }

  Completer<bool>? _waitingExecutedOperation;

  Object? _lastResult;

  void _markOperationExecuted(TransactionOperation op, Object? result) {
    if (_executedOperations.contains(op)) {
      throw StateError("Operation already executed in transaction: $op");
    }
    _executedOperations.add(op);

    _lastResult = result;

    var waitingExecutedOperation = _waitingExecutedOperation;
    if (waitingExecutedOperation != null &&
        !waitingExecutedOperation.isCompleted) {
      waitingExecutedOperation.complete(true);
      _waitingExecutedOperation = null;
    }

    _doAutoCommit();
  }

  FutureOr<bool> waitAllExecuted() {
    if (_executedOperations.length == _operations.length) {
      return true;
    }
    return _waitAllExecutedImpl();
  }

  Future<bool> _waitAllExecutedImpl() async {
    while (_executedOperations.length < _operations.length) {
      var completer = _waitingExecutedOperation ??= Completer<bool>();
      await completer.future;
    }
    return true;
  }

  void _doAutoCommit() {
    if (autoCommit && _executedOperations.length == _operations.length) {
      commit();
    }
  }

  bool _commitCalled = false;

  FutureOr<R?> commit<R>() {
    if (_aborted) {
      return _abortImpl().resolveMapped((_) => null);
    }

    if (_commitCalled) {
      FutureOr<dynamic> retFuture;
      if (transactionResult != null) {
        retFuture = transactionResult;
      } else {
        retFuture = _transactionCompleter.future;
      }
      return retFuture.resolveMapped((r) => r as R?);
    }

    _commitCalled = true;

    return waitAllExecuted().resolveMapped((_) => _commitImpl<R>());
  }

  FutureOr<R?> _commitImpl<R>() {
    var result = _lastResult;
    _result = result;

    _transactionCompleter.complete(result);

    if (transactionResult != null) {
      return transactionResult!.resolveMapped((r) {
        _committed = true;
        _resultCompleter.complete(r);
        return r as R?;
      });
    } else {
      return _transactionCompleter.future.then((r) {
        _committed = true;
        _resultCompleter.complete(r);
        return r as R?;
      });
    }
  }

  bool _aborted = false;

  /// Returns `true` if this transaction as aborted. See [abort].
  bool get isAborted => _aborted;

  TransactionAbortedError? _abortedError;

  /// Returns the abort error ([TransactionAbortedError]).
  TransactionAbortedError? get abortedError => _abortedError;

  /// Abort this transaction.
  FutureOr<TransactionAbortedError?> abort({String? reason, Object? payload}) {
    if (_commitCalled) {
      return null;
    }

    if (_aborted) {
      return _abortedError;
    }

    payload ??= _lastResult;
    var abortError = TransactionAbortedError(reason: reason, payload: payload);

    _abortedError = abortError;
    _aborted = true;

    return abortError;
  }

  FutureOr<TransactionAbortedError> _abortImpl() {
    var abortError = _abortedError!;

    _transactionCompleter.completeError(abortError);

    if (transactionResult != null) {
      if (transactionResult is Future) {
        return (transactionResult as Future).then((r) {
          _resultCompleter.complete(null);
          return abortError;
        }, onError: (e) {
          return abortError;
        });
      } else {
        return transactionResult!.resolveMapped((r) {
          _resultCompleter.complete(null);
          return abortError;
        });
      }
    } else {
      return _transactionCompleter.future.then((r) {
        _resultCompleter.complete(null);
        return abortError;
      }, onError: (e) {
        _resultCompleter.complete(null);
        return abortError;
      });
    }
  }

  /// Executes the transaction operations dispatches inside [block] then [commit]s.
  FutureOr<R?> execute<R>(FutureOr<R?> Function() block) {
    if (_commitCalled) {
      throw StateError('Transaction committed already dispatched: $this');
    }

    if (_executingTransaction != null) {
      throw StateError(
          'Already executing a Transaction: _executingTransaction');
    }

    _executingTransaction = this;

    return _errorZone.asyncTry<R?>(block, onFinally: () {
      return asyncTry(() => commit<Object?>(), onFinally: () {
        _executingTransaction = null;
      });
    });
  }

  final List<FutureOr> _executionsFutures = <FutureOr>[];

  FutureOr<R> addExecution<R, C>(TransactionExecution<R, C> exec) {
    if (_executionsFutures.isEmpty) {
      var ret = exec(context! as C);
      _executionsFutures.add(ret);
      return ret;
    } else {
      var last = _executionsFutures.last;

      var ret = last.resolveWith(() {
        return exec(context! as C);
      });

      _executionsFutures.add(ret);
      return ret;
    }
  }

  @override
  FutureOr<O?> getEntityByID<O>(id, {Type? type}) =>
      getCachedEntityByID(id, type: type);

  @override
  String toString() {
    return [
      'Transaction[#$id]{\n',
      '  open: $isOpen\n',
      '  executing: $isExecuting\n',
      '  committed: $isCommitted\n',
      '  aborted: $isAborted\n',
      '  abortedError: $abortedError\n',
      '  cachedEntities: $cachedEntitiesLength\n',
      '  operations: [\n',
      if (_operations.isNotEmpty) '    ${_operations.join(',\n    ')}',
      '\n  ],\n',
      '  executedOperations: [\n',
      if (_executedOperations.isNotEmpty)
        '    ${_executedOperations.join(',\n    ')}',
      '\n  ]\n',
      '  result: $_result\n',
      '}'
    ].join();
  }
}

abstract class TransactionOperation {
  final TransactionOperationType type;
  final String repositoryName;
  Object? command;

  int? id;

  late final Transaction transaction;
  late final bool externalTransaction;
  late final bool transactionRoot;

  TransactionOperation(
      this.type, this.repositoryName, Transaction? transaction) {
    externalTransaction = transaction != null;

    var resolvedTransaction = transaction ?? Transaction.executingOrNew();
    this.transaction = resolvedTransaction;

    transactionRoot =
        resolvedTransaction.isEmpty && !resolvedTransaction.isExecuting;

    resolvedTransaction.addOperation(this);
  }

  int get transactionId => transaction.id;

  TransactionExecution? execution;

  String get _commandToString => command == null ? '' : ', command: $command';

  FutureOr<R> finish<R>(R result) => transaction.finishOperation(this, result);
}

class TransactionOperationSelect<O> extends TransactionOperation {
  final EntityMatcher matcher;

  TransactionOperationSelect(String repositoryName, this.matcher,
      [Transaction? transaction])
      : super(TransactionOperationType.select, repositoryName, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:select@$repositoryName]{matcher: $matcher$_commandToString}';
  }
}

class TransactionOperationCount<O> extends TransactionOperation {
  final EntityMatcher? matcher;

  TransactionOperationCount(String repositoryName,
      [this.matcher, Transaction? transaction])
      : super(TransactionOperationType.count, repositoryName, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:count@$repositoryName]{matcher: $matcher$_commandToString}';
  }
}

class TransactionOperationStore<O> extends TransactionOperation {
  final O entity;

  TransactionOperationStore(String repositoryName, this.entity,
      [Transaction? transaction])
      : super(TransactionOperationType.store, repositoryName, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:store@$repositoryName]{entity: $entity$_commandToString}';
  }
}

class TransactionOperationUpdate<O> extends TransactionOperation {
  final O entity;

  TransactionOperationUpdate(String repositoryName, this.entity,
      [Transaction? transaction])
      : super(TransactionOperationType.update, repositoryName, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:update@$repositoryName]{entity: $entity$_commandToString}';
  }
}

class TransactionOperationStoreRelationship<O, E> extends TransactionOperation {
  final O entity;
  final List<E> others;

  TransactionOperationStoreRelationship(
      String repositoryName, this.entity, this.others,
      [Transaction? transaction])
      : super(TransactionOperationType.storeRelationship, repositoryName,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:storeRelationship@$repositoryName]{entity: $entity, other: $others$_commandToString}';
  }
}

class TransactionOperationConstrainRelationship<O, E>
    extends TransactionOperation {
  final O entity;
  final List<E> others;

  TransactionOperationConstrainRelationship(
      String repositoryName, this.entity, this.others,
      [Transaction? transaction])
      : super(TransactionOperationType.constrainRelationship, repositoryName,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:constrainRelationship@$repositoryName]{entity: $entity, other: $others$_commandToString}';
  }
}

class TransactionOperationSelectRelationship<O> extends TransactionOperation {
  final O entity;

  TransactionOperationSelectRelationship(String repositoryName, this.entity,
      [Transaction? transaction])
      : super(TransactionOperationType.selectRelationship, repositoryName,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:selectRelationship@$repositoryName]{entity: $entity$_commandToString}';
  }
}

class TransactionOperationSelectRelationships<O> extends TransactionOperation {
  final List<O> entities;

  TransactionOperationSelectRelationships(String repositoryName, this.entities,
      [Transaction? transaction])
      : super(TransactionOperationType.selectRelationships, repositoryName,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:selectRelationships@$repositoryName]{entities: $entities$_commandToString}';
  }
}

class TransactionOperationDelete<O> extends TransactionOperation {
  final EntityMatcher matcher;

  TransactionOperationDelete(String repositoryName, this.matcher,
      [Transaction? transaction])
      : super(TransactionOperationType.delete, repositoryName, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id:delete@$repositoryName]{matcher: $matcher$_commandToString}';
  }
}

enum TransactionOperationType {
  select,
  count,
  store,
  storeRelationship,
  constrainRelationship,
  selectRelationship,
  selectRelationships,
  update,
  delete
}

extension TransactionOperationTypeExtension on TransactionOperationType {
  String get name {
    switch (this) {
      case TransactionOperationType.select:
        return 'select';
      case TransactionOperationType.count:
        return 'count';
      case TransactionOperationType.store:
        return 'store';
      case TransactionOperationType.storeRelationship:
        return 'storeRelationship';
      case TransactionOperationType.constrainRelationship:
        return 'constrainRelationship';
      case TransactionOperationType.selectRelationship:
        return 'selectRelationship';
      case TransactionOperationType.update:
        return 'update';
      case TransactionOperationType.delete:
        return 'delete';
      default:
        throw ArgumentError("Unknown: $this");
    }
  }
}

abstract class IterableEntityRepository<O extends Object>
    extends EntityRepository<O> with EntityFieldAccessor<O> {
  IterableEntityRepository(String name, EntityHandler<O> entityHandler,
      {EntityRepositoryProvider? provider})
      : super(provider, name, entityHandler);

  Iterable<O> iterable();

  dynamic nextID();

  void put(O o);

  void remove(O o);

  @override
  FutureOr<int> count(
      {EntityMatcher<O>? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    if (matcher == null) {
      return iterable().length;
    }

    return iterable().where((o) {
      return matcher.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    }).length;
  }

  @override
  Iterable<O> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    checkNotClosed();

    var os = matches(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        limit: limit);

    return trackEntities(os);
  }

  @override
  O? selectByID(id, {Transaction? transaction}) {
    checkNotClosed();

    var o = iterable().firstWhereOrNull((o) {
      var oId = getID(o, entityHandler: entityHandler);
      return oId == id;
    });

    return trackEntityNullable(o);
  }

  @override
  bool isStored(O o, {Transaction? transaction}) {
    var id = entityHandler.getID(o);
    return id != null;
  }

  @override
  dynamic store(O o, {Transaction? transaction}) {
    checkNotClosed();

    var op = TransactionOperationStore(name, o, transaction);

    return ensureReferencesStored(o, transaction: op.transaction)
        .resolveWith(() {
      var oId = getID(o, entityHandler: entityHandler);

      if (oId == null) {
        oId = nextID();
        setID(o, oId, entityHandler: entityHandler);
        put(o);
      }

      op.transaction._markOperationExecuted(op, oId);

      return oId;
    });
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.autoCommit();
    return os.map((o) => store(o, transaction: transaction)).toList();
  }

  @override
  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction}) {
    checkNotClosed();

    fieldType ??= entityHandler.getFieldType(o, field)!;

    var op =
        TransactionOperationStoreRelationship(name, o, values, transaction);

    var valuesType = fieldType.listEntityType.type;
    var valuesRepository = provider.getEntityRepository<E>(type: valuesType)!;

    var oId = getID(o, entityHandler: entityHandler);

    var valuesIds = values.map((e) => valuesRepository.entityHandler.getID(e));

    var valuesIdsNotNull = IterableNullableExtension(valuesIds).whereNotNull();

    return putRelationship(oId, valuesType, valuesIdsNotNull)
        .resolveMapped((ok) {
      op.transaction._markOperationExecuted(op, ok);
      return ok;
    });
  }

  FutureOr<bool> putRelationship(
      Object oId, Type valuesType, Iterable<Object> valuesIds);

  @override
  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
      {Object? oId, TypeInfo? fieldType, Transaction? transaction}) {
    checkNotClosed();

    fieldType ??= entityHandler.getFieldType(o, field)!;
    oId ??= getID(o!, entityHandler: entityHandler)!;
    var valuesType = fieldType.listEntityType.type;

    var op =
        TransactionOperationSelectRelationship(name, o ?? oId, transaction);

    var valuesIds = getRelationship(oId!, valuesType);
    op.transaction._markOperationExecuted(op, valuesIds);

    return valuesIds;
  }

  @override
  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
      List<O>? os, String field,
      {List<dynamic>? oIds, TypeInfo? fieldType, Transaction? transaction}) {
    oIds ??= os!
        .map((o) => getID(o, entityHandler: entityHandler)! as Object)
        .toList();

    if (oIds.isEmpty) {
      return <dynamic, Iterable<dynamic>>{};
    }

    var entries = oIds.map((oId) {
      var objs = selectRelationship(null, field,
          oId: oId, fieldType: fieldType, transaction: transaction);
      return MapEntry(oId, objs);
    }).toList();

    var results =
        Map<dynamic, FutureOr<Iterable<dynamic>>>.fromEntries(entries);
    return results.resolveAllValues();
  }

  List<Object> getRelationship(Object oId, Type valuesType);

  @override
  FutureOr<dynamic> ensureStored(O o, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.autoCommit();

    var id = getID(o, entityHandler: entityHandler);

    if (id == null || entityHasChangedFields(o)) {
      return store(o, transaction: transaction);
    } else {
      return ensureReferencesStored(o, transaction: transaction)
          .resolveWithValue(id);
    }
  }

  @override
  FutureOr<bool> ensureReferencesStored(O o, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.autoCommit();

    var fieldsNames = entityHandler.fieldsNames(o);

    var futures = fieldsNames.map((fieldName) {
      var value = entityHandler.getField(o, fieldName);
      if (value == null) return null;

      var fieldType = entityHandler.getFieldType(o, fieldName)!;

      if (!EntityHandler.isValidType(fieldType.type)) {
        return null;
      }

      if (value is List && fieldType.isList && fieldType.hasArguments) {
        var elementType = fieldType.arguments.first;

        var elementRepository =
            provider.getEntityRepository(type: elementType.type);
        if (elementRepository == null) return null;

        var futures = value.map((e) {
          return elementRepository.ensureStored(e, transaction: transaction);
        }).toList();

        return futures.resolveAll();
      } else {
        var repository =
            provider.getEntityRepository(type: fieldType.type, obj: value);
        if (repository == null) return null;

        return repository.ensureStored(value, transaction: transaction);
      }
    });

    return futures.resolveAllWithValue(true);
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var del = matches(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    for (var o in del) {
      remove(o);
    }

    untrackEntities(del);

    return del;
  }

  List<O> matches(EntityMatcher<dynamic> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit}) {
    var itr = iterable().where((o) {
      return matcher.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    });

    if (limit != null && limit > 0) {
      itr = itr.take(limit);
    }

    return itr.toList();
  }

  @override
  Map<String, dynamic> information() => {
        'length': length(),
        'nextID': nextID(),
      };
}

class SetEntityRepository<O extends Object>
    extends IterableEntityRepository<O> {
  SetEntityRepository(String name, EntityHandler<O> entityHandler,
      {EntityRepositoryProvider? provider})
      : super(name, entityHandler, provider: provider);

  final Set<O> _entries = <O>{};

  @override
  Iterable<O> iterable() => _entries;

  @override
  int nextID() => _entries.length + 1;

  @override
  int length({Transaction? transaction}) => _entries.length;

  @override
  void put(O o) {
    _entries.add(o);
  }

  @override
  void remove(O o) {
    _entries.remove(o);
  }

  final Map<Type, Map<Object, Set<Object>>> _relationships =
      <Type, Map<Object, Set<Object>>>{};

  @override
  FutureOr<bool> putRelationship(
      Object oId, Type valuesType, Iterable<Object> valuesIds) {
    var typeRelationships =
        _relationships.putIfAbsent(valuesType, () => <Object, Set<Object>>{});

    typeRelationships[oId] = valuesIds.toSet();

    return true;
  }

  @override
  List<Object> getRelationship(Object oId, Type valuesType) {
    var typeRelationships = _relationships[valuesType];

    var idReferences = typeRelationships?[oId];

    return idReferences?.toList() ?? <Object>[];
  }
}
