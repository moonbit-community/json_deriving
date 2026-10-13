///|
pub(all) enum Path {
  Root
  Key(Path, String)
  Index(Path, Int32)
} derive(Eq)

///|
pub suberror DecodeError {
  DecodeError((Path, Json))
}

///|
pub impl Show for Path with fn output(self, buf) {
  match self {
    Root => buf.write_string("$root")
    Key(path, key) => {
      path.output(buf)
      buf..write_string(".").write_string(key)
    }
    Index(path, idx) => {
      path.output(buf)
      buf..write_string(".").write_string(idx.to_string())
    }
  }
}

///|
pub impl Show for DecodeError with fn output(self, buf) {
  let DecodeError((path, json)) = self
  buf
  ..write_string("Failed to decode json at ")
  ..write_string(path.to_string())
  ..write_string(":\n")
  .write_string(json.stringify(indent=2))
}

///|
/// convert value to json
pub(open) trait Encode {
  #as_free_fn
  fn encode(Self) -> Json
}

///|
/// convert json to value
pub(open) trait Decode {
  fn decode(Json, Path) -> Self raise DecodeError
}

///|
pub fn[T : Decode] decode(json : Json, path? : Path) -> T raise DecodeError {
  Decode::decode(json, path.unwrap_or(Root))
}

///|
pub fn[T] fail(path : Path, json : Json) -> T raise DecodeError {
  raise DecodeError((path, json))
}
