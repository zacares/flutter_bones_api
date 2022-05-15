//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.1.1
// BUILD COMMAND: dart run build_runner build
//

// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test.dart';

// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJson(Map<String, Object?> map) =>
    MyInfoModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJsonEncoded(String jsonEncoded) =>
    MyInfoModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class MyInfoModule$reflection extends ClassReflection<MyInfoModule> {
  MyInfoModule$reflection([MyInfoModule? object]) : super(MyInfoModule, object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('2.14.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.1.1');

  @override
  MyInfoModule$reflection withObject([MyInfoModule? obj]) =>
      MyInfoModule$reflection(obj);

  static MyInfoModule$reflection? _withoutObjectInstance;
  @override
  MyInfoModule$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as MyInfoModule$reflection;

  static MyInfoModule$reflection get staticInstance =>
      _withoutObjectInstance ??= MyInfoModule$reflection();

  @override
  MyInfoModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    MyInfoModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  MyInfoModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  MyInfoModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  MyInfoModule? createInstanceWithNoRequiredArgsConstructor() => null;

  @override
  List<String> get constructorsNames => const <String>[''];

  @override
  ConstructorReflection<MyInfoModule>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<MyInfoModule>(
            this,
            MyInfoModule,
            '',
            () => (APIRoot apiRoot) => MyInfoModule(apiRoot),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection(APIRoot), 'apiRoot', false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<ClassReflection> siblingsClassReflection() =>
      _siblingsReflection().whereType<ClassReflection>().toList();

  @override
  List<Reflection> siblingsReflection() => _siblingsReflection();

  @override
  List<Type> get supperTypes => const <Type>[APIModule, Initializable];

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([MyInfoModule? obj]) => null;

  @override
  List<String> get fieldsNames => const <String>[
        'allRoutesNames',
        'apiConfig',
        'apiRoot',
        'authenticationRoute',
        'defaultRouteName',
        'hashCode',
        'isInitialized',
        'name',
        'routes',
        'security',
        'version'
      ];

  @override
  FieldReflection<MyInfoModule, T>? field<T>(String fieldName,
      [MyInfoModule? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot as T,
          null,
          obj,
          false,
          true,
          null,
        );
      case 'name':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'name',
          false,
          (o) => () => o!.name as T,
          null,
          obj,
          false,
          true,
          null,
        );
      case 'version':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'version',
          true,
          (o) => () => o!.version as T,
          null,
          obj,
          false,
          true,
          null,
        );
      case 'apiconfig':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'defaultroutename':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'defaultRouteName',
          true,
          (o) => () => o!.defaultRouteName as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'allroutesnames':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection.tSetString,
          'allRoutesNames',
          false,
          (o) => () => o!.allRoutesNames as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'routes':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection(APIRouteBuilder, [APIModule]),
          'routes',
          false,
          (o) => () => o!.routes as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'authenticationroute':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'authenticationRoute',
          false,
          (o) => () => o!.authenticationRoute as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'security':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection(APISecurity),
          'security',
          true,
          (o) => () => o!.security as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<MyInfoModule, T>(
          this,
          APIModule,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'isinitialized':
        return FieldReflection<MyInfoModule, T>(
          this,
          Initializable,
          TypeReflection.tBool,
          'isInitialized',
          false,
          (o) => () => o!.isInitialized as T,
          null,
          obj,
          false,
          false,
          null,
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<MyInfoModule, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
        'acceptsRequest',
        'addRoute',
        'apiInfo',
        'call',
        'checkInitialized',
        'configure',
        'echo',
        'ensureConfigured',
        'ensureInitialized',
        'ensureInitializedAsync',
        'getRouteHandler',
        'getRouteHandlerByRequest',
        'getRoutesHandlersNames',
        'initialize',
        'initializeDependencies',
        'initializeImpl',
        'resolveRoute',
        'toUpperCase'
      ];

  @override
  MethodReflection<MyInfoModule, R>? method<R>(String methodName,
      [MyInfoModule? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<MyInfoModule, R>(
            this,
            MyInfoModule,
            'configure',
            TypeReflection.tVoid,
            false,
            (o) => o!.configure,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'echo':
        return MethodReflection<MyInfoModule, R>(
            this,
            MyInfoModule,
            'echo',
            TypeReflection(FutureOr, [
              TypeReflection(APIResponse, [String])
            ]),
            false,
            (o) => o!.echo,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'msg', false, true, null, null),
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'touppercase':
        return MethodReflection<MyInfoModule, R>(
            this,
            MyInfoModule,
            'toUpperCase',
            TypeReflection(FutureOr, [
              TypeReflection(APIResponse, [String])
            ]),
            false,
            (o) => o!.toUpperCase,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'msg', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'ensureConfigured',
            TypeReflection.tVoid,
            false,
            (o) => o!.ensureConfigured,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'initializeimpl':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'initializeImpl',
            TypeReflection.tFutureOrBool,
            false,
            (o) => o!.initializeImpl,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getrouteshandlersnames':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'getRoutesHandlersNames',
            TypeReflection(Iterable, [String]),
            false,
            (o) => o!.getRoutesHandlersNames,
            obj,
            false,
            null,
            null,
            const <String, ParameterReflection>{
              'method': ParameterReflection(TypeReflection(APIRequestMethod),
                  'method', true, false, null, null)
            },
            null);
      case 'addroute':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'addRoute',
            TypeReflection(APIModule),
            false,
            (o) => o!.addRoute,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequestMethod), 'method',
                  true, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'name', false, true, null, null),
              ParameterReflection(TypeReflection(APIRouteFunction, [dynamic]),
                  'function', false, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'parameters': ParameterReflection(
                  TypeReflection(Map, [String, TypeInfo]),
                  'parameters',
                  true,
                  false,
                  null,
                  null),
              'rules': ParameterReflection(
                  TypeReflection(Iterable, [APIRouteRule]),
                  'rules',
                  true,
                  false,
                  null,
                  null)
            },
            null);
      case 'getroutehandler':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'getRouteHandler',
            TypeReflection(APIRouteHandler, [dynamic]),
            true,
            (o) => o!.getRouteHandler,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'name', false, true, null, null)
            ],
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequestMethod), 'method',
                  true, false, null, null)
            ],
            null,
            null);
      case 'getroutehandlerbyrequest':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            TypeReflection(APIRouteHandler, [dynamic]),
            true,
            (o) => o!.getRouteHandlerByRequest,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'resolveroute':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'resolveRoute',
            TypeReflection.tString,
            false,
            (o) => o!.resolveRoute,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'call':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'call',
            TypeReflection(FutureOr, [
              TypeReflection(APIResponse, [dynamic])
            ]),
            false,
            (o) => o!.call,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'acceptsrequest':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'acceptsRequest',
            TypeReflection.tBool,
            false,
            (o) => o!.acceptsRequest,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'apiRequest',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      case 'apiinfo':
        return MethodReflection<MyInfoModule, R>(
            this,
            APIModule,
            'apiInfo',
            TypeReflection(APIModuleInfo),
            false,
            (o) => o!.apiInfo,
            obj,
            false,
            null,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'apiRequest',
                  true, false, null, null)
            ],
            null,
            null);
      case 'ensureinitialized':
        return MethodReflection<MyInfoModule, R>(
            this,
            Initializable,
            'ensureInitialized',
            TypeReflection.tFutureOrBool,
            false,
            (o) => o!.ensureInitialized,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'ensureinitializedasync':
        return MethodReflection<MyInfoModule, R>(
            this,
            Initializable,
            'ensureInitializedAsync',
            TypeReflection.tFutureOrBool,
            false,
            (o) => o!.ensureInitializedAsync,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'initialize':
        return MethodReflection<MyInfoModule, R>(
            this,
            Initializable,
            'initialize',
            TypeReflection.tFutureOrBool,
            false,
            (o) => o!.initialize,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'initializedependencies':
        return MethodReflection<MyInfoModule, R>(
            this,
            Initializable,
            'initializeDependencies',
            TypeReflection(FutureOr, [
              TypeReflection(List, [Initializable])
            ]),
            false,
            (o) => o!.initializeDependencies,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'checkinitialized':
        return MethodReflection<MyInfoModule, R>(
            this,
            Initializable,
            'checkInitialized',
            TypeReflection.tVoid,
            false,
            (o) => o!.checkInitialized,
            obj,
            false,
            null,
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<MyInfoModule, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

extension MyInfoModule$reflectionExtension on MyInfoModule {
  /// Returns a [ClassReflection] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  ClassReflection<MyInfoModule> get reflection => MyInfoModule$reflection(this);

  /// Returns a JSON for type [MyInfoModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded(
          {bool pretty = false, bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonEncoded(
          pretty: pretty, duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [MyInfoModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension MyInfoModuleProxy$reflectionProxy on MyInfoModuleProxy {
  Future<String> echo(String msg) {
    var ret = onCall(
        this,
        'echo',
        <String, dynamic>{
          'msg': msg,
        },
        TypeReflection.tFutureString);
    return ret is Future<String>
        ? ret as Future<String>
        : (ret is Future
            ? ret.then((v) => v as String)
            : Future<String>.value(ret as dynamic));
  }

  Future<String> toUpperCase(String msg) {
    var ret = onCall(
        this,
        'toUpperCase',
        <String, dynamic>{
          'msg': msg,
        },
        TypeReflection.tFutureString);
    return ret is Future<String>
        ? ret as Future<String>
        : (ret is Future
            ? ret.then((v) => v as String)
            : Future<String>.value(ret as dynamic));
  }

  Future<bool> initializeImpl() {
    var ret = onCall(this, 'initializeImpl', <String, dynamic>{},
        TypeReflection.tFutureBool);
    return ret is Future<bool>
        ? ret as Future<bool>
        : (ret is Future
            ? ret.then((v) => v as bool)
            : Future<bool>.value(ret as dynamic));
  }

  Future<bool> ensureInitialized() {
    var ret = onCall(this, 'ensureInitialized', <String, dynamic>{},
        TypeReflection.tFutureBool);
    return ret is Future<bool>
        ? ret as Future<bool>
        : (ret is Future
            ? ret.then((v) => v as bool)
            : Future<bool>.value(ret as dynamic));
  }

  Future<bool> ensureInitializedAsync() {
    var ret = onCall(this, 'ensureInitializedAsync', <String, dynamic>{},
        TypeReflection.tFutureBool);
    return ret is Future<bool>
        ? ret as Future<bool>
        : (ret is Future
            ? ret.then((v) => v as bool)
            : Future<bool>.value(ret as dynamic));
  }

  Future<bool> initialize() {
    var ret = onCall(
        this, 'initialize', <String, dynamic>{}, TypeReflection.tFutureBool);
    return ret is Future<bool>
        ? ret as Future<bool>
        : (ret is Future
            ? ret.then((v) => v as bool)
            : Future<bool>.value(ret as dynamic));
  }

  Future<List<Initializable>> initializeDependencies() {
    var ret = onCall(
        this,
        'initializeDependencies',
        <String, dynamic>{},
        TypeReflection(Future, [
          TypeReflection(List, [Initializable])
        ]));
    return ret is Future<List<Initializable>>
        ? ret as Future<List<Initializable>>
        : (ret is Future
            ? ret.then((v) => v as List<Initializable>)
            : Future<List<Initializable>>.value(ret as dynamic));
  }

  Future<void> checkInitialized() {
    var ret = onCall(this, 'checkInitialized', <String, dynamic>{},
        TypeReflection(Future, [TypeReflection.tVoid]));
    return ret is Future<void>
        ? ret as Future<void>
        : (ret is Future
            ? ret.then((v) => v as dynamic)
            : Future<void>.value(ret as dynamic));
  }
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
      MyInfoModule$reflection(),
    ];

List<Reflection>? _siblingsReflectionList;
List<Reflection> _siblingsReflection() => _siblingsReflectionList ??=
    List<Reflection>.unmodifiable(_listSiblingsReflection());

bool _registerSiblingsReflectionCalled = false;
void _registerSiblingsReflection() {
  if (_registerSiblingsReflectionCalled) return;
  _registerSiblingsReflectionCalled = true;
  var length = _listSiblingsReflection().length;
  assert(length > 0);
}
