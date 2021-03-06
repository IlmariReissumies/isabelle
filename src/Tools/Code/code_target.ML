(*  Title:      Tools/Code/code_target.ML
    Author:     Florian Haftmann, TU Muenchen

Generic infrastructure for target language data.
*)

signature CODE_TARGET =
sig
  val cert_tyco: Proof.context -> string -> string
  val read_tyco: Proof.context -> string -> string

  val export_code_for: Proof.context -> Path.T option -> string -> int option -> string -> Token.T list
    -> Code_Thingol.program -> bool -> Code_Symbol.T list -> unit
  val produce_code_for: Proof.context -> string -> int option -> string -> Token.T list
    -> Code_Thingol.program -> bool -> Code_Symbol.T list -> (string * string) list * string option list
  val present_code_for: Proof.context -> string -> int option -> string -> Token.T list
    -> Code_Thingol.program -> Code_Symbol.T list * Code_Symbol.T list -> string
  val check_code_for: Proof.context -> string -> bool -> Token.T list
    -> Code_Thingol.program -> bool -> Code_Symbol.T list -> unit

  val export_code: Proof.context -> bool -> string list
    -> (((string * string) * Path.T option) * Token.T list) list -> unit
  val produce_code: Proof.context -> bool -> string list
    -> string -> int option -> string -> Token.T list -> (string * string) list * string option list
  val present_code: Proof.context -> string list -> Code_Symbol.T list
    -> string -> int option -> string -> Token.T list -> string
  val check_code: Proof.context -> bool -> string list
    -> ((string * bool) * Token.T list) list -> unit

  val generatedN: string
  val compilation_text: Proof.context -> string -> Code_Thingol.program
    -> Code_Symbol.T list -> bool -> ((string * class list) list * Code_Thingol.itype) * Code_Thingol.iterm
    -> (string * string) list * string
  val compilation_text': Proof.context -> string -> string option -> Code_Thingol.program
    -> Code_Symbol.T list -> bool -> ((string * class list) list * Code_Thingol.itype) * Code_Thingol.iterm
    -> ((string * string) list * string) * (Code_Symbol.T -> string option)

  type serializer
  type literals = Code_Printer.literals
  type language
  type ancestry
  val assert_target: theory -> string -> string
  val add_language: string * language -> theory -> theory
  val add_derived_target: string * ancestry -> theory -> theory
  val the_literals: Proof.context -> string -> literals
  type serialization
  val parse_args: 'a parser -> Token.T list -> 'a
  val serialization: (int -> Path.T option -> 'a -> unit)
    -> (Code_Symbol.T list -> int -> 'a -> (string * string) list * (Code_Symbol.T -> string option))
    -> 'a -> serialization
  val default_code_width: int Config.T

  type ('a, 'b, 'c, 'd, 'e, 'f) symbol_attr_decl
  val set_identifiers: (string, string, string, string, string, string) symbol_attr_decl
    -> theory -> theory
  val set_printings: (Code_Printer.raw_const_syntax, Code_Printer.tyco_syntax, string, unit, unit, (string * string list)) symbol_attr_decl
    -> theory -> theory
  val add_reserved: string -> string -> theory -> theory
end;

structure Code_Target : CODE_TARGET =
struct

open Basic_Code_Symbol;
open Basic_Code_Thingol;

type literals = Code_Printer.literals;
type ('a, 'b, 'c, 'd, 'e, 'f) symbol_attr_decl =
  (string * (string * 'a option) list, string * (string * 'b option) list,
    class * (string * 'c option) list, (class * class) * (string * 'd option) list,
    (class * string) * (string * 'e option) list,
    string * (string * 'f option) list) Code_Symbol.attr;

type tyco_syntax = Code_Printer.tyco_syntax;
type raw_const_syntax = Code_Printer.raw_const_syntax;


(** checking and parsing of symbols **)

fun cert_const ctxt const =
  let
    val _ = if Sign.declared_const (Proof_Context.theory_of ctxt) const then ()
      else error ("No such constant: " ^ quote const);
  in const end;

fun read_const ctxt = Code.read_const (Proof_Context.theory_of ctxt);

fun cert_tyco ctxt tyco =
  let
    val _ = if Sign.declared_tyname (Proof_Context.theory_of ctxt) tyco then ()
      else error ("No such type constructor: " ^ quote tyco);
  in tyco end;

fun read_tyco ctxt =
  #1 o dest_Type o Proof_Context.read_type_name {proper = true, strict = true} ctxt;

fun cert_class ctxt class =
  let
    val _ = Axclass.get_info (Proof_Context.theory_of ctxt) class;
  in class end;

val parse_classrel_ident = Parse.class --| @{keyword "<"} -- Parse.class;

fun cert_inst ctxt (class, tyco) =
  (cert_class ctxt class, cert_tyco ctxt tyco);

fun read_inst ctxt (raw_tyco, raw_class) =
  (read_tyco ctxt raw_tyco, Proof_Context.read_class ctxt raw_class);

val parse_inst_ident = Parse.name --| @{keyword "::"} -- Parse.class;

fun cert_syms ctxt =
  Code_Symbol.map_attr (apfst (cert_const ctxt)) (apfst (cert_tyco ctxt))
    (apfst (cert_class ctxt)) ((apfst o apply2) (cert_class ctxt)) (apfst (cert_inst ctxt)) I;

fun read_syms ctxt =
  Code_Symbol.map_attr (apfst (read_const ctxt)) (apfst (read_tyco ctxt))
    (apfst (Proof_Context.read_class ctxt)) ((apfst o apply2) (Proof_Context.read_class ctxt)) (apfst (read_inst ctxt)) I;

fun check_name is_module s =
  let
    val _ = if s = "" then error "Bad empty code name" else ();
    val xs = Long_Name.explode s;
    val xs' = if is_module
        then map (Name.desymbolize NONE) xs
      else if length xs < 2
        then error ("Bad code name without module component: " ^ quote s)
      else
        let
          val (ys, y) = split_last xs;
          val ys' = map (Name.desymbolize NONE) ys;
          val y' = Name.desymbolize NONE y;
        in ys' @ [y'] end;
  in if xs' = xs
    then if is_module then (xs, "") else split_last xs
    else error ("Invalid code name: " ^ quote s ^ "\n"
      ^ "better try " ^ quote (Long_Name.implode xs'))
  end;


(** serializations and serializer **)

(* serialization: abstract nonsense to cover different destinies for generated code *)

datatype destination = Export of Path.T option | Produce | Present of Code_Symbol.T list;
type serialization = int -> destination -> ((string * string) list * (Code_Symbol.T -> string option)) option;

fun serialization output _ content width (Export some_path) =
      (output width some_path content; NONE)
  | serialization _ string content width Produce =
      string [] width content |> SOME
  | serialization _ string content width (Present syms) =
     string syms width content
     |> (apfst o map o apsnd) Output.output
     |> SOME;

fun export some_path f = (f (Export some_path); ());
fun produce f = the (f Produce);
fun present syms f = space_implode "\n\n" (map snd (fst (the (f (Present syms)))));


(* serializers: functions producing serializations *)

type serializer = Token.T list
  -> Proof.context
  -> {
    module_name: string,
    reserved_syms: string list,
    identifiers: Code_Printer.identifiers,
    includes: (string * Pretty.T) list,
    class_syntax: string -> string option,
    tyco_syntax: string -> Code_Printer.tyco_syntax option,
    const_syntax: string -> Code_Printer.const_syntax option }
  -> Code_Symbol.T list
  -> Code_Thingol.program
  -> serialization;

  
(** theory data **)

type language = {serializer: serializer, literals: literals,
  check: {env_var: string, make_destination: Path.T -> Path.T, make_command: string -> string},
  evaluation_args: Token.T list}; 

type ancestry = (string * (Code_Thingol.program -> Code_Thingol.program)) list;

val merge_ancestry : ancestry * ancestry -> ancestry = AList.join (op =) (K snd);

type target = {serial: serial, language: language, ancestry: ancestry};

structure Targets = Theory_Data
(
  type T = (target * Code_Printer.data) Symtab.table;
  val empty = Symtab.empty;
  val extend = I;
  fun merge (targets1, targets2) : T =
    Symtab.join (fn target_name => fn ((target1, data1), (target2, data2)) =>
      if #serial target1 = #serial target2 then
      ({serial = #serial target1, language = #language target1,
        ancestry = merge_ancestry (#ancestry target1, #ancestry target2)},
        Code_Printer.merge_data (data1, data2))
      else error ("Incompatible targets: " ^ quote target_name) 
    ) (targets1, targets2)
);

fun exists_target thy = Symtab.defined (Targets.get thy);
fun lookup_target_data thy = Symtab.lookup (Targets.get thy);
fun assert_target thy target_name =
  if exists_target thy target_name
  then target_name
  else error ("Unknown code target language: " ^ quote target_name);

fun fold1 f xs = fold f (tl xs) (hd xs);

fun join_ancestry thy target_name =
  let
    val _ = assert_target thy target_name; 
    val the_target_data = the o lookup_target_data thy;
    val (target, this_data) = the_target_data target_name;
    val ancestry = #ancestry target;
    val modifies = rev (map snd ancestry);
    val modify = fold (curry (op o)) modifies I;
    val datas = rev (map (snd o the_target_data o fst) ancestry) @ [this_data];
    val data = fold1 (fn data' => fn data => Code_Printer.merge_data (data, data')) datas;
  in (modify, (target, data)) end;

  fun allocate_target target_name target thy =
  let
    val _ = if exists_target thy target_name
      then error ("Attempt to overwrite existing target " ^ quote target_name)
      else ();
  in
    thy
    |> (Targets.map o Symtab.update) (target_name, (target, Code_Printer.empty_data))  
  end;

fun add_language (target_name, language) =
  allocate_target target_name {serial = serial (), language = language,
    ancestry = []};

fun add_derived_target (target_name, initial_ancestry) thy =
  let
    val _ = if null initial_ancestry
      then error "Must derive from existing target(s)" else ();
    fun the_target_data target_name' = case lookup_target_data thy target_name' of
      NONE => error ("Unknown code target language: " ^ quote target_name')
    | SOME target_data' => target_data';
    val targets = rev (map (fst o the_target_data o fst) initial_ancestry);
    val supremum = fold1 (fn target' => fn target =>
      if #serial target = #serial target'
      then target else error "Incompatible targets") targets;
    val ancestries = map #ancestry targets @ [initial_ancestry];
    val ancestry = fold1 (fn ancestry' => fn ancestry =>
      merge_ancestry (ancestry, ancestry')) ancestries;
  in
    allocate_target target_name {serial = #serial supremum, language = #language supremum,
      ancestry = ancestry} thy 
  end;
  
fun map_data target_name f thy =
  let
    val _ = assert_target thy target_name;
  in
    thy
    |> (Targets.map o Symtab.map_entry target_name o apsnd o Code_Printer.map_data) f
  end;

fun map_reserved target_name =
  map_data target_name o @{apply 3 (1)};
fun map_identifiers target_name =
  map_data target_name o @{apply 3 (2)};
fun map_printings target_name =
  map_data target_name o @{apply 3 (3)};


(** serializer usage **)

(* technical aside: pretty printing width *)

val default_code_width = Attrib.setup_config_int @{binding "default_code_width"} (K 80);


(* montage *)

fun the_language ctxt =
  #language o fst o the o lookup_target_data (Proof_Context.theory_of ctxt);

fun the_literals ctxt = #literals o the_language ctxt;

fun the_evaluation_args ctxt = #evaluation_args o the_language ctxt;

local

fun activate_target ctxt target_name =
  let
    val thy = Proof_Context.theory_of ctxt;
    val (modify, target_data) = join_ancestry thy target_name;
  in (target_data, modify) end;

fun project_program ctxt syms_hidden syms1 program2 =
  let
    val syms2 = subtract (op =) syms_hidden syms1;
    val program3 = Code_Symbol.Graph.restrict (not o member (op =) syms_hidden) program2;
    val syms4 = Code_Symbol.Graph.all_succs program3 syms2;
    val unimplemented = Code_Thingol.unimplemented program3;
    val _ =
      if null unimplemented then ()
      else error ("No code equations for " ^
        commas (map (Proof_Context.markup_const ctxt) unimplemented));
    val program4 = Code_Symbol.Graph.restrict (member (op =) syms4) program3;
  in (syms4, program4) end;

fun prepare_serializer ctxt (serializer : serializer) reserved identifiers
    printings module_name args proto_program syms =
  let
    val syms_hidden = Code_Symbol.symbols_of printings;
    val (syms_all, program) = project_program ctxt syms_hidden syms proto_program;
    fun select_include (name, (content, cs)) =
      if null cs orelse exists (fn c => member (op =) syms_all (Constant c)) cs
      then SOME (name, content) else NONE;
    val includes = map_filter select_include (Code_Symbol.dest_module_data printings);
  in
    (serializer args ctxt {
      module_name = module_name,
      reserved_syms = reserved,
      identifiers = identifiers,
      includes = includes,
      const_syntax = Code_Symbol.lookup_constant_data printings,
      tyco_syntax = Code_Symbol.lookup_type_constructor_data printings,
      class_syntax = Code_Symbol.lookup_type_class_data printings },
      (subtract (op =) syms_hidden syms, program))
  end;

fun mount_serializer ctxt target_name some_width module_name args program syms =
  let
    val default_width = Config.get ctxt default_code_width;
    val ((target, data), modify) = activate_target ctxt target_name;
    val serializer = (#serializer o #language) target;
    val (prepared_serializer, (prepared_syms, prepared_program)) =
      prepare_serializer ctxt serializer
        (Code_Printer.the_reserved data) (Code_Printer.the_identifiers data)
        (Code_Printer.the_printings data)
        module_name args (modify program) syms
    val width = the_default default_width some_width;
  in (fn program => fn syms => prepared_serializer syms program width, (prepared_syms, prepared_program)) end;

fun invoke_serializer ctxt target_name some_width raw_module_name args program all_public syms =
  let
    val module_name = if raw_module_name = "" then ""
      else (check_name true raw_module_name; raw_module_name)
    val (mounted_serializer, (prepared_syms, prepared_program)) =
      mount_serializer ctxt target_name some_width module_name args program syms;
  in
    Code_Preproc.timed_exec "serializing"
      (fn () => mounted_serializer prepared_program (if all_public then [] else prepared_syms)) ctxt
  end;

fun assert_module_name "" = error "Empty module name not allowed here"
  | assert_module_name module_name = module_name;

val using_master_directory =
  Option.map o File.full_path o Resources.master_directory o Proof_Context.theory_of;

in

val generatedN = "Generated_Code";

fun export_code_for ctxt some_path target_name some_width module_name args =
  export (using_master_directory ctxt some_path)
  ooo invoke_serializer ctxt target_name some_width module_name args;

fun produce_code_for ctxt target_name some_width module_name args =
  let
    val serializer = invoke_serializer ctxt target_name some_width (assert_module_name module_name) args;
  in fn program => fn all_public => fn syms =>
    produce (serializer program all_public syms) |> apsnd (fn deresolve => map deresolve syms)
  end;

fun present_code_for ctxt target_name some_width module_name args =
  let
    val serializer = invoke_serializer ctxt target_name some_width (assert_module_name module_name) args;
  in fn program => fn (syms, selects) =>
    present selects (serializer program false syms)
  end;

fun check_code_for ctxt target_name strict args program all_public syms =
  let
    val { env_var, make_destination, make_command } =
      (#check o the_language ctxt) target_name;
    fun ext_check p =
      let
        val destination = make_destination p;
        val _ = export (SOME destination) (invoke_serializer ctxt target_name (SOME 80)
          generatedN args program all_public syms);
        val cmd = make_command generatedN;
      in
        if Isabelle_System.bash ("cd " ^ File.bash_path p ^ " && " ^ cmd ^ " 2>&1") <> 0
        then error ("Code check failed for " ^ target_name ^ ": " ^ cmd)
        else ()
      end;
  in
    if not (env_var = "") andalso getenv env_var = ""
    then if strict
      then error (env_var ^ " not set; cannot check code for " ^ target_name)
      else warning (env_var ^ " not set; skipped checking code for " ^ target_name)
    else Isabelle_System.with_tmp_dir "Code_Test" ext_check
  end;

fun dynamic_compilation_text mounted_serializer prepared_program syms all_public ((vs, ty), t) =
  let
    val _ = if Code_Thingol.contains_dict_var t then
      error "Term to be evaluated contains free dictionaries" else ();
    val v' = singleton (Name.variant_list (map fst vs)) "a";
    val vs' = (v', []) :: vs;
    val ty' = ITyVar v' `-> ty;
    val program = prepared_program
      |> Code_Symbol.Graph.new_node (Code_Symbol.value,
          Code_Thingol.Fun (((vs', ty'), [(([IVar (SOME "dummy")], t), (NONE, true))]), NONE))
      |> fold (curry (perhaps o try o
          Code_Symbol.Graph.add_edge) Code_Symbol.value) syms;
    val (program_code, deresolve) =
      produce (mounted_serializer program (if all_public then [] else [Code_Symbol.value]));
    val value_name = the (deresolve Code_Symbol.value);
  in ((program_code, value_name), deresolve) end;

fun compilation_text' ctxt target_name some_module_name program syms =
  let
    val evaluation_args = the_evaluation_args ctxt target_name;
    val (mounted_serializer, (_, prepared_program)) =
      mount_serializer ctxt target_name NONE (the_default generatedN some_module_name) evaluation_args program syms;
  in
    Code_Preproc.timed_exec "serializing"
    (fn () => dynamic_compilation_text mounted_serializer prepared_program syms) ctxt
  end;

fun compilation_text ctxt target_name program syms =
  fst oo compilation_text' ctxt target_name NONE program syms
  
end; (* local *)


(* code generation *)

fun prep_destination (s, pos) =
  if s = "" then NONE
  else
    let
      val _ = Position.report pos Markup.language_path;
      val path = Path.explode s;
      val _ = Position.report pos (Markup.path (Path.smart_implode path));
    in SOME path end;

fun export_code ctxt all_public cs seris =
  let
    val program = Code_Thingol.consts_program ctxt cs;
    val _ = map (fn (((target_name, module_name), some_path), args) =>
      export_code_for ctxt some_path target_name NONE module_name args program all_public (map Constant cs)) seris;
  in () end;

fun export_code_cmd all_public raw_cs seris ctxt =
  export_code ctxt all_public
    (Code_Thingol.read_const_exprs ctxt raw_cs)
    ((map o apfst o apsnd) prep_destination seris);

fun produce_code ctxt all_public cs target_name some_width some_module_name args =
  let
    val program = Code_Thingol.consts_program ctxt cs;
  in produce_code_for ctxt target_name some_width some_module_name args program all_public (map Constant cs) end;

fun present_code ctxt cs syms target_name some_width some_module_name args =
  let
    val program = Code_Thingol.consts_program ctxt cs;
  in present_code_for ctxt target_name some_width some_module_name args program (map Constant cs, syms) end;

fun check_code ctxt all_public cs seris =
  let
    val program = Code_Thingol.consts_program ctxt cs;
    val _ = map (fn ((target_name, strict), args) =>
      check_code_for ctxt target_name strict args program all_public (map Constant cs)) seris;
  in () end;

fun check_code_cmd all_public raw_cs seris ctxt =
  check_code ctxt all_public
    (Code_Thingol.read_const_exprs ctxt raw_cs) seris;

local

val parse_const_terms = Scan.repeat1 Args.term
  >> (fn ts => fn ctxt => map (Code.check_const (Proof_Context.theory_of ctxt)) ts);

fun parse_names category parse internalize mark_symbol =
  Scan.lift (Args.parens (Args.$$$ category)) |-- Scan.repeat1 parse
  >> (fn xs => fn ctxt => map (mark_symbol o internalize ctxt) xs);

val parse_consts = parse_names "consts" Args.term
  (Code.check_const o Proof_Context.theory_of) Constant;

val parse_types = parse_names "types" (Scan.lift Args.name)
  (Sign.intern_type o Proof_Context.theory_of) Type_Constructor;

val parse_classes = parse_names "classes" (Scan.lift Args.name)
  (Sign.intern_class o Proof_Context.theory_of) Type_Class;

val parse_instances = parse_names "instances" (Scan.lift (Args.name --| Args.$$$ "::" -- Args.name))
  (fn ctxt => fn (raw_tyco, raw_class) =>
    let
      val thy = Proof_Context.theory_of ctxt;
    in (Sign.intern_class thy raw_tyco, Sign.intern_type thy raw_class) end) Class_Instance;

in

val _ = Theory.setup
  (Thy_Output.antiquotation_raw @{binding code_stmts}
    (parse_const_terms --
      Scan.repeat (parse_consts || parse_types || parse_classes || parse_instances)
      -- Scan.lift (Args.parens (Args.name -- Scan.option Parse.int)))
    (fn ctxt => fn ((mk_cs, mk_stmtss), (target_name, some_width)) =>
      Latex.string
        (present_code ctxt (mk_cs ctxt)
          (maps (fn f => f ctxt) mk_stmtss)
          target_name some_width "Example" [])));

end;


(** serializer configuration **)

(* reserved symbol names *)

fun add_reserved target_name sym thy =
  let
    val (_, (_, data)) = join_ancestry thy target_name;
    val _ = if member (op =) (Code_Printer.the_reserved data) sym
      then error ("Reserved symbol " ^ quote sym ^ " already declared")
      else ();
  in
    thy
    |> map_reserved target_name (insert (op =) sym)
  end;


(* checking of syntax *)

fun check_const_syntax ctxt target_name c syn =
  if Code_Printer.requires_args syn > Code.args_number (Proof_Context.theory_of ctxt) c
  then error ("Too many arguments in syntax for constant " ^ quote c)
  else Code_Printer.prep_const_syntax (Proof_Context.theory_of ctxt) (the_literals ctxt target_name) c syn;

fun check_tyco_syntax ctxt target_name tyco syn =
  if fst syn <> Sign.arity_number (Proof_Context.theory_of ctxt) tyco
  then error ("Number of arguments mismatch in syntax for type constructor " ^ quote tyco)
  else syn;


(* custom symbol names *)

fun arrange_name_decls x =
  let
    fun arrange is_module (sym, target_names) = map (fn (target, some_name) =>
      (target, (sym, Option.map (check_name is_module) some_name))) target_names;
  in
    Code_Symbol.maps_attr' (arrange false) (arrange false) (arrange false)
      (arrange false) (arrange false) (arrange true) x
  end;

fun cert_name_decls ctxt = cert_syms ctxt #> arrange_name_decls;

fun read_name_decls ctxt = read_syms ctxt #> arrange_name_decls;

fun set_identifier (target_name, sym_name) = map_identifiers target_name (Code_Symbol.set_data sym_name);

fun gen_set_identifiers prep_name_decl raw_name_decls thy =
  fold set_identifier (prep_name_decl (Proof_Context.init_global thy) raw_name_decls) thy;

val set_identifiers = gen_set_identifiers cert_name_decls;
val set_identifiers_cmd = gen_set_identifiers read_name_decls;


(* custom printings *)

fun arrange_printings prep_const ctxt =
  let
    fun arrange check (sym, target_syns) =
      map (fn (target_name, some_syn) =>
        (target_name, (sym, Option.map (check ctxt target_name sym) some_syn))) target_syns;
  in
    Code_Symbol.maps_attr'
      (arrange check_const_syntax) (arrange check_tyco_syntax)
        (arrange ((K o K o K) I)) (arrange ((K o K o K) I)) (arrange ((K o K o K) I))
        (arrange (fn ctxt => fn _ => fn _ => fn (raw_content, raw_cs) =>
          (Pretty.blk (0, Pretty.fbreaks (map Code_Printer.str (split_lines raw_content))),
            map (prep_const ctxt) raw_cs)))
  end;

fun cert_printings ctxt = cert_syms ctxt #> arrange_printings cert_const ctxt;

fun read_printings ctxt = read_syms ctxt #> arrange_printings read_const ctxt;

fun set_printing (target_name, sym_syn) = map_printings target_name (Code_Symbol.set_data sym_syn);

fun gen_set_printings prep_print_decl raw_print_decls thy =
  fold set_printing (prep_print_decl (Proof_Context.init_global thy) raw_print_decls) thy;

val set_printings = gen_set_printings cert_printings;
val set_printings_cmd = gen_set_printings read_printings;


(* concrete syntax *)

fun parse_args f args =
  case Scan.read Token.stopper f args
   of SOME x => x
    | NONE => error "Bad serializer arguments";


(** Isar setup **)

fun parse_single_symbol_pragma parse_keyword parse_isa parse_target =
  parse_keyword |-- Parse.!!! (parse_isa --| (@{keyword "\<rightharpoonup>"} || @{keyword "=>"})
    -- Parse.and_list1 (@{keyword "("} |-- (Parse.name --| @{keyword ")"} -- Scan.option parse_target)));

fun parse_symbol_pragma parse_const parse_tyco parse_class parse_classrel parse_inst parse_module =
  parse_single_symbol_pragma @{keyword "constant"} Parse.term parse_const
    >> Constant
  || parse_single_symbol_pragma @{keyword "type_constructor"} Parse.type_const parse_tyco
    >> Type_Constructor
  || parse_single_symbol_pragma @{keyword "type_class"} Parse.class parse_class
    >> Type_Class
  || parse_single_symbol_pragma @{keyword "class_relation"} parse_classrel_ident parse_classrel
    >> Class_Relation
  || parse_single_symbol_pragma @{keyword "class_instance"} parse_inst_ident parse_inst
    >> Class_Instance
  || parse_single_symbol_pragma @{keyword "code_module"} Parse.name parse_module
    >> Code_Symbol.Module;

fun parse_symbol_pragmas parse_const parse_tyco parse_class parse_classrel parse_inst parse_module =
  Parse.enum1 "|" (Parse.group (fn () => "code symbol pragma")
    (parse_symbol_pragma parse_const parse_tyco parse_class parse_classrel parse_inst parse_module));

val code_expr_argsP = Scan.optional (@{keyword "("} |-- Parse.args --| @{keyword ")"}) [];

fun code_expr_inP all_public raw_cs =
  Scan.repeat (@{keyword "in"} |-- Parse.!!! (Parse.name
    -- Scan.optional (@{keyword "module_name"} |-- Parse.name) ""
    -- Scan.optional (@{keyword "file"} |-- Parse.position Parse.path) ("", Position.none)
    -- code_expr_argsP))
      >> (fn seri_args => export_code_cmd all_public raw_cs seri_args);

fun code_expr_checkingP all_public raw_cs =
  (@{keyword "checking"} |-- Parse.!!!
    (Scan.repeat (Parse.name -- ((@{keyword "?"} |-- Scan.succeed false) || Scan.succeed true)
    -- code_expr_argsP)))
      >> (fn seri_args => check_code_cmd all_public raw_cs seri_args);

val code_exprP = (Scan.optional (@{keyword "open"} |-- Scan.succeed true) false
  -- Scan.repeat1 Parse.term)
  :|-- (fn (all_public, raw_cs) => (code_expr_checkingP all_public raw_cs || code_expr_inP all_public raw_cs));

val _ =
  Outer_Syntax.command @{command_keyword code_reserved}
    "declare words as reserved for target language"
    (Parse.name -- Scan.repeat1 Parse.name
      >> (fn (target, reserveds) => (Toplevel.theory o fold (add_reserved target)) reserveds));

val _ =
  Outer_Syntax.command @{command_keyword code_identifier} "declare mandatory names for code symbols"
    (parse_symbol_pragmas Parse.name Parse.name Parse.name Parse.name Parse.name Parse.name
      >> (Toplevel.theory o fold set_identifiers_cmd));

val _ =
  Outer_Syntax.command @{command_keyword code_printing} "declare dedicated printing for code symbols"
    (parse_symbol_pragmas (Code_Printer.parse_const_syntax) (Code_Printer.parse_tyco_syntax)
      Parse.string (Parse.minus >> K ()) (Parse.minus >> K ())
      (Parse.text -- Scan.optional (@{keyword "attach"} |-- Scan.repeat1 Parse.term) [])
      >> (Toplevel.theory o fold set_printings_cmd));

val _ =
  Outer_Syntax.command @{command_keyword export_code} "generate executable code for constants"
    (Parse.!!! code_exprP >> (fn f => Toplevel.keep (f o Toplevel.context_of)));

end; (*struct*)
