///|
priv struct Env {
  generated : Array[@syntax.Impl]
}

///|
using @list {type List, empty}

///|
fn is_json_derive(
  attrs : List[@attribute.Attribute],
) -> (DeriveFlag, DeriveFlag, DeriveFlag) raise {
  let mut decode = Nothing
  let mut encode = Nothing
  let mut schema = Nothing
  for attr in attrs {
    match attr.parsed {
      Some(Ident({ qual: Some(NAMESPACE), name: DERIVE, })) => {
        decode = Derive(private=false)
        encode = Derive(private=false)
        schema = Derive(private=false)
      }
      Some(Apply({ qual: Some(NAMESPACE), name: DERIVE, }, props)) =>
        for prop in props {
          match prop {
            Expr(Ident({ qual: None, name: DECODE, })) =>
              decode = Derive(private=false)
            Expr(Ident({ qual: None, name: ENCODE, })) =>
              encode = Derive(private=false)
            Expr(Ident({ qual: None, name: SCHEMA, })) =>
              schema = Derive(private=false)
            _ => fail("Unsupported property in #\{NAMESPACE}.\{DERIVE}")
          }
        }
      // TODO: clean up duplicated code
      Some(Ident({ qual: Some(NAMESPACE), name: PRIVATE_DERIVE, })) => {
        decode = Derive(private=true)
        encode = Derive(private=true)
        schema = Derive(private=true)
      }
      Some(Apply({ qual: Some(NAMESPACE), name: PRIVATE_DERIVE, }, props)) =>
        for prop in props {
          match prop {
            Expr(Ident({ qual: None, name: DECODE, })) =>
              decode = Derive(private=true)
            Expr(Ident({ qual: None, name: ENCODE, })) =>
              encode = Derive(private=true)
            Expr(Ident({ qual: None, name: SCHEMA, })) =>
              schema = Derive(private=true)
            _ => fail("Unsupported property in #\{NAMESPACE}.\{DERIVE}")
          }
        }
      _ => ()
    }
  }
  return (decode, encode, schema)
}

// ///|
// fn is_generated(attrs : List[@attribute.Attribute]) -> Bool {
//   for attr in attrs {
//     if attr.parsed is Some(Ident({ qual: Some(NAMESPACE), name: GENERATED })) {
//       return true
//     }
//   }
//   false
// }

///|
let pos : @basic.Position = { cnum: 0, fname: "", lnum: 0, bol: 0, }

///|
let loc : @basic.Location = { start: pos, end: pos, }

///|
fn mk_constr_id(constr : String) -> @syntax.ConstrId {
  { id: Ident(name=constr), loc, }
}

// ///|
// fn mk_binder(binder : String) -> @syntax.Binder {
//   { name: binder, loc }
// }

///|
fn mk_json_object(map : Array[(String, @syntax.Expr)]) -> @syntax.Expr {
  let elems : List[@syntax.MapExprElem] = List::from_iter(
    map
    .iter()
    .map(fn(p) {
      let key : @syntax.Constant = String(p.0)
      { key, expr: p.1, key_loc: loc, loc, }
    }),
  )
  Map(elems~, loc~)
}

///|
priv struct Property {
  name : String
  type_ : Schema
  default : Constant?
  description : String
}

///|
priv enum Schema {
  String(mut enums~ : Array[Constant]?) //(min_len~ : Int?, max_len~ : Int?, format~ : String?, enum_~ : Array[String]?)
  Boolean
  Integer //(min~ : Int?, max~ : Int?, mut enums~ : Array[Constant]?)
  Number
  Object(properties~ : Array[Property], required~ : Array[String])
  Array(item~ : Schema)
  Nullable(Schema)
  Custom(String)
}

///|
priv enum Constant {
  String(String)
  Integer(String)
  Number(String)
  Boolean(Bool)
}

///|
priv enum DeriveFlag {
  Nothing
  Derive(private~ : Bool)
}

