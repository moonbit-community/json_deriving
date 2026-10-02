///|
test {
  let source =
    #|///|
    #|/// doc for pos
    #|#json.private_derive
    #|struct Pos {
    #|  #json.enumerate(string("a", "b", "c"))
    #|  v : String
    #|  w : Array[Int]
    #|  /// doc for x
    #|  /// doc2
    #|  #json.default(string("*"))
    #|  x : String?
    #|  /// doc for y
    #|  #json.default(boolean(false))
    #|  y : Bool?
    #|  /// doc for z
    #|  z : Int?
    #|}
    #|
    #|/// doc for location
    #|#json.derive
    #|struct Location {
    #|  /// start pos
    #|  start : Pos?
    #|  /// end pos
    #|  end : Pos
    #|  points : Array[Pos]
    #|}
  let (ast, _) = @parser.parse_string(source)
  let ast = derive_json(ast)
  let result = @formatter.impls_to_string(ast)
  inspect(
    result,
    content=(
      #|///|
      #|#json.generated
      #|fn Pos::get_schema() -> Json {
      #|  {
      #|    "type": "object",
      #|    "required": ["v", "w"],
      #|    "properties": {
      #|      "v": { "type": "string", "enum": ["a", "b", "c"] },
      #|      "w": { "type": "array", "items": { "type": "integer" } },
      #|      "x": {
      #|        "type": "string",
      #|        "default": "*",
      #|        "description": "doc for x\ndoc2",
      #|      },
      #|      "y": { "type": "boolean", "default": false, "description": "doc for y" },
      #|      "z": { "type": "integer", "description": "doc for z" },
      #|    },
      #|    "description": "\ndoc for pos",
      #|  }
      #|}
      #|
      #|///|
      #|#json.generated
      #|priv impl @moonbitlang/json_deriving.Decode for Pos with decode(self, path) {
      #|  match self {
      #|    { "v": v, "w": w, "x"?: x, "y"?: y, "z": z } => {
      #|      v: @moonbitlang/json_deriving.decode(v, Key(path, "v")),
      #|      w: @moonbitlang/json_deriving.decode(w, Key(path, "w")),
      #|      x: match x {
      #|        Some(value) => 
      #|          Some(@moonbitlang/json_deriving.decode(value, Key(path, "x")))
      #|        None => Some("*")
      #|      },
      #|      y: match y {
      #|        Some(value) => 
      #|          Some(@moonbitlang/json_deriving.decode(value, Key(path, "y")))
      #|        None => Some(false)
      #|      },
      #|      z: @moonbitlang/json_deriving.decode(z, Key(path, "z")),
      #|    }
      #|    _ => @moonbitlang/json_deriving.fail(self, path)
      #|  }
      #|}
      #|
      #|///|
      #|#json.generated
      #|priv impl @moonbitlang/json_deriving.Encode for Pos with encode(self) {
      #|  let result = {  }
      #|  result["v"] =  encode(self.v)
      #|  result["w"] =  encode(self.w)
      #|  if self.x is Some(value) {
      #|    result["x"] =  encode(value)
      #|  }
      #|  if self.y is Some(value) {
      #|    result["y"] =  encode(value)
      #|  }
      #|  result["z"] =  encode(self.z)
      #|  result
      #|}
      #|
      #|///|
      #|#json.generated
      #|pub fn Location::get_schema() -> Json {
      #|  {
      #|    "type": "object",
      #|    "required": ["end", "points"],
      #|    "properties": {
      #|      "start": { "$ref": "#/definitions/Pos", "description": "start pos" },
      #|      "end": { "$ref": "#/definitions/Pos", "description": "end pos" },
      #|      "points": { "type": "array", "items": { "$ref": "#/definitions/Pos" } },
      #|    },
      #|    "description": "doc for location",
      #|    "definitions": { "Pos": Pos::get_schema() },
      #|  }
      #|}
      #|
      #|///|
      #|#json.generated
      #|pub impl @moonbitlang/json_deriving.Decode for Location with decode(self, path) {
      #|  match self {
      #|    { "start": start, "end": end, "points": points } => {
      #|      start: @moonbitlang/json_deriving.decode(start, Key(path, "start")),
      #|      end: @moonbitlang/json_deriving.decode(end, Key(path, "end")),
      #|      points: @moonbitlang/json_deriving.decode(points, Key(path, "points")),
      #|    }
      #|    _ => @moonbitlang/json_deriving.fail(self, path)
      #|  }
      #|}
      #|
      #|///|
      #|#json.generated
      #|pub impl @moonbitlang/json_deriving.Encode for Location with encode(self) {
      #|  let result = {  }
      #|  result["start"] =  encode(self.start)
      #|  result["end"] =  encode(self.end)
      #|  result["points"] =  encode(self.points)
      #|  result
      #|}
      #|
      #|
    ),
  )
}

///|
test "panic - invalid T with default" {
  let source =
    #|#json.derive
    #|struct Pos {
    #|  #json.default(integer("10"))
    #|  w : Int
    #|}
  let (ast, _) = @parser.parse_string(source)
  let _ = derive_json(ast)
}

///|
test "panic - invalid nested option" {
  let source =
    #|#json.derive
    #|struct Pos {
    #|  w : Int??
    #|}
  let (ast, _) = @parser.parse_string(source)
  let _ = derive_json(ast)
}

///|
test "array with nullable" {
  let source =
    #|#json.derive
    #|struct Pos {
    #|  w : Array[Int?]
    #|}
  let (ast, _) = @parser.parse_string(source)
  let ast = derive_json(ast)
  let result = @formatter.impls_to_string(ast)
  inspect(
    result,
    content=(
      #|///|
      #|#json.generated
      #|fn Pos::get_schema() -> Json {
      #|  {
      #|    "type": "object",
      #|    "required": ["w"],
      #|    "properties": {
      #|      "w": { "type": "array", "items": { "type": ["integer", "null"] } },
      #|    },
      #|  }
      #|}
      #|
      #|
    ),
  )
}
