// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#include <string.h>
#include <stdio.h>
#include "dart_util.h"

Dart_NativeFunction ResolveName(Dart_Handle name, int argc);

Dart_Handle get_library(Dart_Handle libraryNumberHandle) {
  int64_t libraryNumber;
  CheckDartError(Dart_IntegerToInt64(libraryNumberHandle, &libraryNumber));
  return (Dart_Handle) libraryNumber;
}

/** Creates a new library from [source], returns an integer handle. */
//DART_FUNCTION(NewLibrary) {
void NewLibrary(Dart_NativeArguments arguments) { 
  printf("NewLibrary\n"); 
  DART_ARGS_2(url, source);
  Dart_Handle lib = Dart_NewPersistentHandle(CheckDartError(Dart_LoadLibrary(url, source)));
  DART_RETURN(Dart_NewInteger((int64_t) lib));
}

/** Adds declarations from [text] to [library]. */
//DART_FUNCTION(Declare) {
void Declare(Dart_NativeArguments arguments) {
  printf("Declare\n"); 
  DART_ARGS_3(library, url, text);
  Dart_Handle libraryHandle = get_library(library);
  CheckDartError(Dart_LoadSource(libraryHandle, url, text));
  DART_RETURN(Dart_Null());
}

/** Invokes the no-args function [funcName] within the context of [library], returns the result. */
//DART_FUNCTION(Invoke) {
void Invoke(Dart_NativeArguments arguments) {
  printf("Invoke\n");
  DART_ARGS_2(library, funcName);
  Dart_Handle libraryHandle = get_library(library);
  DART_RETURN(CheckDartError(Dart_Invoke(libraryHandle, funcName, 0, NULL)));

}

/** Imports the library named [importName] into [library]. */
//DART_FUNCTION(Import) {
void Import(Dart_NativeArguments arguments) {
  printf("Import\n");
  DART_ARGS_3(library, importName, loadingClosure);
  Dart_Handle libraryHandle = get_library(library);
  Dart_Handle importHandle = Dart_LookupLibrary(importName);
  if (Dart_IsError(importHandle)) {
    Dart_Handle source = CheckDartError(Dart_InvokeClosure(loadingClosure, 0, NULL));
    importHandle = CheckDartError(Dart_LoadLibrary(importName, source));
  }
  CheckDartError(Dart_LibraryImportLibrary(libraryHandle, importHandle, Dart_Null()));
  DART_RETURN(Dart_Null());
}

/** Executes _seedEnv([map], [newVars]) within the context of [library]. */
//DART_FUNCTION(InitEnvMap) {
void InitEnvMap(Dart_NativeArguments arguments) {
  printf("InitEnvMap\n");
  DART_ARGS_2(library, map);
  Dart_Handle libraryHandle = get_library(library);
  CheckDartError(Dart_Invoke(libraryHandle, NewString("_seedEnv"), 1, &map));
  DART_RETURN(Dart_Null());
}

/*
DART_LIBRARY(sandbox)
  EXPORT(Declare, 3);
  EXPORT(NewLibrary, 2);
  EXPORT(Invoke, 2);
  EXPORT(Import, 3);
  EXPORT(InitEnvMap, 2);
DART_LIBRARY_END
*/

DART_EXPORT Dart_Handle dart_sandbox_Init(Dart_Handle parent_library) {
  
  printf("dart_sandbox_Init\n");

  if (Dart_IsError(parent_library)) { return parent_library; }

  Dart_Handle result_code = Dart_SetNativeResolver(parent_library, ResolveName);
  
  printf("result_code = ");
  printf("%d", result_code);
  printf("\n");

  if (Dart_IsError(result_code)) {
    return result_code;
  } 

  _library = Dart_NewPersistentHandle(parent_library); 
  return parent_library; 
}

Dart_Handle HandleError(Dart_Handle handle) {
  if (Dart_IsError(handle)) Dart_PropagateError(handle);
  return handle;
}

struct FunctionLookup {
  const char* name;
  Dart_NativeFunction function;
};

FunctionLookup function_list[] = {
    {"NewLibrary", NewLibrary},  
    {"Declare", Declare},  
    {"Invoke", Invoke},  
    {"Import", Import},  
    {"InitEnvMap", InitEnvMap},      
    {NULL, NULL}
  };

Dart_NativeFunction ResolveName(Dart_Handle name, int argc) {
  printf("ResolveName\n");
  if (!Dart_IsString(name)) return NULL;
  Dart_NativeFunction result = NULL;
  Dart_EnterScope();
  const char* cname;
  HandleError(Dart_StringToCString(name, &cname));

  for (int i=0; function_list[i].name != NULL; ++i) {
    printf(function_list[i].name);
    printf(" = ");
    printf("%d", strcmp(function_list[i].name, cname));
    printf("\n");
    if (strcmp(function_list[i].name, cname) == 0) {
      result = function_list[i].function;
      break;
    }
  }
  Dart_ExitScope();
  return result;
}

