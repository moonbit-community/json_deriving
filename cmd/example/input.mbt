///|
#json.derive
pub struct Params {
  /// The kind of search to perform. 
  /// 'regex' performs traditional regex-based file content search. 
  /// 'moonbit_definition' performs fuzzy symbolic search to find MoonBit symbol definitions 
  /// - note that when using 'moonbit_definition', 
  /// the regex parameter can be imprecise as the system will perform fuzzy search 
  /// to find the most relevant symbols. 'moonbit_references' finds all references 
  /// to a MoonBit symbol using the moon IDE tool.",
  #json.enumerate(string("regex", "moonbit_definition", "moonbit_references"))
  kind : String
  /// The path of the directory or file to search in, relative to the current working directory.
  path : String
  /// Glob pattern to filter files (e.g., '*.ts', '*.js', '*.py', etc.). Defaults to '*' to search all files.
  #json.default(string("*"))
  file_pattern : String?
  /// Number of context lines to show before and after each match. Defaults to 2.
  #json.default(integer("2"))
  context_lines : Int32?
  /// The search pattern. 
  /// For 'regex' kind: regular expression pattern with full regex syntax. 
  /// For 'moonbit_definition' kind: symbol name or partial name (can be imprecise) for fuzzy symbolic search.
  regex : String
} derive(Show)

///|
#json.derive
struct Table {
  head : Params
  tail : Array[Int32]
  tail2 : Array[Double?]
} derive(Show)

///|
test {
  let table = {
    head: {
      kind: "123",
      path: "abc",
      file_pattern: Some("cde"),
      context_lines: None,
      regex: "regex1",
    },
    tail: [1, 2, 3, 4, 5],
    tail2: [Some(1.2), None],
  }
  @json.inspect(table.encode(), content={
    "head": {
      "kind": "123",
      "path": "abc",
      "file_pattern": "cde",
      "regex": "regex1",
    },
    "tail": [1, 2, 3, 4, 5],
    "tail2": [1.2, null],
  })
  inspect(
    (@json_deriving.decode(table.encode()) : Table),
    content=(
      #|{head: {kind: "123", path: "abc", file_pattern: Some("cde"), context_lines: Some(2), regex: "regex1"}, tail: [1, 2, 3, 4, 5], tail2: [Some(1.2), None]}
    ),
  )
}
