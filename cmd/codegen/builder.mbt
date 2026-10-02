///|
fn e_id(name : String, pkg? : String) -> @syntax.Expr {
  let id : @syntax.LongIdent = match pkg {
    None => Ident(name~)
    Some(pkg) => Dot(pkg~, id=name)
  }
  Ident(id={ name: id, loc, }, loc~)
}

///|
fn e_method(ty : String, name : String, pkg? : String) -> @syntax.Expr {
  let id : @syntax.LongIdent = match pkg {
    None => Ident(name=ty)
    Some(pkg) => Dot(pkg~, id=ty)
  }
  Method(
    type_name={ name: id, is_object: false, loc, },
    method_name={ name, loc, },
    loc~,
  )
}

///|
fn p_any() -> @syntax.Pattern {
  Any(loc~)
}

///|
fn p_constr(
  name : String,
  args? : Array[@syntax.Pattern] = [],
  open? : Bool = false,
  pkg? : String,
  ty? : String,
) -> @syntax.Pattern {
  let extra_info : @syntax.ConstructorExtraInfo = match (pkg, ty) {
    (Some(pkg), Some(id)) =>
      TypeName({
        name: @syntax.LongIdent::Dot(pkg~, id~),
        loc,
        is_object: false,
      })
    (Some(pkg), None) => Package(pkg)
    (None, Some(id)) =>
      TypeName({
        name: @syntax.LongIdent::Ident(name=id),
        loc,
        is_object: false,
      })
    (None, None) => NoExtraInfo
  }
  let args = match (args, open) {
    ([], false) => None
    _ =>
      Some(
        List::from_array(
          args.map(pat => @syntax.ConstrPatArg::{ pat, kind: Positional, }),
        ),
      )
  }
  @syntax.Pattern::Constr(
    loc~,
    constr=@syntax.Constructor::{
      extra_info,
      name: @syntax.ConstrName::{ name, loc, },
      loc,
    },
    args~,
    is_open=open,
  )
}

///|
fn p_case(
  pattern : @syntax.Pattern,
  body : @syntax.Expr,
  guard_? : @syntax.Expr,
) -> @syntax.Case {
  @syntax.Case::{ pattern, body, guard_, }
}

///|
fn e_constr(name : String, pkg? : String, ty? : String) -> @syntax.Expr {
  let extra_info : @syntax.ConstructorExtraInfo = match (pkg, ty) {
    (Some(pkg), Some(id)) =>
      TypeName({
        name: @syntax.LongIdent::Dot(pkg~, id~),
        loc,
        is_object: false,
      })
    (Some(pkg), None) => Package(pkg)
    (None, Some(id)) =>
      TypeName({
        name: @syntax.LongIdent::Ident(name=id),
        loc,
        is_object: false,
      })
    (None, None) => NoExtraInfo
  }
  @syntax.Expr::Constr(
    constr={ name: @syntax.ConstrName::{ name, loc, }, extra_info, loc, },
    loc~,
  )
}

///|
fn e_match(expr : @syntax.Expr, cases : Array[@syntax.Case]) -> @syntax.Expr {
  Match(expr~, cases=List::from_array(cases), match_loc=loc, using_=None, loc~)
}

///|
fn e_apply(func : @syntax.Expr, args : Array[@syntax.Expr]) -> @syntax.Expr {
  let args = List::from_array(
    args.map(p => @syntax.Argument::{ value: p, kind: Positional, }),
  )
  Apply(func~, args~, loc~, attr=NoAttr)
}

///|
fn e_field(record : @syntax.Expr, field : String) -> @syntax.Expr {
  Field(record~, accessor=@syntax.Accessor::Label({ name: field, loc, }), loc~)
}

// ///|
// fn e_index(expr : @syntax.Expr, index : Int) -> @syntax.Expr {
//   Field(
//     record=expr,
//     accessor=@syntax.Accessor::Index(tuple_index=index, loc~),
//     loc~,
//   )
// }

///|
fn e_string(s : String) -> @syntax.Expr {
  Constant(c=String(s), loc~)
}

///|
fn c_string(s : String) -> @syntax.Constant {
  String(s)
}

///|
fn e_int(s : String) -> @syntax.Expr {
  Constant(c=Int(s), loc~)
}

///|
fn e_double(s : String) -> @syntax.Expr {
  Constant(c=Double(s), loc~)
}

///|
fn e_bool(b : Bool) -> @syntax.Expr {
  Constant(c=Bool(b), loc~)
}

///|
fn e_array(es : Array[@syntax.Expr]) -> @syntax.Expr {
  Array(exprs=List::from_array(es), loc~)
}

///|
fn p_map(elems : Array[@syntax.MapPatElem]) -> @syntax.Pattern {
  @syntax.Pattern::Map(loc~, is_closed=true, elems=List::from_array(elems))
}

///|
fn p_map_elem(
  key : @syntax.Constant,
  pat : @syntax.Pattern,
  match_absent? : Bool = false,
) -> @syntax.MapPatElem {
  { key, pat, match_absent, key_loc: loc, loc, }
}

///|
fn e_record(fields : Array[(String, @syntax.Expr)]) -> @syntax.Expr {
  @syntax.Expr::Record(
    type_name=None,
    fields=List::from_array(
      fields.map(p => @syntax.FieldDef::{
        label: { name: p.0, loc, },
        is_pun: false,
        loc,
        expr: p.1,
      }),
    ),
    trailing=@syntax.TrailingMark::None,
    loc~,
  )
}

///|
fn e_let(
  pattern : @syntax.Pattern,
  expr : @syntax.Expr,
  body : @syntax.Expr,
) -> @syntax.Expr {
  Let(pattern~, expr~, body~, loc~)
}

///|
fn e_seq(seqs : Array[@syntax.Expr], last : @syntax.Expr) -> @syntax.Expr {
  Sequence(exprs=List::from_array(seqs), last_expr=last, loc~)
}

///|
fn e_map(elems : Array[(@syntax.Constant, @syntax.Expr)]) -> @syntax.Expr {
  Map(
    elems=List::from_array(
      elems.map(p => @syntax.MapExprElem::{
        key: p.0,
        expr: p.1,
        key_loc: loc,
        loc,
      }),
    ),
    loc~,
  )
}

///|
fn p_var(name : String) -> @syntax.Pattern {
  @syntax.Pattern::Var({ name, loc, })
}

///|
fn e_array_set(
  array : @syntax.Expr,
  index : @syntax.Expr,
  value : @syntax.Expr,
) -> @syntax.Expr {
  ArraySet(array~, index~, loc~, value~)
}

///|
fn e_is(expr : @syntax.Expr, pat : @syntax.Pattern) -> @syntax.Expr {
  Is(expr~, pat~, loc~)
}

///|
fn e_if(cond : @syntax.Expr, ifso : @syntax.Expr) -> @syntax.Expr {
  If(cond~, ifso~, ifnot=None, loc~)
}

// ///|
// fn mk_if_else(
//   cond : @syntax.Expr,
//   ifso : @syntax.Expr,
//   ifnot : @syntax.Expr,
// ) -> @syntax.Expr {
//   If(cond~, ifso~, ifnot=Some(ifnot), loc~)
// }
