// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

library sandbox;
import "dart-ext:dart_sandbox";
import "dart:core";
import "dart:io";
import "dart:uri";

class _TrackingMap implements Map {
  Map _map = new Map();
  var _newKeys;
  _TrackingMap() : _newKeys = new Set<String>();

  operator []= (key, value) {
    if (!_map.containsKey(key)) _newKeys.add(key);
    return _map[key] = value;
  }

  _getNewKeys() {
    try {
      return _newKeys;
    } finally {
      _newKeys = new Set<String>();
    }
  }

  Collection get values => _map.values;
  Collection get keys => _map.keys;
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool containsValue(dynamic value) => _map.containsValue(value);
  bool containsKey(dynamic key) => _map.containsKey(key);
  dynamic operator [] (key) => _map[key];
  dynamic putIfAbsent(dynamic key, dynamic ifAbsent()) => _map.putIfAbsent(key, ifAbsent);
  forEach(void f(dynamic k, dynamic v)) => _map.forEach(f);
  dynamic remove(dynamic key) => _map.remove(key);
  clear() => _map.clear();
}

class Sandbox {
  var _library;
  var _variables = {};

  Map<String, Object> get variables => _variables;

  Sandbox() {
    print("constructor sandbox");
    var uniquer = _unique();
    _library = _createLibrary("console:$uniquer", "library console_$uniquer;\nimport 'dart:io' as io;\nget VARIABLES => _Env._map;\n_seedEnv(map) => _Env._map = map;\nprint(o) {\nio.stdout.writeString(o);\n}\nclass _Env {\n  static var _map;\n  noSuchMethod(mirror) {\n    var name = mirror.memberName;\n    var args = mirror.positionalArguments;\n    if (name.startsWith('set:')) {\n      return _map[name.substring(4)] = args[0];\n    } else if (name.startsWith('get:') && _map.containsKey(name.substring(4))) {\n      return _map[name.substring(4)];\n    }\n    return super.noSuchMethod(mirror);\n  }\n}");
    print("_library = ");
    print(_library);
//    _initEnvMap(_library, _variables);
  }

  eval(expression) {
    return execute("return (\n$expression\n);");
  }

  execute(code) {
    var directiveMatch = new RegExp('^\\s*\\#(source|import)\\s*\\(["\'](.*)["\']\\)\\s*;\\s*\$').firstMatch(code);
    if (directiveMatch != null) return ((directiveMatch[1] == 'source') ? source : import)(directiveMatch[2]);

    var uniquer = _unique();
    _library = _createLibrary("console:$uniquer", "library console_$uniquer;\nimport 'dart:io' as io;\nget VARIABLES => _Env._map;\n_seedEnv(map) => _Env._map = map;\nprint(o) {\nio.stdout.writeString(o);\n}\nclass _Env {\n  static var _map;\n  noSuchMethod(mirror) {\n    var name = mirror.memberName;\n    var args = mirror.positionalArguments;\n    if (name.startsWith('set:')) {\n      return _map[name.substring(4)] = args[0];\n    } else if (name.startsWith('get:') && _map.containsKey(name.substring(4))) {\n      return _map[name.substring(4)];\n    }\n    return super.noSuchMethod(mirror);\n  }\n}");

    var name = "_Eval${_unique()}";
    var body = """
      
      class $name extends _Env {
        _execute(){\n$code\n}
      }
      ${name}_execute() => new $name()._execute();
    """;
    declare(body);
    print("_library = ${_library}");
    return _invoke(_library, "${name}_execute");
  }

  void import(relativeUri) {
    var uri = new Uri.fromComponents(scheme:"file", path:"${new Directory.current().path}/").resolve(relativeUri);
    var readFile = () => new File(relativeUri).readAsStringSync();
    return _import(_library, uri.toString(), readFile);
  }

  void source(relativeUri) {
    var uri = new Uri.fromComponents(scheme:"file", path:"${new Directory.current().path}/").resolve(relativeUri);
    var code = new File(relativeUri).readAsStringSync();
    return _declare(_library, uri.toString(), code);
  }

  void declare(code) {
    // Create getters for any new variables set so they are accessible from declarations.
    for (var v in _variables.keys.toList()) {
      declare("get $v => VARIABLES['$v']; set $v(v) => VARIABLES['$v'] = v;");
    }
    _declare(_library, "console_declaration_${_unique()}", code);

    print(code);
  }

  static var _uniqueSeed = 2;
  static _unique() => _uniqueSeed++;
}

_createLibrary(url, source) native "NewLibrary";
_declare(library, id, code) native "Declare";
_import(library, importName, importClosure) native "Import";
_invoke(library, className) native "Invoke";
_initEnvMap(library, map) native "InitEnvMap";
