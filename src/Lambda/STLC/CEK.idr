module Lambda.STLC.CEK

import Data.List
import Data.List.Quantifiers
import Iter
import Lambda.STLC.Ty
import Lambda.STLC.Term

%default total
%access public export

-- left-to-right call-by-value

mutual
  Env : List Ty -> Type
  Env = All Clos

  data Clos : Ty -> Type where
    Cl : Term g a -> Env g -> Clos a

data Stack : Ty -> Ty -> Type where
  Mt  : Stack a a
  Arg : Clos a -> Stack b c -> Stack (a~>b) c
  Fun : Clos (a~>b) -> Stack b c -> Stack a c

record State (b : Ty) where
  constructor St
  tm  : Term g a
  env : Env g
  stk : Stack a b

step : State b -> Maybe (State b)
step (St (Var  Here)      (Cl t e::_)                       s ) = Just $ St  t                e                 s
step (St (Var (There el))      (_::e)                       s ) = Just $ St (Var el)          e                 s
step (St (App t u)                 e                        s ) = Just $ St  t                e   (Arg (Cl u e) s)
step (St  t                        e  (Fun (Cl (Lam t1) e1) s)) = Just $ St  t1      (Cl t e::e1)               s
step (St  t                        e        (Arg (Cl t1 e1) s)) = Just $ St  t1               e1  (Fun (Cl t e) s)
step  _                                                         = Nothing

runCEK : Term [] a -> (Nat, State a)
runCEK t = iterCount step $ St t [] Mt

private
test1 : runCEK TestTm1 = (8, St ResultTm [] Mt)
test1 = Refl

private
test2 : runCEK TestTm2 = (8, St ResultTm [] Mt)
test2 = Refl
