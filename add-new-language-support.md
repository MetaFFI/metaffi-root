# Add new language support

## High-level Components

The following does **not** have to be implemented in C/C++, but the interfaces should be exported and accessible as C-compliant entrypoint.

(Future plans: interface will be access via MetaFFI, removing the requirement of C-compliant entrypoint)

[ ] Implement runtime plugin [sdk/runtime/runtime_plugin_interface.h](sdk\runtime\runtime_plugin_interface.h)
[ ] Implement IDL compiler plugin [sdk/idl_compiler/idl_plugin_interface.h](sdk/idl_compiler/idl_plugin_interface.h)
[ ] Implement MetaFFI API that uses MetaFFI from the added PL
[ ] Implement compiler plugins [sdk/compiler/compiler_plugin_interface.h](sdk/compiler/compiler_plugin_interface.h)
    - Compiler guest plugin, mandatory for **some** runtimes
    - Compiler host plugin, optional



## SDK

The SDK contains multiple core implementation that can be reused by plugins.

Some libraries can be shared across PLs (programming languages) that share runtime (e.g. Java, Scala), some libraries can be shared across PLs that shared syntax (e.g. Python3, Jython).

You can use directly core libraries from the SDK, expand the SDK (PR the project) with new runtimes/syntax, or implement everything within your plugin.

## Note about the rest of the document

The document will refer to using or expanding the SDK, but may implement everything within your plugin.

By expanding the SDK, you will help future implementations and can improve future intergrations, therefore, expanding the SDK is **highly recommended**.

Large SDK means the plugins can simply "assemble" different core libraries together to support new PL.

## Important notes

- Plugins should enforce fast-fail policy.
- If implementing into SDK, you must link the libraries/components into the CMake build system.
- Plugins generally suppose to be cross-platform (e.g. Window, Linux, MacOS)

## The Test plugin (xllr.test)

The test plugin contains low-level foreign functions that use directly the underlying CDTS.
It can help you debug your implementation.

xllr.test is implemented in `sdk/test_modules/guest_modules/test`. To use it, just load `test` as target language.

## CMake Scripts

CMake scripts, in `cmake/` are available to use. They are loaded into the CMake context at the MetaFFI root `CMakeLists.txt`.

# Runtime Plugin

## Steps
[ ] Implement or use CDTS serializer/deserializer in `sdk/cdts_serializer/[runtime-name]/`.
    - It is responsible to convert CDTS to runtime-specific entities and vice versa.
    - More information in `sdk/cdts_serializer/serializer_doc.md`
    - Unit-test information in `sdk/cdts_serializer/serializer_tests_doc.md`
    - Will be used by `runtime_manager`, so when picking a programming language, this should be taken into account
    - CDT code, MetaFFI primitives and additional helper functions are available at `sdk/runtime/`.

[ ] Implement or use `runtime_manager` in `sdk/runtime_manager/[runtime-name]/`.
    - Load/unload the target runtime
    - Load/unload target runtime modules
    - Load/unload target runtime entities (e.g. globals, functions, classes)
    - Provides functionality to use the entities (e.g. read a field, call a method)
    - Uses native runtime data types
    - As part of this implementation of loading entities, you need to decide what is the required `entity_path`.
      - `entity_path` is a CSV-based string, where key and value are seperated by '='
      - It may contain any information that is required in runtime, to load an entity
      - add to `sdk/idl_entities/entity_path_specs.json` the new runtime's `entity_path`
    - HIGHLY RECOMMENDED: Load runtime completely dynamically, without any build-time linking. This will provide a single plugin that supports multiple runtime versions.
    - More information in [sdk/runtime_manager/runtime_manager_doc.md](sdk/runtime_manager/runtime_manager_doc.md)
    - Unit-test information in [sdk/runtime_manager/runtime_manager_tests_doc.md](sdk/runtime_manager/runtime_manager_tests_doc.md)

[ ] In the plugin directory/repository, implement [sdk/runtime/runtime_plugin_interface.h](sdk\runtime\runtime_plugin_interface.h) using `runtime_manager` and `cdts_serializer` in `[plugin-directory]/runtime`.

[ ] The dynamic library should be copied to $METAFFI_HOME/[plugin-name]/xllr.[plugin-name].[dynamic-library-extension] including all dependencies.

[ ] Make sure all unit-tests pass successfully. If in SDK, make sure all tests are executed by CMake.

## Important Note
- All heap-managenemt (allocation and free) **must** be done via `xllr` using `xllr_alloc_*` and `xllr_free_*` functions to avoid using non-compitable allocators which leads to undefined behavior.