///|
fn ty_to_schema(ty : @syntax.Type) -> Schema raise {
  match ty {
    Option(ty=Option(_), loc~, ..) =>
      fail("Json schema error (\{loc}): type `T??` is unsupported.")
    Option(ty~, ..) => Nullable(ty_to_schema(ty))
    Name(constr_id={ id: Ident(name="Array"), .. }, tys=More(ety, ..), ..) =>
      Array(item=ty_to_schema(ety))
    Name(constr_id={ id: Ident(name~), .. }, tys=Empty, ..) =>
      match name {
        "String" => String(enums=None)
        "Int" => Integer
        "Bool" => Boolean
        "Double" => Number
        "Int16"
        | "Int64"
        | "UInt16"
        | "UInt"
        | "UInt64"
        | "Float"
        | "BigInt"
        | "Result"
        | "Option" =>
          fail("Json schema error: type \{name} is not supported yet.")
        custom => Custom(custom)
      }
    Tuple(..) => fail("Json schema error: tuple type is not supported yet.")
    Object(_) => fail("Json schema error: trait object is not supported.")
    Any(_) => fail("Internal error: Any")
    Name(..) => fail("Json schema error: unsupported type")
    Arrow(_) => fail("Json schema error: function type is not supported.")
  }
}

///|
fn field_enumerate(
  attrs : List[@attribute.Attribute],
) -> Array[Constant]? raise {
  fn is_string(x) {
    x is @attribute.Prop::Expr(String(_))
  }

  for attr in attrs {
    if attr.parsed is Some(Apply({ qual: Some(NAMESPACE), name: ENUM }, props)) {
      guard props
        is More(
          Expr(
            Apply(
              { qual: None, name: "string" | "integer" | "number" as name },
              xs
            )
          ),
          tail=Empty
        ) &&
        xs.all(is_string) else {
        fail(
          (
            $| Json schema error: invalid enumerate attribute.
            $| Hint: The syntax is 
            $| #\{NAMESPACE}.\{ENUM}(string(\"s1\", \"s2\"))
            $| #\{NAMESPACE}.\{ENUM}(integer(\"1\", \"2\")) 
            $| #\{NAMESPACE}.\{ENUM}(number(\"1.0\", \"2.0\"))
          ),
        )
      }
      let xs = xs
        .map(x => match x {
          Expr(String(s)) => s
          _ => fail("unreachable")
        })
        .to_array()
      let enums = match name {
        "string" => xs.map(x => Constant::String(x))
        "integer" => xs.map(x => Constant::Integer(x))
        "number" => xs.map(x => Constant::Number(x))
        _ => fail("unreachable")
      }
      break Some(enums)
    }
  } else {
    None
  }
}

///|
fn field_default(attrs : List[@attribute.Attribute]) -> Constant? {
  for attr in attrs {
    if attr.parsed
      is Some(
        Apply(
          { qual: Some(NAMESPACE), name: DEFAULT },
          More(
            Expr(Apply({ qual: None, name }, More(Expr(expr), tail=Empty))),
            tail=Empty
          )
        )
      ) {
      let v = match (name, expr) {
        ("string", String(s)) => Constant::String(s)
        ("integer", String(s)) => Integer(s)
        ("number", String(s)) => Number(s)
        ("boolean", Bool(b)) => Boolean(b)
        _ => continue
      }
      break Some(v)
    }
  } else {
    None
  }
}

///|
fn record_to_schema(fields : @list.List[@syntax.FieldDecl]) -> Schema raise {
  let properties = []
  let required = []
  for field in fields {
    let name = field.name.label
    let description = try! field.doc.content
    .iter()
    .map(line => line.trim_start(char_set="\n\t ").to_string())
    .join("\n")
    .escape()[1:-1].to_string()
    let default = field_default(field.attrs)
    let enums = field_enumerate(field.attrs)
    let (schema, nullable) = match ty_to_schema(field.ty) {
      Nullable(schema) => (schema, true)
      schema => (schema, false)
    }
    match (enums, schema) {
      (Some(_), String(..) as s) => s.enums = enums
      (Some(_), _) =>
        fail(
          "Json schema error (\{field.loc}): currently the enumerate attribute is only allowed on string fields",
        )
      _ => ()
    }
    if !nullable && default is Some(_) {
      fail(
        "Json schema error (\{field.loc}): a field with a default value must be of `T?` type.",
      )
    }
    if !nullable && default is None {
      required.push(name)
    }
    properties.push({ name, type_: schema, default, description, })
  }
  Object(properties~, required~)
}

///|
fn constant_to_ast(c : Constant) -> @syntax.Expr {
  match c {
    Number(s) => e_double(s)
    Integer(s) => e_int(s)
    String(s) => e_string(s)
    Boolean(b) => e_bool(b)
  }
}

///|
type Entries = Array[(String, @syntax.Expr)]

///|
type Definitions = Array[(String, @syntax.Expr)]

