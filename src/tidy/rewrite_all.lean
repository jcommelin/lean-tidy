-- Copyright (c) 2018 Scott Morrison. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.
-- Authors: Scott Morrison

import data.list
import .pretty_print

open tactic
open interactive
open interactive.types
open expr
open lean
open lean.parser

meta def lock_tactic_state {α} (t : tactic α) : tactic α
| s := match t s with
       | result.success a s' := result.success a s
       | result.exception msg pos s' := result.exception msg pos s
       end

meta def rewrite_without_new_mvars (r : expr) (e : expr) (cfg : rewrite_cfg := {}) : tactic (expr × expr) :=
lock_tactic_state $ -- Sorry I don't have a MWE example, but without this natural_transformation.lean fails.
do n_before ← num_goals,
   (new_t, prf, metas) ← rewrite_core r e cfg,
   try_apply_opt_auto_param cfg.to_apply_cfg metas,
   n_after ← num_goals,
   guard (n_before = n_after),
   return (new_t, prf)

meta def mk_eq_symm_under_binders_aux : expr → (nat → expr) → tactic expr
| (expr.pi n bi d b) f := expr.lam n bi d <$> mk_eq_symm_under_binders_aux b (λ n, f (n+1) (expr.var n))
| `(%%a = %%b) e := mk_eq_symm (e 0)
| _ _ := fail "expression must have the form `Π x y z, a = b`"

meta def mk_eq_symm_under_binders : expr → tactic expr
| e := do t ← infer_type e, mk_eq_symm_under_binders_aux t (λ _, e)

meta def rewrite_entire (r : (expr × bool)) (e : expr) : tactic (expr × expr) :=
do let sl := simp_lemmas.mk,
   r' ← if r.2 then mk_eq_symm_under_binders r.1 else pure r.1,
   sl ← sl.add r',
   sl.rewrite e failed `eq semireducible

open tactic.interactive

meta inductive expr_lens
| app_fun : expr_lens → expr → expr_lens
| app_arg : expr_lens → expr → expr_lens
| entire  : expr_lens

open expr_lens

meta def expr_lens.replace : expr_lens → expr → expr
| (app_fun l f) x := expr_lens.replace l (expr.app f x)
| (app_arg l x) f := expr_lens.replace l (expr.app f x)
| entire        e := e 

meta def expr_lens.congr : expr_lens → expr → tactic expr
| (app_fun l f) x_eq := do fx_eq ← mk_congr_arg f x_eq,
                                    expr_lens.congr l fx_eq
| (app_arg l x) f_eq := do fx_eq ← mk_congr_fun f_eq x,
                                    expr_lens.congr l fx_eq
| entire                  e_eq := pure e_eq

meta def rewrite_fold_aux {α} (F : expr_lens → expr → α → tactic α) : expr_lens → expr → α → tactic α 
| l e a := (do a' ← F l e a,
              match e with
              | (expr.app f x) := do a_f ← rewrite_fold_aux (expr_lens.app_arg l x) f a',
                                            rewrite_fold_aux (expr_lens.app_fun l f) x a_f
              | _ := pure a'
              end) <|> pure a
. 

meta def rewrite_fold {α} (F : expr_lens → expr → α → tactic α) (e : expr) (a : α) : tactic α := rewrite_fold_aux F expr_lens.entire e a

meta def rewrite_F (r : expr × bool) (l : expr_lens) (e : expr) (state : list (expr × expr)) : tactic (list (expr × expr)) := 
do 
  (v, pr) ← rewrite_without_new_mvars r.1 e {symm := r.2, md := semireducible},
  -- Now we determine whether the rewrite transforms the entire expression or not:
  (do 
    (w, qr) ← rewrite_entire r e,
    let w' := l.replace w,
    qr' ← l.congr qr,
    pure ((w', qr') :: state)
  ) <|>
  (do
    pure (state)
  )

