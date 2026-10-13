name = "moonbitlang/json_deriving_wasm"

version = "0.0.1"

import {
  "moonbitlang/formatter@0.1.1",
  "moonbitlang/parser@0.1.11",
  "peter-jerry-ye/wasi@0.22.4",
  "moonbitlang/json_deriving_codegen@0.0.2",
  "moonbitlang/json_deriving@0.0.2",
}

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = [ "json", "derive", "serialization", "deserialization" ]

description = "deriving JSON serialization and deserialization automatically"

preferred_target = "wasm"
