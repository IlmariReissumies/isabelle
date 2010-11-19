(*  Title:      HOL/Fun.thy
    Author:     Tobias Nipkow, Cambridge University Computer Laboratory
    Copyright   1994  University of Cambridge
*)

header {* Notions about functions *}

theory Fun
imports Complete_Lattice
begin

text{*As a simplification rule, it replaces all function equalities by
  first-order equalities.*}
lemma fun_eq_iff: "f = g \<longleftrightarrow> (\<forall>x. f x = g x)"
apply (rule iffI)
apply (simp (no_asm_simp))
apply (rule ext)
apply (simp (no_asm_simp))
done

lemma apply_inverse:
  "f x = u \<Longrightarrow> (\<And>x. P x \<Longrightarrow> g (f x) = x) \<Longrightarrow> P x \<Longrightarrow> x = g u"
  by auto


subsection {* The Identity Function @{text id} *}

definition
  id :: "'a \<Rightarrow> 'a"
where
  "id = (\<lambda>x. x)"

lemma id_apply [simp]: "id x = x"
  by (simp add: id_def)

lemma image_ident [simp]: "(%x. x) ` Y = Y"
by blast

lemma image_id [simp]: "id ` Y = Y"
by (simp add: id_def)

lemma vimage_ident [simp]: "(%x. x) -` Y = Y"
by blast

lemma vimage_id [simp]: "id -` A = A"
by (simp add: id_def)


subsection {* The Composition Operator @{text "f \<circ> g"} *}

definition
  comp :: "('b \<Rightarrow> 'c) \<Rightarrow> ('a \<Rightarrow> 'b) \<Rightarrow> 'a \<Rightarrow> 'c" (infixl "o" 55)
where
  "f o g = (\<lambda>x. f (g x))"

notation (xsymbols)
  comp  (infixl "\<circ>" 55)

notation (HTML output)
  comp  (infixl "\<circ>" 55)

text{*compatibility*}
lemmas o_def = comp_def

lemma o_apply [simp]: "(f o g) x = f (g x)"
by (simp add: comp_def)

lemma o_assoc: "f o (g o h) = f o g o h"
by (simp add: comp_def)

lemma id_o [simp]: "id o g = g"
by (simp add: comp_def)

lemma o_id [simp]: "f o id = f"
by (simp add: comp_def)

lemma o_eq_dest:
  "a o b = c o d \<Longrightarrow> a (b v) = c (d v)"
  by (simp only: o_def) (fact fun_cong)

lemma o_eq_elim:
  "a o b = c o d \<Longrightarrow> ((\<And>v. a (b v) = c (d v)) \<Longrightarrow> R) \<Longrightarrow> R"
  by (erule meta_mp) (fact o_eq_dest) 

lemma image_compose: "(f o g) ` r = f`(g`r)"
by (simp add: comp_def, blast)

lemma vimage_compose: "(g \<circ> f) -` x = f -` (g -` x)"
  by auto

lemma UN_o: "UNION A (g o f) = UNION (f`A) g"
by (unfold comp_def, blast)


subsection {* The Forward Composition Operator @{text fcomp} *}

definition
  fcomp :: "('a \<Rightarrow> 'b) \<Rightarrow> ('b \<Rightarrow> 'c) \<Rightarrow> 'a \<Rightarrow> 'c" (infixl "\<circ>>" 60)
where
  "f \<circ>> g = (\<lambda>x. g (f x))"

lemma fcomp_apply [simp]:  "(f \<circ>> g) x = g (f x)"
  by (simp add: fcomp_def)

lemma fcomp_assoc: "(f \<circ>> g) \<circ>> h = f \<circ>> (g \<circ>> h)"
  by (simp add: fcomp_def)

lemma id_fcomp [simp]: "id \<circ>> g = g"
  by (simp add: fcomp_def)

lemma fcomp_id [simp]: "f \<circ>> id = f"
  by (simp add: fcomp_def)

code_const fcomp
  (Eval infixl 1 "#>")

no_notation fcomp (infixl "\<circ>>" 60)


subsection {* Mapping functions *}

definition map_fun :: "('c \<Rightarrow> 'a) \<Rightarrow> ('b \<Rightarrow> 'd) \<Rightarrow> ('a \<Rightarrow> 'b) \<Rightarrow> 'c \<Rightarrow> 'd" where
  "map_fun f g h = g \<circ> h \<circ> f"

