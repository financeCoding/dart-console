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
  final _BASE = r"""
  #import('dart:io', prefix: 'io');
  get VARIABLES => _Env._map;
  _seedEnv(map) => _Env._map = map;
  class _Env {
    static var _map;
    noSuchMethod(mirror) {
      var name = mirror.memberName;
      var args = mirror.positionalArguments;
      if (name.startsWith('set:')) {
        return _map[name.substring(4)] = args[0];
      } else if (name.startsWith('get:') && _map.containsKey(name.substring(4))) {
        return _map[name.substring(4)];
      }
      return super.noSuchMethod(name, args);
    }
  }
  print(o) { // otherwise this is missing for some reason
    io.stdout.writeString("$o\n");
  }
  """;

  var _library;
  var _variables;

  Map<String, Object> get variables => _variables;

  Sandbox() : _variables = new _TrackingMap() {
    var uniquer = _unique();
    _library = _createLibrary("console:$uniquer", "#library('console_$uniquer');\n$_BASE");
    _initEnvMap(_library, _variables);
  }

  eval(expression) {
    return execute("return (\n$expression\n);");
  }

  execute(code) {
    var directiveMatch = new RegExp('^\\s*\\#(source|import)\\s*\\(["\'](.*)["\']\\)\\s*;\\s*\$').firstMatch(code);
    if (directiveMatch != null) return ((directiveMatch[1] == 'source') ? source : import)(directiveMatch[2]);

    var name = "_Eval${_unique()}";
    var body = """
      class $name extends _Env {
        _execute(){\n$code\n}
      }
      ${name}_execute() => new $name()._execute();
    """;
    declare(body);
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
    for (var v in _variables._getNewKeys()) {
      declare("get $v => VARIABLES['$v']; set $v(v) => VARIABLES['$v'] = v;");
    }
    _declare(_library, "console_declaration_${_unique()}", code);
  }

  static var _uniqueSeed = 1;
  static _unique() => _uniqueSeed++;
}

_createLibrary(url, source) native "NewLibrary";
_declare(library, id, code) native "Declare";
_import(library, importName, importClosure) native "Import";
_invoke(library, className) native "Invoke";
_initEnvMap(library, map) native "InitEnvMap";