///|
fn schema_to_ast(
  schema : Schema,
  nullable? : Bool = false,
  definitions~ : Definitions,
) -> Entries {

  // Handle null, if the developer wishes to pass `null` explicitly.
  // This should be a rare case.
  //
  // Note:
  // `field : T?`:        represent a field can be omited or present with type `T` in record.
  // `field : Array[E?]`: represent a field must be an array of `E | null`. 
  // 
  // In JSON Schema, if a field is not required in an object, the JSON 
  // `{ field: null }` is invalid in this case.
  // 
  fn maybe_nullable(e : @syntax.Expr) -> @syntax.Expr {
    if nullable {
      Array(exprs=List::from_array([e, e_string("null")]), loc~)
    } else {
      e
    }
  }

  match schema {
    String(enums~) => {
      let arr = [("type", maybe_nullable(e_string("string")))]
      if enums is Some(xs) {
        arr.push(("enum", e_array(xs.map(constant_to_ast))))
      }
      arr
    }
    Boolean => [("type", maybe_nullable(e_string("boolean")))]
    Number => [("type", maybe_nullable(e_string("number")))]
    Integer => [("type", maybe_nullable(e_string("integer")))]
    Array(item~) => {
      let item_entries = schema_to_ast(item, definitions~)
      let entries = [
        ("type", maybe_nullable(e_string("array"))),
        ("items", mk_json_object(item_entries)),
      ]
      entries
    }
    Nullable(schema) => schema_to_ast(schema, nullable=true, definitions~)
    Custom(typename) => {
      let type_name : @syntax.TypeName = {
        name: @syntax.LongIdent::Ident(name=typename),
        is_object: false,
        loc,
      }
      let method_name : @syntax.Label = { name: "get_schema", loc, }
      let func = @syntax.Method(type_name~, method_name~, loc~)
      let get_schema_ast = @syntax.Apply(
        func~,
        args=@list.empty(),
        attr=NoAttr,
        loc~,
      )
      definitions.push((typename, get_schema_ast))
      [("$ref", e_string("#/definitions/\{typename}"))]
    }
    Object(properties~, required~) => {
      let entries = [
        ("type", maybe_nullable(e_string("object"))),
        ("required", e_array(required.map(e_string))),
      ]
      let result_props = []
      for p in properties {
        let ty = if p.type_ is Nullable(ty) { ty } else { p.type_ }
        let prop_entries = schema_to_ast(ty, definitions~)
        if p.default is Some(c) {
          prop_entries.push(("default", constant_to_ast(c)))
        }
        if p.description.trim(char_set="\n\t ") != "" {
          prop_entries.push(("description", e_string(p.description)))
        }
        result_props.push((p.name, mk_json_object(prop_entries)))
      }
      entries.push(("properties", mk_json_object(result_props)))
      entries
    }
  }
}

///|
fn derive_schema(
  decl : @syntax.TypeDecl,
  private~ : Bool,
) -> @syntax.Impl raise {
  let expr : @syntax.Expr = match decl.components {
    TupleStruct(_) => fail("Internal error: tuple struct is not supported yet.")
    Alias(_) => fail("Internal error: typealias is not supported yet.")
    Error(_) => fail("Internal error: error type is not supported yet.")
    Extern => fail("Internal error: extern type is not supported yet.")
    Abstract => fail("Internal error: abstract type is not supported yet.")
    Newtype(_) => fail("Internal error: newtype is not supported yet.")
    Variant(_) => fail("Internal error: enum is not supported yet.")
    Record(fields) => {
      let schema = record_to_schema(fields)
      let definitions = []
      let entries = schema_to_ast(schema, definitions~)
      let description = try! decl.doc.content
      .iter()
      .map(line => line.trim_start(char_set="\n\t ").to_string())
      .join("\n")
      .escape()[1:-1].to_string()
      if description != "" {
        entries.push(("description", e_string(description)))
      }
      if !definitions.is_empty() {
        // dedup
        let definitions = Map::from_array(definitions)
        entries.push(("definitions", mk_json_object(definitions.to_array())))
      }
      mk_json_object(entries)
    }
  }
  let attr_generated : @attribute.Attribute = {
    parsed: Some(Ident({ qual: Some(NAMESPACE), name: GENERATED, })),
    raw: "",
    loc,
  }
  let json_ty : @syntax.Type = Name(
    constr_id=mk_constr_id("Json"),
    tys=@list.empty(),
    loc~,
  )
  let vis : @syntax.Visibility = if private {
    Default
  } else {
    Pub(attr=None, loc~)
  }
  let fun_decl : @syntax.FunDecl = {
    type_name: Some({ name: Ident(name=decl.tycon), is_object: false, loc, }),
    name: { name: "get_schema", loc, },
    has_error: None,
    is_async: false,
    decl_params: Some(@list.empty()),
    params_loc: loc,
    quantifiers: @list.empty(),
    return_type: Some(json_ty),
    error_type: NoErrorType,
    vis,
    attrs: @list.from_array([attr_generated]),
    doc: @syntax.DocString::empty(),
  }
  let decl_body : @syntax.DeclBody = DeclBody(local_types=empty(), expr~)
  TopFuncDef(fun_decl~, decl_body~, loc~)
}

