(*  Title:      HOL/HOLCF/IOA/NTP/Lemmas.thy
    Author:     Tobias Nipkow & Konrad Slind
*)

theory Lemmas
imports Main
begin

subsubsection \<open>Logic\<close>

lemma neg_flip: "(X = (~ Y)) = ((~X) = Y)"
  by blast


subsection \<open>Sets\<close>

lemma set_lemmas:
  "f(x) : (UN x. {f(x)})"
  "f x y : (UN x y. {f x y})"
  "!!a. (!x. a ~= f(x)) ==> a ~: (UN x. {f(x)})"
  "!!a. (!x y. a ~= f x y) ==> a ~: (UN x y. {f x y})"
  by auto


subsection \<open>Arithmetic\<close>

lemma pred_suc: "0<x ==> (x - 1 = y) = (x = Suc(y))"
  by (simp add: diff_Suc split: nat.split)

lemmas [simp] = hd_append set_lemmas

end
