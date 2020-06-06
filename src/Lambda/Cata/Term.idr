module Lambda.Cata.Term

import Lambda.Cata.Ty
import Data.Fin
import Data.List
--import Data.Vect
import Data.List.Elem

--%access public export
%default total

-- isorecursive

public export
data Term : List (Ty n) -> Ty n -> Type where
  TT   : Term g U
  Var  : Elem a g -> Term g a
  Lam  : Term (a::g) b -> Term g (a~>b)
  App  : {a : Ty 0} -> Term g (a~>b) -> Term g a -> Term g b
  Pair : Term g a -> Term g b -> Term g (Prod a b)
  Fst  : Term g (Prod a b) -> Term g a
  Snd  : Term g (Prod a b) -> Term g b
  Inl  : Term g a -> Term g (Sum a b)
  Inr  : Term g b -> Term g (Sum a b)
  Case : {a, b : Ty n} -> Term g (Sum a b) -> Term (a::g) c -> Term (b::g) c -> Term g c
  In   : Term g (subst1T f (Mu f)) -> Term g (Mu f)
  Cata : Term g (subst1T f a ~> a) -> Term g (Mu f ~> a)

export
NAT : Ty n
NAT = Mu $ Sum U (TVar FZ)

export
zero : Term g NAT
zero = In $ Inl TT

export
succ : Term {n=0} g (NAT ~> NAT)
succ = Lam $ In $ Inr $ Var Here

export
add : Term {n=0} g (NAT~>NAT~>NAT)
add = Lam $ Cata $ Lam $ Case (Var Here) (Var $ There $ There Here) (In $ Inr $ Var Here)

LIST : Ty (S n) -> Ty n
LIST t = Mu $ Sum U (Prod t (TVar FZ))

l123 : Term g (LIST NAT)
l123 = In $ Inr $ Pair (In $ Inr $ In $ Inl TT) $
       In $ Inr $ Pair (In $ Inr $ In $ Inr $ In $ Inl TT) $
       In $ Inr $ Pair (In $ Inr $ In $ Inr $ In $ Inr $ In $ Inl TT) $
       In $ Inl TT

-- interleaving
FIN : Ty 0
FIN = Mu $ Mu $ Sum U (Prod (TVar $ FS FZ) (TVar FZ))

VOID : Ty n
VOID = Mu $ TVar FZ

exfalso : Term {n=0} g (VOID ~> a)
exfalso = Cata $ Lam $ Var Here