lemma map_fun_apply [simp]:
  "map_fun f g h x = g (h (f x))"
  by (simp add: map_fun_def)

type_mapper map_fun
  by (simp_all add: fun_eq_iff)


subsection {* Injectivity, Surjectivity and Bijectivity *}

definition inj_on :: "('a \<Rightarrow> 'b) \<Rightarrow> 'a set \<Rightarrow> bool" where -- "injective"
  "inj_on f A \<longleftrightarrow> (\<forall>x\<in>A. \<forall>y\<in>A. f x = f y \<longrightarrow> x = y)"

definition surj_on :: "('a \<Rightarrow> 'b) \<Rightarrow> 'b set \<Rightarrow> bool" where -- "surjective"
  "surj_on f B \<longleftrightarrow> B \<subseteq> range f"

definition bij_betw :: "('a \<Rightarrow> 'b) \<Rightarrow> 'a set \<Rightarrow> 'b set \<Rightarrow> bool" where -- "bijective"
  "bij_betw f A B \<longleftrightarrow> inj_on f A \<and> f ` A = B"

text{*A common special case: functions injective over the entire domain type.*}

abbreviation
  "inj f \<equiv> inj_on f UNIV"

abbreviation
  "surj f \<equiv> surj_on f UNIV"

abbreviation
  "bij f \<equiv> bij_betw f UNIV UNIV"

lemma injI:
  assumes "\<And>x y. f x = f y \<Longrightarrow> x = y"
  shows "inj f"
  using assms unfolding inj_on_def by auto

text{*For Proofs in @{text "Tools/Datatype/datatype_rep_proofs"}*}
lemma datatype_injI:
    "(!! x. ALL y. f(x) = f(y) --> x=y) ==> inj(f)"
by (simp add: inj_on_def)

theorem range_ex1_eq: "inj f \<Longrightarrow> b : range f = (EX! x. b = f x)"
  by (unfold inj_on_def, blast)

lemma injD: "[| inj(f); f(x) = f(y) |] ==> x=y"
by (simp add: inj_on_def)

lemma inj_on_eq_iff: "inj_on f A ==> x:A ==> y:A ==> (f(x) = f(y)) = (x=y)"
by (force simp add: inj_on_def)

lemma inj_comp:
  "inj f \<Longrightarrow> inj g \<Longrightarrow> inj (f \<circ> g)"
  by (simp add: inj_on_def)

lemma inj_fun: "inj f \<Longrightarrow> inj (\<lambda>x y. f x)"
  by (simp add: inj_on_def fun_eq_iff)

lemma inj_eq: "inj f ==> (f(x) = f(y)) = (x=y)"
by (simp add: inj_on_eq_iff)

lemma inj_on_id[simp]: "inj_on id A"
  by (simp add: inj_on_def)

lemma inj_on_id2[simp]: "inj_on (%x. x) A"
by (simp add: inj_on_def)

lemma surj_id[simp]: "surj_on id A"
by (simp add: surj_on_def)

lemma bij_id[simp]: "bij id"
by (simp add: bij_betw_def)

lemma inj_onI:
    "(!! x y. [|  x:A;  y:A;  f(x) = f(y) |] ==> x=y) ==> inj_on f A"
by (simp add: inj_on_def)

lemma inj_on_inverseI: "(!!x. x:A ==> g(f(x)) = x) ==> inj_on f A"
by (auto dest:  arg_cong [of concl: g] simp add: inj_on_def)

lemma inj_onD: "[| inj_on f A;  f(x)=f(y);  x:A;  y:A |] ==> x=y"
by (unfold inj_on_def, blast)

lemma inj_on_iff: "[| inj_on f A;  x:A;  y:A |] ==> (f(x)=f(y)) = (x=y)"
by (blast dest!: inj_onD)

lemma comp_inj_on:
     "[| inj_on f A;  inj_on g (f`A) |] ==> inj_on (g o f) A"
by (simp add: comp_def inj_on_def)

lemma inj_on_imageI: "inj_on (g o f) A \<Longrightarrow> inj_on g (f ` A)"
apply(simp add:inj_on_def image_def)
apply blast
done

