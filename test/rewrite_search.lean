import tidy.rewrite_search

namespace tidy.rewrite_search.testing

axiom foo' : [6] = [7]
axiom bar' : [[6],[6]] = [[5],[5]]

example : [[7],[6]] = [[5],[5]] :=
begin
 success_if_fail { rewrite_search [] },
-- rw [←foo', bar']
 rewrite_search [←foo', bar'],
end

@[search] private axiom foo : [0] = [1]
@[search] private axiom bar1 : [1] = [2]
@[search] private axiom bar2 : [3] = [2]
@[search] private axiom bar3 : [3] = [4]

private example (a : unit) : [[0],[0]] = [[4],[4]] :=
begin
  -- perform_nth_rewrite_lhs [foo] 0,
  -- perform_nth_rewrite_lhs [bar1] 0,
  -- perform_nth_rewrite_lhs [←bar2] 0,
  -- perform_nth_rewrite_lhs [foo] 0,
  -- perform_nth_rewrite_lhs [bar1] 0,
  -- perform_nth_rewrite_lhs [←bar2] 0,
  -- perform_nth_rewrite_rhs [←bar3] 0,
  -- perform_nth_rewrite_rhs [←bar3] 0,
  rewrite_search [foo, bar1, ← bar2, bar2, ← bar3],
end

private example : [[0],[0]] = [[4],[4]] :=
begin
    rewrite_search_using `search,
end

@[search] private axiom qux' : [[1], [2]] = [[6], [7]]
@[search] private axiom qux'' : [6] = [7]
private example : [[1], [1]] = [[7], [7]] :=
begin
  -- perform_nth_rewrite_lhs [bar1] 0,
  -- perform_nth_rewrite_lhs [qux'] 0,
  -- perform_nth_rewrite_lhs [qux''] 0,
  rewrite_search_using `search,
end

private example : [[0],[0]] = [[4],[4]] :=
begin
  -- perform_nth_rewrite_lhs [foo] 0,
  -- perform_nth_rewrite_lhs [bar1] 0,
  -- perform_nth_rewrite_lhs [←bar2] 0,
  -- perform_nth_rewrite_lhs [bar3] 0,
  -- perform_nth_rewrite_lhs [foo] 0,
  -- perform_nth_rewrite_lhs [bar1] 0,
  -- perform_nth_rewrite_lhs [←bar2] 0,
  -- perform_nth_rewrite_lhs [bar3] 0,
  rewrite_search_using `search {trace:=tt},
end

private structure cat :=
  (O : Type)
  (H : O → O → Type)
  (i : Π o : O, H o o)
  (c : Π {X Y Z : O} (f : H X Y) (g : H Y Z), H X Z)
  (li : Π {X Y : O} (f : H X Y), c (i X) f = f)
  (ri : Π {X Y : O} (f : H X Y), c f (i Y) = f)
  (a : Π {W X Y Z : O} (f : H W X) (g : H X Y) (h : H Y Z), c (c f g) h = c f (c g h))

attribute [search] cat.li cat.a

private example (C : cat) (X Y Z : C.O) (f : C.H X Y) (g : C.H Y X) (w : C.c g f = C.i Y) (h k : C.H Y Z) (p : C.c f h = C.c f k) : h = k := 
begin
-- rewrite_search_using `search {trace := tt, trace_rules:=tt}, -- not quite there, we haven't activated intense search
perform_nth_rewrite [← @cat.li C Y Z h] 0,
perform_nth_rewrite [← w] 0,
perform_nth_rewrite [C.a] 0,
perform_nth_rewrite [p] 0,
perform_nth_rewrite [← C.a] 0,
perform_nth_rewrite [w] 0,
perform_nth_rewrite [@cat.li C Y Z k] 0,
-- PROJECT automate this!
-- rw [← C.li Y Z h],
-- rw [← C.li Y Z k],
-- rw [← w],
-- rw [C.a],
-- rw [C.a],
-- rw [p],
end

end tidy.rewrite_search.testing

namespace tidy.rewrite_search.examples

constants f g : ℕ → ℕ → ℕ → ℕ 
@[search] axiom f_0_0 : ∀ a b c : ℕ, f a b c = f 0 b c
@[search] axiom f_0_1 : ∀ a b c : ℕ, f a b c = f 1 b c
@[search] axiom f_0_2 : ∀ a b c : ℕ, f a b c = f 2 b c 
@[search] axiom f_1_0 : ∀ a b c : ℕ, f a b c = f a 0 c
@[search] axiom f_1_1 : ∀ a b c : ℕ, f a b c = f a 1 c
@[search] axiom f_1_2 : ∀ a b c : ℕ, f a b c = f a 2 c 
@[search] axiom f_2_0 : ∀ a b c : ℕ, f a b c = f a b 0
@[search] axiom f_2_1 : ∀ a b c : ℕ, f a b c = f a b 1
@[search] axiom f_2_2 : ∀ a b c : ℕ, f a b c = f a b 2
@[search] axiom g_0_0 : ∀ a b c : ℕ, g a b c = g 0 b c
@[search] axiom g_0_1 : ∀ a b c : ℕ, g a b c = g 1 b c 
@[search] axiom g_0_2 : ∀ a b c : ℕ, g a b c = g 2 b c 
@[search] axiom g_1_0 : ∀ a b c : ℕ, g a b c = g a 0 c 
@[search] axiom g_1_1 : ∀ a b c : ℕ, g a b c = g a 1 c 
@[search] axiom g_1_2 : ∀ a b c : ℕ, g a b c = g a 2 c 
@[search] axiom g_2_0 : ∀ a b c : ℕ, g a b c = g a b 0
@[search] axiom g_2_1 : ∀ a b c : ℕ, g a b c = g a b 1
@[search] axiom g_2_2 : ∀ a b c : ℕ, g a b c = g a b 2
@[search] axiom f_g : f 0 1 2 = g 2 0 1

lemma test : f 0 0 0 = g 0 0 0 := by rewrite_search_using `search {trace := tt}

end tidy.rewrite_search.examples