///|
fn derive_decode(
  decl : @syntax.TypeDecl,
  private~ : Bool,
) -> @syntax.Impl raise {
  let expr : @syntax.Expr = match decl.components {
    TupleStruct(_) => fail("Internal error: tuple struct is not supported yet.")
    Alias(_) => fail("Internal error: typealias is not supported yet.")
    Error(_) => fail("Internal error: error type is not supported yet.")
    Extern => fail("Internal error: extern type is not supported yet.")
    Abstract => fail("Internal error: abstract type is not supported yet.")
    Newtype(_) => fail("Internal error: newtype is not supported yet.")
    Variant(_) => fail("Internal error: enum is not supported yet.")
    Record(fields) => {
      let schema = record_to_schema(fields)
      let mut name_stamp = -1
      fn fresh_name() -> String {
        name_stamp += 1
        "x\{name_stamp}"
      }

      guard schema is Object(properties~, required=_) else {
        fail("unreachable")
      }
      let self_expr = e_id("self")
      let path_expr = e_id("path")
      let succeed_case = {
        let map_pat_elems = []
        let field_def_elems = []
        for property in properties {
          let name = fresh_name()
          let match_absent = property.default is Some(_)
          let map_pat = p_map_elem(
            c_string(property.name),
            p_var(name),
            match_absent~,
          )
          let field_value = if property.default is Some(c) {
            e_match(e_id(name), [
              p_case(
                p_constr("Some", args=[p_var("value")]),
                e_apply(e_constr("Some"), [
                  e_apply(e_method(pkg~, "Decode", "decode"), [
                    e_id("value"),
                    e_apply(e_constr("Key"), [path_expr, e_string(name)]),
                  ]),
                ]),
              ),
              p_case(
                p_constr("None"),
                e_apply(e_id("Some"), [
                  match c {
                    Number(s) => e_double(s)
                    Integer(s) => e_int(s)
                    Boolean(b) => e_bool(b)
                    String(s) => e_string(s)
                  },
                ]),
              ),
            ])
          } else {
            e_apply(e_method(pkg~, "Decode", "decode"), [
              e_id(name),
              e_apply(e_constr("Key"), [path_expr, e_string(name)]),
            ])
          }
          map_pat_elems.push(map_pat)
          field_def_elems.push((property.name, field_value))
        }
        let pattern = p_map(map_pat_elems)
        let body = e_record(field_def_elems)
        p_case(pattern, body)
      }
      let failed_case = p_case(
        p_any(),
        e_apply(e_id("fail", pkg~), [path_expr, self_expr]),
      )
      e_match(self_expr, [succeed_case, failed_case])
    }
  }
  let attr_generated : @attribute.Attribute = {
    parsed: Some(Ident({ qual: Some(NAMESPACE), name: GENERATED, })),
    raw: "",
    loc,
  }
  let vis : @syntax.Visibility = if private {
    Priv(loc~)
  } else {
    Pub(attr=None, loc~)
  }
  let self_ty : @syntax.Type = Name(
    constr_id={ id: Ident(name=decl.tycon), loc, },
    tys=empty(),
    loc~,
  )
  let decode_trait : @syntax.TypeName = {
    name: @syntax.LongIdent::Dot(pkg~, id="Decode"),
    is_object: false,
    loc,
  }
  let decode_method : @syntax.Binder = { name: "decode", loc, }
  let body : @syntax.DeclBody = DeclBody(local_types=empty(), expr~)
  let params = [
    @syntax.Parameter::Positional(binder={ name: "self", loc, }, ty=None),
    @syntax.Parameter::Positional(binder={ name: "path", loc, }, ty=None),
  ]
  TopImpl(
    trait_=decode_trait,
    self_ty=Some(self_ty),
    method_name=decode_method,
    has_error=None,
    quantifiers=List::empty(),
    params=List::from_array(params),
    ret_ty=None,
    err_ty=NoErrorType,
    body~,
    vis~,
    loc~,
    attrs=List::from_array([attr_generated]),
    doc=@syntax.DocString::empty(),
  )
}

