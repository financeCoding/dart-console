// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

library console;
import "readline.dart" as readline;
import "sandbox.dart";
import "fragment_parser.dart";

class Console {
  var stdin;
  var sandbox;
  Console() {
    print("entering Console();");
      stdin = new readline.Input();
      sandbox = new Sandbox();
      print("\nleaving Console();");
  }

  run() {
    //print(sandbox.eval('1+1;'));
    stdin.loop(">> ", (line) {
      try {
        var input = new FragmentParser().append(line);
        while (true) {
          print('${input.state} ${input.toString()}');


          switch (input.state) {
          case FragmentParser.INCOMPLETE:
            var line = stdin.readline("${input.context}> ");
            if (line == null) return true;
            input.append("$line\n");
            break;

          case FragmentParser.DECLARATION:
            print("DECLARATION");
            var d = input.toString();
            return sandbox.declare(d);

          case FragmentParser.EXPRESSION:
            print("EXPRESSION");
            var e = input.toString();
            return print(sandbox.eval(e));

          case FragmentParser.STATEMENT:
            print("STATEMENT");
            return sandbox.execute(input.toString());
          }
        }
      } catch (e) {
        print((e is Exception) ? e : "Exception: $e");
      }
    });
  }
}