- **For some runtime**, you won't be able to load entities from the target module without adding *ad-hoc* code to allow the entities to be exported to C (e.g., Go, C, C++, Rust). In this case, **start with `idl_compiler` and `guest compiler` plugin(!)** and then get back to this phase.

# API

## Steps
[ ] Implement or use `api` in `sdk/api/[runtime-name]/`.
    - The loads and uses XLLR and, if required, your new plugin, to load/unload the runtime, load/unload entities and call them.
    - The API loads the dynamic library `xllr` resides in $METAFFI_HOME and uses the XLLR-API (`sdk\runtime\xllr_api.h`) to load the plugin's runtime interface `sdk\runtime\runtime_plugin_interface.h`.
    - More information in [sdk/api/api_doc.md](sdk\api\api_doc.md)
    - Unit-test information in [sdk\api\api_tests_doc.md](sdk\api\api_tests_doc.md)

## Publish

It is recommended to publish the API package to the popular package manager of your runtime/language. It will allow users to easily download and use MetaFFI.


## End-to-end tests as **Host** language via API to test guest (`xllr.test`)

At this point, you implemented enough code to call **from** the supported language to other languages.
You can test your code by calling `xllr.test`.

[ ] Write a unit-test for your `api` module, that loads the target runtime `test`.
[ ] To check which tests you need to perform against `xllr.test`, read [sdk/test_modules/guest_modules/test/test_entities.md](sdk\test_modules\guest_modules\test\test_entities.md).
[ ] Implement tests for all the entities `xllr.test` provides.
[ ] Do not forget to add this as a target to CMake

`xllr.test`, in `sdk/test_modules/guest_modules/test/` contains the C++ code being called. It checks directly the CDTS your API + runtime_manager + cdts serializer is sending it, and returns an expected result back, which your unit-test can verify.

## End-to-end tests as **Guest** language from test host (low-level C/C++)

Use C/C++ code available at `sdk/runtime/` to load `xllr` and use the new plugin to call the entities in `sdk/test_modules/guest_modules/[programming-language]/` (notice, the dir is PL and not runtime name).

### Test Guest

Implement a guest module in your a programming language that uses the target runtime (or implement in more PLs, as long as they all use the same runtime). The compiled/built test module should be placed in `sdk/test_modules/guest_modules/[programming-language]/test_bin/`.

[ ] Implement or use test module for your runtime in `sdk/test_modules/guest_modules/[programming-language]`.
    - More information about guest module in [sdk/test_modules/guest_modules/guest_modules_doc.md](sdk/test_modules/guest_modules/guest_modules_doc.md).
    - Make sure the test module is built to `sdk/test_modules/guest_modules/[programming-language]/test_bin/`
[ ] Do not forget to add this as a target to CMake

### Host C/C++ module test

[ ] Implement or use `sdk/test_modules/host_modules/[programming-language]/` using C++ and available code in `sdk/runtime/` to load the target runtime using the new plugins
[ ] Implement tests for all the entities you exposed in `sdk/test_modules/guest_modules/[programming-language]/`. Preferably, use `doctest`.
[ ] More information about host module in [sdk/test_modules/host_modules/host_modules_doc.md](sdk\test_modules/host_modules/host_modules_doc.md)
[ ] Do not forget to add this as a target to CMake


# Current Status
This concludes the runtime integration between MetaFFI and the new runtime.
The next sections are for:
- IDL Compiler (**mandatory**)
- In cases guest compiler is **Mandatory** (you should start here before )
- *Optional* host compiler

---

# IDL Compiler Plugin

The plugin turns code or executable code into MetaFFI IDL

## Steps
[ ] Implement or use IDL Entities in `sdk/idl_entities/[runtime-name]`.
    - IDL entities are objects that are created and filled parsing given MetaFFI IDL.
    - MetaFFI IDL is JSON-based, and its schema is defined at `sdk/idl_entities/idl.schema.json`.
    - The expected keys in `entity_path` are detailed in `sdk/idl_entities/entity_path_specs.json`.

[ ] Implement or use IDL compiler in `sdk/idl_compiler/[runtime-name or programming-language]/`
    - It is an object that **can** receives as input:
      - target source code (e.g., .java, .py, .cpp) - PL specific
      - target runtime executable (e.g., .jar, .dll, .so, .class, filesystem-directory, package-name) - Runtime specific (which many include multiple PLs)
      - **At least one is mandatory**, both are optional
    - The output is MetaFFI IDL
    - More information in [sdk\idl_compiler\idl_compiler_doc.md]()
    - Unit-test information in [sdk\idl_compiler\idl_compiler_tests_doc.md]()

[ ] In the plugin directory/repository, implement [sdk/idl_compiler/idl_plugin_interface.h](sdk/idl_compiler/idl_plugin_interface.h) using `idl_entities` and `idl_compiler` in `[plugin-directory]/idl/`.

