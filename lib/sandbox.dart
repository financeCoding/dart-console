// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#library("sandbox");
#import("dart-ext:dart_sandbox");
#import("dart:coreimpl");

class _TrackingMap extends HashMapImplementation {
  var _newKeys;
  _TrackingMap() : _newKeys = new Set<String>();
  operator []= (key, value) {
    if (!this.containsKey(key)) _newKeys.add(key);
    return super[key] = value;
  }
  _getNewKeys() {
    try {
      return _newKeys;
    } finally {
      _newKeys = new Set<String>();
    }
  }
}

class Sandbox {
  final _BASE = @"""
  #import('dart:io', prefix: 'io');
  get VARIABLES() => _Env._map;
  _seedEnv(map) => _Env._map = map;
  class _Env {
    static var _map;
    noSuchMethod(name, args) {
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

  Map<String, Object> get variables() => _variables;
  
  Sandbox() : _variables = new _TrackingMap() {
    var uniquer = _unique();
    _library = _createLibrary("console:$uniquer", "#library('console_$uniquer');\n$_BASE");
    _initEnvMap(_library, _variables);
  }

  eval(expression) {
    return execute("return (\n$expression\n);");
  }

  execute(code) {
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

  void declare(code) {
    // Create getters for any new variables set so they are accessible from declarations.
    for (var v in _variables._getNewKeys()) {
      declare("get $v() => VARIABLES['$v']; set $v(v) => VARIABLES['$v'] = v;");
    }
    _declare(_library, "console_declaration_${_unique()}", code);
  }

  static var _uniqueSeed = 1;
  static _unique() => _uniqueSeed++;
}

_newException(x) => new Exception(x); // For use from extension

_createLibrary(url, source) native "NewLibrary";
_declare(library, id, code) native "Declare";
_invoke(library, className) native "Invoke";
_initEnvMap(library, map) native "InitEnvMap";