///|
fn derive_encode(
  decl : @syntax.TypeDecl,
  private~ : Bool,
) -> @syntax.Impl raise {
  let expr : @syntax.Expr = match decl.components {
    TupleStruct(_) => fail("Internal error: tuple struct is not supported yet.")
    Alias(_) => fail("Internal error: typealias is not supported yet.")
    Error(_) => fail("Internal error: error type is not supported yet.")
    Extern => fail("Internal error: extern type is not supported yet.")
    Abstract => fail("Internal error: abstract type is not supported yet.")
    Newtype(_) => fail("Internal error: newtype is not supported yet.")
    Variant(_) => fail("Internal error: enum is not supported yet.")
    Record(fields) => {
      let schema = record_to_schema(fields)
      guard schema is Object(properties~, required=_) else {
        fail("unreachable")
      }
      let self_expr = e_id("self")
      let result_expr = e_id("result")
      let fill_value_exprs = []
      fn mk_decode_and_set(key : String, value : @syntax.Expr) -> @syntax.Expr {
        e_array_set(
          result_expr,
          e_string(key),
          e_apply(e_method("Encode", "encode", pkg~), [value]),
        )
      }

      for property in properties {
        let field_expr = e_field(self_expr, property.name)
        let expr = match property.default {
          None => mk_decode_and_set(property.name, field_expr)
          Some(_) => {
            let value_expr = e_id("value")
            let cond = e_is(field_expr, p_constr("Some", args=[p_var("value")]))
            let ifso = mk_decode_and_set(property.name, value_expr)
            e_if(cond, ifso)
          }
        }
        fill_value_exprs.push(expr)
      }
      e_let(
        p_var("result"),
        e_map([]),
        e_seq(
          fill_value_exprs,
          e_apply(e_method("Json", "object"), [result_expr]),
        ),
      )
    }
  }
  let attr_generated : @attribute.Attribute = {
    parsed: Some(Ident({ qual: Some(NAMESPACE), name: GENERATED, })),
    raw: "",
    loc,
  }
  let vis : @syntax.Visibility = if private {
    Priv(loc~)
  } else {
    Pub(attr=None, loc~)
  }
  let self_ty : @syntax.Type = Name(
    constr_id={ id: Ident(name=decl.tycon), loc, },
    tys=empty(),
    loc~,
  )
  let decode_trait : @syntax.TypeName = {
    name: @syntax.LongIdent::Dot(pkg~, id="Encode"),
    is_object: false,
    loc,
  }
  let decode_method : @syntax.Binder = { name: "encode", loc, }
  let body : @syntax.DeclBody = DeclBody(local_types=empty(), expr~)
  let params = [
    @syntax.Parameter::Positional(binder={ name: "self", loc, }, ty=None),
  ]
  TopImpl(
    trait_=decode_trait,
    self_ty=Some(self_ty),
    method_name=decode_method,
    has_error=None,
    quantifiers=List::empty(),
    params=List::from_array(params),
    ret_ty=None,
    err_ty=NoErrorType,
    body~,
    vis~,
    loc~,
    attrs=List::from_array([attr_generated]),
    doc=@syntax.DocString::empty(),
  )
}

///|
fn visit_top_type_def(env : Env, decl : @syntax.TypeDecl) -> Unit raise {
  let (decode, encode, schema) = is_json_derive(decl.attrs)
  if schema is Derive(private~) {
    env.generated.push(derive_schema(decl, private~))
  }
  if decode is Derive(private~) {
    env.generated.push(derive_decode(decl, private~))
  }
  if encode is Derive(private~) {
    env.generated.push(derive_encode(decl, private~))
  }
}

///|
pub fn derive_json(impls : @syntax.Impls) -> @syntax.Impls raise {
  let self : Env = { generated: [], }
  impls.each(impl_ => {
    match impl_ {
      TopTypeDef(decl) => visit_top_type_def(self, decl)
      _ => ()
    }
  })
  List::from_array(self.generated)
}
