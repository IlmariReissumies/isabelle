(* Author: Markus Wenzel, Stefan Berghofer, and Tobias Nipkow
   Author: Brian Huffman

Basic arithmetic for natural numbers.
*)

signature NAT_ARITH =
sig
  val cancel_diff_conv: Proof.context -> conv
  val cancel_eq_conv: Proof.context -> conv
  val cancel_le_conv: Proof.context -> conv
  val cancel_less_conv: Proof.context -> conv
end;

structure Nat_Arith: NAT_ARITH =
struct

val add1 = @{lemma "(A::'a::comm_monoid_add) == k + a ==> A + b == k + (a + b)"
      by (simp only: ac_simps)}
val add2 = @{lemma "(B::'a::comm_monoid_add) == k + b ==> a + B == k + (a + b)"
      by (simp only: ac_simps)}
val suc1 = @{lemma "A == k + a ==> Suc A == k + Suc a"
      by (simp only: add_Suc_right)}
val rule0 = @{lemma "(a::'a::comm_monoid_add) == a + 0"
      by (simp only: add_0_right)}

val norm_rules = map mk_meta_eq @{thms add_0_left add_0_right}

fun move_to_front ctxt path = Conv.every_conv
    [Conv.rewr_conv (Library.foldl (op RS) (rule0, path)),
     Conv.arg_conv (Raw_Simplifier.rewrite ctxt false norm_rules)]

fun add_atoms path (Const (\<^const_name>\<open>Groups.plus\<close>, _) $ x $ y) =
      add_atoms (add1::path) x #> add_atoms (add2::path) y
  | add_atoms path (Const (\<^const_name>\<open>Nat.Suc\<close>, _) $ x) =
      add_atoms (suc1::path) x
  | add_atoms _ (Const (\<^const_name>\<open>Groups.zero\<close>, _)) = I
  | add_atoms path x = cons (x, path)

fun atoms t = add_atoms [] t []

exception Cancel

fun find_common ord xs ys =
  let
    fun find (xs as (x, px)::xs') (ys as (y, py)::ys') =
        (case ord (x, y) of
          EQUAL => (px, py)
        | LESS => find xs' ys
        | GREATER => find xs ys')
      | find _ _ = raise Cancel
    fun ord' ((x, _), (y, _)) = ord (x, y)
  in
    find (sort ord' xs) (sort ord' ys)
  end

fun cancel_conv rule ctxt ct =
  let
    val ((_, lhs), rhs) = (apfst dest_comb o dest_comb) (Thm.term_of ct)
    val (lpath, rpath) = find_common Term_Ord.term_ord (atoms lhs) (atoms rhs)
    val lconv = move_to_front ctxt lpath
    val rconv = move_to_front ctxt rpath
    val conv1 = Conv.combination_conv (Conv.arg_conv lconv) rconv
    val conv = conv1 then_conv Conv.rewr_conv rule
  in conv ct end
    handle Cancel => raise CTERM ("no_conversion", [])

val cancel_diff_conv = cancel_conv (mk_meta_eq @{thm add_diff_cancel_left [where ?'a = nat]})
val cancel_eq_conv = cancel_conv (mk_meta_eq @{thm add_left_cancel [where ?'a = nat]})
val cancel_le_conv = cancel_conv (mk_meta_eq @{thm add_le_cancel_left [where ?'a = nat]})
val cancel_less_conv = cancel_conv (mk_meta_eq @{thm add_less_cancel_left [where ?'a = nat]})

end;