[ ] The dynamic library should be copied to $METAFFI_HOME/[plugin-name]/metaffi.idl.[plugin-name].[dynamic-library-extension] including all dependencies.


# Compiler plugin

Both host and guest compiler plugin receive as input the MetaFFI IDL and generate code for the target runtime.

## Guest compiler

The runtime plugin (via runtime manager) needs to load the entities from the target runtime executable. In some cases, unless the runtime executable is not explicitly exposes the entities, the runtime manager cannot load the entities.
In this case, the guest compiler, needs to generate code for the target runtime or language to expose the entities to MetaFFI (i.e. C entrypoints).

The goal of the guest compiler is to use the MetaFFI IDL and generate generate entrypoint to required entities. There can be two cases:
1. In cases the runtime executable does not contain any entrypoints (i.e. non-MetaFFI compliant entrypoint), the compiler plugin would need to generate code that uses the **entities source code** in order to build new runtime executable with MetaFFI compliant entrypoints.
2. In case the runtime executable does contain entrypoints (i.e. even if non-MetaFFI compilant), the compiler plugin can generate code that wraps the existing non-MetaFFI compliant entrypoint, meaning, the source code is not required.

### Steps
[ ] Implement or use guest compiler **library** in `sdk/compiler/[runtime-name]/guest/` to generate MetaFFI IDL. Use the IDL Entities in `sdk/idl_entities/[runtime-name]/` to construct the IDL.
[ ] More information in [sdk/compiler/compiler_doc.md](sdk/compiler/compiler_doc.md)
[ ] Unit-test information in [sdk/compiler/compiler_tests_doc.md](sdk/compiler/compiler_tests_doc.md)

[ ] In the plugin directory/repository, implement [sdk/compiler/compiler_plugin_interface.h](sdk/compiler/compiler_plugin_interface.h) using `idl_entities` and `compiler` in `[plugin-directory]/compiler/`.
    - If you don't need host compiler, implement the host compiler by returning `Not Implemented` error.

[ ] The dynamic library should be copied to $METAFFI_HOME/[plugin-name]/metaffi.compiler.[plugin-name].[dynamic-library-extension] including all dependencies.

## Host compiler (optional)

To load entities in other languages, the user can use the MetaFFI API for its language/runtime. But in cases of large libraries, this would be a daugnting task. Therefore, the host compiler receives a MetaFFI IDL and generates the entities in that languages, where the implementations are stubs that use MetaFFI API to make the cross-call.

This keeps the cross-call completely transparent and leaves it "behind the scenes".

### Steps
[ ] Implement or use guest compiler **library** in `sdk/compiler/[runtime-name]/host/` to generate MetaFFI IDL. Use the IDL Entities in `sdk/idl_entities/[runtime-name]/` to construct the IDL.
[ ] More information in [sdk/compiler/compiler_doc.md](sdk/compiler/compiler_doc.md)
[ ] Unit-test information in [sdk/compiler/compiler_tests_doc.md](sdk/compiler/compiler_tests_doc.md)

[ ] In the plugin directory/repository, implement [sdk/compiler/compiler_plugin_interface.h](sdk/compiler/compiler_plugin_interface.h) using `idl_entities` and `compiler` in `[plugin-directory]/compiler/`.
    - If you don't need guest compiler, implement the guest compiler by returning `Not Implemented` error.

[ ] The dynamic library should be copied to $METAFFI_HOME/[plugin-name]/metaffi.compiler.[plugin-name].[dynamic-library-extension] including all dependencies.

### End-to-end tests via Host compiler

[ ] Write a unit-test for your `host compiler` module, that generates host code to target runtime `test`. `xllr.test` entities are IDL is available at `sdk/test_modules/guest_modules/test/test_entities.idl.json`.
[ ] Implement tests for all the entities `xllr.test` provides by using the generated code from the host IDL.
[ ] Do not forget to add this as a target to CMake

`xllr.test`, in `sdk/test_modules/guest_modules/test/` contains the C++ code being called. It checks directly the CDTS your API + runtime_manager + cdts serializer is sending it, and returns an expected result back, which your unit-test can verify.

# End-to-end tests

In the plugin directory:

[ ] Under `[plugin-directory]/tests/host/` implement a unit-test to call all other guest modules available at `sdk/test_modules/guest_modules/` using their corresponding plugins.
    - If you have implemented host compiler, use it.
    - Otherwise, use the API.
[ ] Under `[plugin-directory]/tests/guest/` implement unit-tests from all other languages, using their API at `sdk/api/` or host plugin (if available) to call your test module at `sdk/test_modules/guest_modules/[programming-language]`.
