module Lambda.Untyped.CEK

import Lambda.Untyped.Term

%default total
%access public export

mutual
  Env : Type 
  Env = List Clos

  data Clos = Cl Term Env

data Frame = Fun Term Env 
           | Arg Clos

Stack : Type
Stack = List Frame

data State = L Term Env Stack
           | R Clos Stack

step : State -> Maybe State
step (L (Var  Z)    (v::_)             s ) = Just $ R  v                                  s
step (L (Var (S n)) (_::e)             s ) = Just $ L (Var n)     e                       s
step (L (Lam t)         e              s ) = Just $ R (Cl (Lam t) e)                      s
step (L (App t u)       e              s ) = Just $ L u           e             (Fun t e::s)
step (R (Cl (Lam t)     e) (Fun t1 e1::s)) = Just $ L t1          e1 (Arg (Cl (Lam t) e)::s)
step (R (Cl (Lam t)     e) (    Arg v::s)) = Just $ L t       (v::e)                      s
step  _                                    = Nothing

stepIter : State -> (Nat, Maybe State)
stepIter s = loop Z s
  where
    loop : Nat -> State -> (Nat, Maybe State)
    loop n s1 with (step s1)
      | Nothing = (n, Just s1)
      | Just s2 = assert_total $ loop (S n) s2

runCEK : Term -> (Nat, Maybe State)
runCEK t = stepIter $ L t [] []

test0 : runCEK Term0 = (11, Just (R (Cl (Lam (Var 0)) []) []))
test0 = Refl

test1 : runCEK Term1 = (11, Just (R (Cl (Lam (Var 0)) []) []))
test1 = Refl

test2 : runCEK Term2 = (11, Just (R (Cl (Lam (Var 0)) []) []))
test2 = Refl