def remove_adjacent_duplicates {α β} (f : α → β) [decidable_eq β] : list α → list α
| (x :: y :: t) := if f x = f y then
                     remove_adjacent_duplicates (y :: t)
                   else
                     x :: (remove_adjacent_duplicates (y :: t))
| [x] := [x]
| [] := []

meta def all_rewrites (r : expr × bool) (e : expr) : tactic (list (expr × expr)) :=
do 
   results ← rewrite_fold (rewrite_F r) e [],
   let results : list (expr × expr) := remove_adjacent_duplicates (λ p, p.1) results,
   pure results

-- return a list of (e', prf, n, k) where 
--   e' is a new expression, 
--   prf : e = e', 
--   n is the index of the rule r used from rs, and 
--   k is the index of (e', prf) in all_rewrites r e.
meta def all_rewrites_list (rs : list (expr × bool)) (e : expr) : tactic (list (expr × expr × ℕ × ℕ)) :=
do
  results ← rs.mmap $ λ r, all_rewrites r e,
  let results' := results.enum.map (λ p, p.2.enum.map (λ q, (q.2.1, q.2.2, p.1, q.1))),
  return results'.join

meta def perform_nth_rewrite (r : expr × bool) (n : ℕ) : tactic unit := 
do e ← target,
   rewrites ← all_rewrites r e,
   (new_t, prf) ← rewrites.nth n,
   replace_target new_t prf

meta def all_rewrites_using (a : name) (e : expr) : tactic (list (expr × expr)) :=
do names ← attribute.get_instances a,
   rules ← names.mmap $ mk_const,
   let pairs := rules.map (λ e, (e, ff)) ++ rules.map (λ e, (e, tt)),
   results ← pairs.mmap $ λ r, all_rewrites r e,
   pure results.join

namespace tactic.interactive

private meta def perform_nth_rewrite' (q : parse rw_rules) (n : ℕ) (e : expr) : tactic (expr × expr) := 
do rewrites ← q.rules.mmap $ λ p : rw_rule, to_expr p.rule >>= λ r, all_rewrites (r, p.symm) e,
   let rewrites := rewrites.join,
   rewrites.nth n

meta def perform_nth_rewrite (q : parse rw_rules) (n : ℕ) : tactic unit := 
do e ← target,
   (new_t, prf) ← perform_nth_rewrite' q n e,
   replace_target new_t prf,
   tactic.try tactic.reflexivity

meta def replace_target_lhs (new_lhs prf: expr) : tactic unit :=
do `(%%lhs = %%rhs) ← target,
   new_target ← to_expr ``(%%new_lhs = %%rhs),
   prf' ← to_expr ``(congr_arg (λ L, L = %%rhs) %%prf),
   replace_target new_target prf'

meta def replace_target_rhs (new_rhs prf: expr) : tactic unit :=
do `(%%lhs = %%rhs) ← target,
   new_target ← to_expr ``(%%lhs = %%new_rhs),
   prf' ← to_expr ``(congr_arg (λ R, %%lhs = R) %%prf),
   replace_target new_target prf'

meta def perform_nth_rewrite_lhs (q : parse rw_rules) (n : ℕ) : tactic unit := 
do `(%%lhs = %%rhs) ← target,
   (new_t, prf) ← perform_nth_rewrite' q n lhs,
   replace_target_lhs new_t prf,
   tactic.try tactic.reflexivity

meta def perform_nth_rewrite_rhs (q : parse rw_rules) (n : ℕ) : tactic unit := 
do `(%%lhs = %%rhs) ← target,
   (new_t, prf) ← perform_nth_rewrite' q n rhs,
   replace_target_rhs new_t prf,
   tactic.try tactic.reflexivity


meta def perform_nth_rewrite_using (a : name) (n : ℕ) : tactic unit := 
do e ← target,
   rewrites ← all_rewrites_using a e,
   (new_t, prf) ← rewrites.nth n,
   replace_target new_t prf

end tactic.interactive