lemma inj_on_image_iff: "\<lbrakk> ALL x:A. ALL y:A. (g(f x) = g(f y)) = (g x = g y);
  inj_on f A \<rbrakk> \<Longrightarrow> inj_on g (f ` A) = inj_on g A"
apply(unfold inj_on_def)
apply blast
done

lemma inj_on_contraD: "[| inj_on f A;  ~x=y;  x:A;  y:A |] ==> ~ f(x)=f(y)"
by (unfold inj_on_def, blast)

lemma inj_singleton: "inj (%s. {s})"
by (simp add: inj_on_def)

lemma inj_on_empty[iff]: "inj_on f {}"
by(simp add: inj_on_def)

lemma subset_inj_on: "[| inj_on f B; A <= B |] ==> inj_on f A"
by (unfold inj_on_def, blast)

lemma inj_on_Un:
 "inj_on f (A Un B) =
  (inj_on f A & inj_on f B & f`(A-B) Int f`(B-A) = {})"
apply(unfold inj_on_def)
apply (blast intro:sym)
done

lemma inj_on_insert[iff]:
  "inj_on f (insert a A) = (inj_on f A & f a ~: f`(A-{a}))"
apply(unfold inj_on_def)
apply (blast intro:sym)
done

lemma inj_on_diff: "inj_on f A ==> inj_on f (A-B)"
apply(unfold inj_on_def)
apply (blast)
done

lemma surj_onI: "(\<And>x. x \<in> B \<Longrightarrow> g (f x) = x) \<Longrightarrow> surj_on g B"
  by (simp add: surj_on_def) (blast intro: sym)

lemma surj_onD: "surj_on f B \<Longrightarrow> y \<in> B \<Longrightarrow> \<exists>x. y = f x"
  by (auto simp: surj_on_def)

lemma surj_on_range_iff: "surj_on f B \<longleftrightarrow> (\<exists>A. f ` A = B)"
  unfolding surj_on_def by (auto intro!: exI[of _ "f -` B"])

lemma surj_def: "surj f \<longleftrightarrow> (\<forall>y. \<exists>x. y = f x)"
  by (simp add: surj_on_def subset_eq image_iff)

lemma surjI: "(\<And> x. g (f x) = x) \<Longrightarrow> surj g"
  by (blast intro: surj_onI)

lemma surjD: "surj f \<Longrightarrow> \<exists>x. y = f x"
  by (simp add: surj_def)

lemma surjE: "surj f \<Longrightarrow> (\<And>x. y = f x \<Longrightarrow> C) \<Longrightarrow> C"
  by (simp add: surj_def, blast)

lemma comp_surj: "[| surj f;  surj g |] ==> surj (g o f)"
apply (simp add: comp_def surj_def, clarify)
apply (drule_tac x = y in spec, clarify)
apply (drule_tac x = x in spec, blast)
done

lemma surj_range: "surj f \<Longrightarrow> range f = UNIV"
  by (auto simp add: surj_on_def)

lemma surj_range_iff: "surj f \<longleftrightarrow> range f = UNIV"
  unfolding surj_on_def by auto

lemma bij_betw_imp_surj: "bij_betw f A UNIV \<Longrightarrow> surj f"
  unfolding bij_betw_def surj_range_iff by auto

lemma bij_def: "bij f \<longleftrightarrow> inj f \<and> surj f"
  unfolding surj_range_iff bij_betw_def ..

lemma bijI: "[| inj f; surj f |] ==> bij f"
by (simp add: bij_def)

lemma bij_is_inj: "bij f ==> inj f"
by (simp add: bij_def)

lemma bij_is_surj: "bij f ==> surj f"
by (simp add: bij_def)

lemma bij_betw_imp_inj_on: "bij_betw f A B \<Longrightarrow> inj_on f A"
by (simp add: bij_betw_def)

lemma bij_betw_imp_surj_on: "bij_betw f A B \<Longrightarrow> surj_on f B"
by (auto simp: bij_betw_def surj_on_range_iff)

lemma bij_comp: "bij f \<Longrightarrow> bij g \<Longrightarrow> bij (g o f)"
by(fastsimp intro: comp_inj_on comp_surj simp: bij_def surj_range)

lemma bij_betw_trans:
  "bij_betw f A B \<Longrightarrow> bij_betw g B C \<Longrightarrow> bij_betw (g o f) A C"
by(auto simp add:bij_betw_def comp_inj_on)

lemma bij_betw_inv: assumes "bij_betw f A B" shows "EX g. bij_betw g B A"
proof -
  have i: "inj_on f A" and s: "f ` A = B"
    using assms by(auto simp:bij_betw_def)
  let ?P = "%b a. a:A \<and> f a = b" let ?g = "%b. The (?P b)"
  { fix a b assume P: "?P b a"
    hence ex1: "\<exists>a. ?P b a" using s unfolding image_def by blast
    hence uex1: "\<exists>!a. ?P b a" by(blast dest:inj_onD[OF i])
    hence " ?g b = a" using the1_equality[OF uex1, OF P] P by simp
  } note g = this
  have "inj_on ?g B"
  proof(rule inj_onI)
    fix x y assume "x:B" "y:B" "?g x = ?g y"
    from s `x:B` obtain a1 where a1: "?P x a1" unfolding image_def by blast
    from s `y:B` obtain a2 where a2: "?P y a2" unfolding image_def by blast
    from g[OF a1] a1 g[OF a2] a2 `?g x = ?g y` show "x=y" by simp
  qed
  moreover have "?g ` B = A"
  proof(auto simp:image_def)
    fix b assume "b:B"
    with s obtain a where P: "?P b a" unfolding image_def by blast
    thus "?g b \<in> A" using g[OF P] by auto
  next
    fix a assume "a:A"
    then obtain b where P: "?P b a" using s unfolding image_def by blast
    then have "b:B" using s unfolding image_def by blast
    with g[OF P] show "\<exists>b\<in>B. a = ?g b" by blast
  qed
  ultimately show ?thesis by(auto simp:bij_betw_def)
qed

lemma bij_betw_combine:
  assumes "bij_betw f A B" "bij_betw f C D" "B \<inter> D = {}"
  shows "bij_betw f (A \<union> C) (B \<union> D)"
  using assms unfolding bij_betw_def inj_on_Un image_Un by auto

lemma surj_image_vimage_eq: "surj f ==> f ` (f -` A) = A"
by (simp add: surj_range)

lemma inj_vimage_image_eq: "inj f ==> f -` (f ` A) = A"
by (simp add: inj_on_def, blast)

lemma vimage_subsetD: "surj f ==> f -` B <= A ==> B <= f ` A"
apply (unfold surj_def)
apply (blast intro: sym)
done

lemma vimage_subsetI: "inj f ==> B <= f ` A ==> f -` B <= A"
by (unfold inj_on_def, blast)

lemma vimage_subset_eq: "bij f ==> (f -` B <= A) = (B <= f ` A)"
apply (unfold bij_def)
apply (blast del: subsetI intro: vimage_subsetI vimage_subsetD)
done

lemma inj_on_Un_image_eq_iff: "inj_on f (A \<union> B) \<Longrightarrow> f ` A = f ` B \<longleftrightarrow> A = B"
by(blast dest: inj_onD)

lemma inj_on_image_Int:
   "[| inj_on f C;  A<=C;  B<=C |] ==> f`(A Int B) = f`A Int f`B"
apply (simp add: inj_on_def, blast)
done

lemma inj_on_image_set_diff:
   "[| inj_on f C;  A<=C;  B<=C |] ==> f`(A-B) = f`A - f`B"
apply (simp add: inj_on_def, blast)
done

lemma image_Int: "inj f ==> f`(A Int B) = f`A Int f`B"
by (simp add: inj_on_def, blast)

lemma image_set_diff: "inj f ==> f`(A-B) = f`A - f`B"
by (simp add: inj_on_def, blast)

lemma inj_image_mem_iff: "inj f ==> (f a : f`A) = (a : A)"
by (blast dest: injD)

lemma inj_image_subset_iff: "inj f ==> (f`A <= f`B) = (A<=B)"
by (simp add: inj_on_def, blast)

lemma inj_image_eq_iff: "inj f ==> (f`A = f`B) = (A = B)"
by (blast dest: injD)

(*injectivity's required.  Left-to-right inclusion holds even if A is empty*)
lemma image_INT:
   "[| inj_on f C;  ALL x:A. B x <= C;  j:A |]
    ==> f ` (INTER A B) = (INT x:A. f ` B x)"
apply (simp add: inj_on_def, blast)
done

(*Compare with image_INT: no use of inj_on, and if f is surjective then
  it doesn't matter whether A is empty*)
lemma bij_image_INT: "bij f ==> f ` (INTER A B) = (INT x:A. f ` B x)"
apply (simp add: bij_def)
apply (simp add: inj_on_def surj_def, blast)
done

lemma surj_Compl_image_subset: "surj f ==> -(f`A) <= f`(-A)"
by (auto simp add: surj_def)

lemma inj_image_Compl_subset: "inj f ==> f`(-A) <= -(f`A)"
by (auto simp add: inj_on_def)

lemma bij_image_Compl_eq: "bij f ==> f`(-A) = -(f`A)"
apply (simp add: bij_def)
apply (rule equalityI)
apply (simp_all (no_asm_simp) add: inj_image_Compl_subset surj_Compl_image_subset)
done

lemma (in ordered_ab_group_add) inj_uminus[simp, intro]: "inj_on uminus A"
  by (auto intro!: inj_onI)

lemma (in linorder) strict_mono_imp_inj_on: "strict_mono f \<Longrightarrow> inj_on f A"
  by (auto intro!: inj_onI dest: strict_mono_eq)

subsection{*Function Updating*}

definition
  fun_upd :: "('a => 'b) => 'a => 'b => ('a => 'b)" where
  "fun_upd f a b == % x. if x=a then b else f x"

nonterminals
  updbinds updbind
syntax
  "_updbind" :: "['a, 'a] => updbind"             ("(2_ :=/ _)")
  ""         :: "updbind => updbinds"             ("_")
  "_updbinds":: "[updbind, updbinds] => updbinds" ("_,/ _")
  "_Update"  :: "['a, updbinds] => 'a"            ("_/'((_)')" [1000, 0] 900)

translations
  "_Update f (_updbinds b bs)" == "_Update (_Update f b) bs"
  "f(x:=y)" == "CONST fun_upd f x y"

(* Hint: to define the sum of two functions (or maps), use sum_case.
         A nice infix syntax could be defined (in Datatype.thy or below) by
notation
  sum_case  (infixr "'(+')"80)
*)

lemma fun_upd_idem_iff: "(f(x:=y) = f) = (f x = y)"
apply (simp add: fun_upd_def, safe)
apply (erule subst)
apply (rule_tac [2] ext, auto)
done

(* f x = y ==> f(x:=y) = f *)
lemmas fun_upd_idem = fun_upd_idem_iff [THEN iffD2, standard]

(* f(x := f x) = f *)
lemmas fun_upd_triv = refl [THEN fun_upd_idem]
declare fun_upd_triv [iff]

lemma fun_upd_apply [simp]: "(f(x:=y))z = (if z=x then y else f z)"
by (simp add: fun_upd_def)

(* fun_upd_apply supersedes these two,   but they are useful
   if fun_upd_apply is intentionally removed from the simpset *)
lemma fun_upd_same: "(f(x:=y)) x = y"
by simp

lemma fun_upd_other: "z~=x ==> (f(x:=y)) z = f z"
by simp

lemma fun_upd_upd [simp]: "f(x:=y,x:=z) = f(x:=z)"
by (simp add: fun_eq_iff)

lemma fun_upd_twist: "a ~= c ==> (m(a:=b))(c:=d) = (m(c:=d))(a:=b)"
by (rule ext, auto)

lemma inj_on_fun_updI: "\<lbrakk> inj_on f A; y \<notin> f`A \<rbrakk> \<Longrightarrow> inj_on (f(x:=y)) A"
by (fastsimp simp:inj_on_def image_def)

lemma fun_upd_image:
     "f(x:=y) ` A = (if x \<in> A then insert y (f ` (A-{x})) else f ` A)"
by auto

lemma fun_upd_comp: "f \<circ> (g(x := y)) = (f \<circ> g)(x := f y)"
by (auto intro: ext)


subsection {* @{text override_on} *}

definition
  override_on :: "('a \<Rightarrow> 'b) \<Rightarrow> ('a \<Rightarrow> 'b) \<Rightarrow> 'a set \<Rightarrow> 'a \<Rightarrow> 'b"
where
  "override_on f g A = (\<lambda>a. if a \<in> A then g a else f a)"

lemma override_on_emptyset[simp]: "override_on f g {} = f"
by(simp add:override_on_def)

lemma override_on_apply_notin[simp]: "a ~: A ==> (override_on f g A) a = f a"
by(simp add:override_on_def)

lemma override_on_apply_in[simp]: "a : A ==> (override_on f g A) a = g a"
by(simp add:override_on_def)


subsection {* @{text swap} *}

definition
  swap :: "'a \<Rightarrow> 'a \<Rightarrow> ('a \<Rightarrow> 'b) \<Rightarrow> ('a \<Rightarrow> 'b)"
where
  "swap a b f = f (a := f b, b:= f a)"

lemma swap_self [simp]: "swap a a f = f"
by (simp add: swap_def)

lemma swap_commute: "swap a b f = swap b a f"
by (rule ext, simp add: fun_upd_def swap_def)

lemma swap_nilpotent [simp]: "swap a b (swap a b f) = f"
by (rule ext, simp add: fun_upd_def swap_def)

lemma swap_triple:
  assumes "a \<noteq> c" and "b \<noteq> c"
  shows "swap a b (swap b c (swap a b f)) = swap a c f"
  using assms by (simp add: fun_eq_iff swap_def)

lemma comp_swap: "f \<circ> swap a b g = swap a b (f \<circ> g)"
by (rule ext, simp add: fun_upd_def swap_def)

lemma swap_image_eq [simp]:
  assumes "a \<in> A" "b \<in> A" shows "swap a b f ` A = f ` A"
proof -
  have subset: "\<And>f. swap a b f ` A \<subseteq> f ` A"
    using assms by (auto simp: image_iff swap_def)
  then have "swap a b (swap a b f) ` A \<subseteq> (swap a b f) ` A" .
  with subset[of f] show ?thesis by auto
qed

lemma inj_on_imp_inj_on_swap:
  "\<lbrakk>inj_on f A; a \<in> A; b \<in> A\<rbrakk> \<Longrightarrow> inj_on (swap a b f) A"
  by (simp add: inj_on_def swap_def, blast)

lemma inj_on_swap_iff [simp]:
  assumes A: "a \<in> A" "b \<in> A" shows "inj_on (swap a b f) A \<longleftrightarrow> inj_on f A"
proof
  assume "inj_on (swap a b f) A"
  with A have "inj_on (swap a b (swap a b f)) A"
    by (iprover intro: inj_on_imp_inj_on_swap)
  thus "inj_on f A" by simp
next
  assume "inj_on f A"
  with A show "inj_on (swap a b f) A" by (iprover intro: inj_on_imp_inj_on_swap)
qed

lemma surj_imp_surj_swap: "surj f \<Longrightarrow> surj (swap a b f)"
  unfolding surj_range_iff by simp

lemma surj_swap_iff [simp]: "surj (swap a b f) \<longleftrightarrow> surj f"
  unfolding surj_range_iff by simp

lemma bij_betw_swap_iff [simp]:
  "\<lbrakk> x \<in> A; y \<in> A \<rbrakk> \<Longrightarrow> bij_betw (swap x y f) A B \<longleftrightarrow> bij_betw f A B"
  by (auto simp: bij_betw_def)

lemma bij_swap_iff [simp]: "bij (swap a b f) \<longleftrightarrow> bij f"
  by simp

hide_const (open) swap

subsection {* Inversion of injective functions *}

definition the_inv_into :: "'a set => ('a => 'b) => ('b => 'a)" where
"the_inv_into A f == %x. THE y. y : A & f y = x"

lemma the_inv_into_f_f:
  "[| inj_on f A;  x : A |] ==> the_inv_into A f (f x) = x"
apply (simp add: the_inv_into_def inj_on_def)
apply blast
done

lemma f_the_inv_into_f:
  "inj_on f A ==> y : f`A  ==> f (the_inv_into A f y) = y"
apply (simp add: the_inv_into_def)
apply (rule the1I2)
 apply(blast dest: inj_onD)
apply blast
done

lemma the_inv_into_into:
  "[| inj_on f A; x : f ` A; A <= B |] ==> the_inv_into A f x : B"
apply (simp add: the_inv_into_def)
apply (rule the1I2)
 apply(blast dest: inj_onD)
apply blast
done

lemma the_inv_into_onto[simp]:
  "inj_on f A ==> the_inv_into A f ` (f ` A) = A"
by (fast intro:the_inv_into_into the_inv_into_f_f[symmetric])

lemma the_inv_into_f_eq:
  "[| inj_on f A; f x = y; x : A |] ==> the_inv_into A f y = x"
  apply (erule subst)
  apply (erule the_inv_into_f_f, assumption)
  done

lemma the_inv_into_comp:
  "[| inj_on f (g ` A); inj_on g A; x : f ` g ` A |] ==>
  the_inv_into A (f o g) x = (the_inv_into A g o the_inv_into (g ` A) f) x"
apply (rule the_inv_into_f_eq)
  apply (fast intro: comp_inj_on)
 apply (simp add: f_the_inv_into_f the_inv_into_into)
apply (simp add: the_inv_into_into)
done

lemma inj_on_the_inv_into:
  "inj_on f A \<Longrightarrow> inj_on (the_inv_into A f) (f ` A)"
by (auto intro: inj_onI simp: image_def the_inv_into_f_f)

lemma bij_betw_the_inv_into:
  "bij_betw f A B \<Longrightarrow> bij_betw (the_inv_into A f) B A"
by (auto simp add: bij_betw_def inj_on_the_inv_into the_inv_into_into)

abbreviation the_inv :: "('a \<Rightarrow> 'b) \<Rightarrow> ('b \<Rightarrow> 'a)" where
  "the_inv f \<equiv> the_inv_into UNIV f"

lemma the_inv_f_f:
  assumes "inj f"
  shows "the_inv f (f x) = x" using assms UNIV_I
  by (rule the_inv_into_f_f)


subsection {* Proof tool setup *} 

text {* simplifies terms of the form
  f(...,x:=y,...,x:=z,...) to f(...,x:=z,...) *}

simproc_setup fun_upd2 ("f(v := w, x := y)") = {* fn _ =>
let
  fun gen_fun_upd NONE T _ _ = NONE
    | gen_fun_upd (SOME f) T x y = SOME (Const (@{const_name fun_upd}, T) $ f $ x $ y)
  fun dest_fun_T1 (Type (_, T :: Ts)) = T
  fun find_double (t as Const (@{const_name fun_upd},T) $ f $ x $ y) =
    let
      fun find (Const (@{const_name fun_upd},T) $ g $ v $ w) =
            if v aconv x then SOME g else gen_fun_upd (find g) T v w
        | find t = NONE
    in (dest_fun_T1 T, gen_fun_upd (find f) T x y) end

  fun proc ss ct =
    let
      val ctxt = Simplifier.the_context ss
      val t = Thm.term_of ct
    in
      case find_double t of
        (T, NONE) => NONE
      | (T, SOME rhs) =>
          SOME (Goal.prove ctxt [] [] (Logic.mk_equals (t, rhs))
            (fn _ =>
              rtac eq_reflection 1 THEN
              rtac ext 1 THEN
              simp_tac (Simplifier.inherit_context ss @{simpset}) 1))
    end
in proc end
*}


subsection {* Code generator setup *}

types_code
  "fun"  ("(_ ->/ _)")
attach (term_of) {*
fun term_of_fun_type _ aT _ bT _ = Free ("<function>", aT --> bT);
*}
attach (test) {*
fun gen_fun_type aF aT bG bT i =
  let
    val tab = Unsynchronized.ref [];
    fun mk_upd (x, (_, y)) t = Const ("Fun.fun_upd",
      (aT --> bT) --> aT --> bT --> aT --> bT) $ t $ aF x $ y ()
  in
    (fn x =>
       case AList.lookup op = (!tab) x of
         NONE =>
           let val p as (y, _) = bG i
           in (tab := (x, p) :: !tab; y) end
       | SOME (y, _) => y,
     fn () => Basics.fold mk_upd (!tab) (Const ("HOL.undefined", aT --> bT)))
  end;
*}

code_const "op \<circ>"
  (SML infixl 5 "o")
  (Haskell infixr 9 ".")

code_const "id"
  (Haskell "id")

end
