module LJ.LJQ

import Data.List
import Data.List.Quantifiers
import Subset
import Iter
import Lambda.STLC.Ty
import Lambda.STLC.Term
import LJ.LambdaC

%default total
%access public export

-- TODO add to Data.List.Quantifiers
indexAll : Elem x xs -> All p xs -> p x
indexAll  Here     (p::_  ) = p
indexAll (There e) ( _::ps) = indexAll e ps

mutual
  data Async : List Ty -> Ty -> Type where
    Foc : RSync g a -> Async g a                                     -- ~dereliction
    IL  : RSync g a -> Async (b::g) c -> Elem (a~>b) g -> Async g c  -- generalized application
    HC  : RSync g a -> Async (a::g) b -> Async g b                   -- head cut, explicit substitution
    MC  : Async g a -> Async (a::g) b -> Async g b                   -- mid cut, beta-redex

  -- cut-free RSyncs are values
  data RSync : List Ty -> Ty -> Type where
    Ax  : Elem a g -> RSync g a                     -- variable
    IR  : Async (a::g) b -> RSync g (a~>b)          -- lambda
    FHC : RSync g a -> RSync (a::g) b -> RSync g b  -- focused head cut
    -- no focused mid cut

mutual
  shiftAsync : {auto is : IsSubset g g1} -> Async g a -> Async g1 a
  shiftAsync      (Foc r)     = Foc $ shiftRSync r
  shiftAsync {is} (IL r a el) = IL (shiftRSync r) (shiftAsync {is=Cons2 is} a) (shift is el)
  shiftAsync {is} (HC r a)    = HC (shiftRSync r) (shiftAsync {is=Cons2 is} a)
  shiftAsync {is} (MC r l)    = MC (shiftAsync r) (shiftAsync {is=Cons2 is} l)

  shiftRSync : {auto is : IsSubset g g1} -> RSync g a -> RSync g1 a
  shiftRSync {is} (Ax el)   = Ax $ shift is el
  shiftRSync {is} (IR a)    = IR (shiftAsync {is=Cons2 is} a)
  shiftRSync {is} (FHC r l) = FHC (shiftRSync r) (shiftRSync {is=Cons2 is} l)

mutual
  stepA : Async g a -> Maybe (Async g a)
  stepA (HC   (Ax el    )  t                 ) = Just $ shiftAsync {is=ctr el} t
  stepA (HC a@(IR _     ) (Foc p            )) = Just $ Foc $ FHC a p
  stepA (HC a@(IR u     ) (IL p t  Here     )) = Just $ MC (HC (FHC a p) u) (HC (shiftRSync a) (shiftAsync t))
  stepA (HC a@(IR _     ) (IL p t (There el))) = Just $ IL (FHC a p) (HC (shiftRSync a) (shiftAsync t)) el
  stepA (HC    k           m                 ) = [| HC (stepRS k) (pure m) |] <|> [| HC (pure k) (stepA m) |]

  stepA (MC   (Foc p    )  t                 ) = Just $ HC p t
  stepA (MC   (IL p v el)  t                 ) = Just $ IL p (MC v (shiftAsync t)) el
  stepA (MC    u           k                 ) = [| MC (stepA u) (pure k) |] <|> [| MC (pure u) (stepA k) |]
  stepA  _                                     = Nothing

  stepRS : RSync g a -> Maybe (RSync g a)
  stepRS (FHC   (Ax el)  p             ) = Just $ shiftRSync {is=ctr el} p
  stepRS (FHC a@(IR _)  (Ax  Here     )) = Just a
  stepRS (FHC   (IR _)  (Ax (There el))) = Just $ Ax el
  stepRS (FHC a@(IR _)  (IR t         )) = Just $ IR $ HC (shiftRSync a) (shiftAsync t)
  stepRS (FHC    k       m             ) = [| FHC (stepRS k) (pure m) |] <|> [| FHC (pure k) (stepRS m) |]
  stepRS  _                              = Nothing

-- STLC embedding

mutual
  encodeVal : Val g a -> RSync g a
  encodeVal (Var e) = Ax e
  encodeVal (Lam t) = IR $ encodeTm t

  encodeTm : Tm g a -> Async g a
  encodeTm (V    v                        ) = Foc $ encodeVal v
  encodeTm (Let (App (V (Var e)) (V v)) p ) = IL (encodeVal v) (encodeTm p) e
  encodeTm (Let (App (V (Lam t)) (V v)) p ) = HC (IR $ encodeTm t) (IL (shiftRSync $ encodeVal v) (shiftAsync $ encodeTm p) Here)
  encodeTm (Let (App (V  v     )  n   ) p ) = assert_total $ encodeTm $ Let n $ Let (App (V $ shiftVal v) (V $ Var Here)) (shiftTm p)
  encodeTm (Let (App  m           n   ) p ) = assert_total $ encodeTm $ Let m $ Let (App (V $ Var Here) (shiftTm n)) (shiftTm p)
  encodeTm (Let (Let  m           n   ) p ) = assert_total $ encodeTm $ Let m $ Let n (shiftTm p)
  encodeTm (Let (V    v               ) p ) = HC (encodeVal v) (encodeTm p)
  encodeTm (App  t1                     t2) = assert_total $ encodeTm $ Let (App t1 t2) (V $ Var Here)

encode : Term g a -> Async g a
encode = encodeTm . embedLC

stepIter : Term [] a -> (Nat, Async [] a)
stepIter = iterCount stepA . encode

-- QJAM

mutual
  Env : List Ty -> Type
  Env = All Clos

  data Clos : Ty -> Type where
    Cl : RSync g a -> Env g -> Clos a

data Stack : Ty -> Ty -> Type where
  Mt : Stack a a
  Fun : Clos (a~>b) -> Stack b c -> Stack a c

data State : Ty -> Type where
  S1 : Async g a -> Env g -> Stack a b -> State b
  S2 : RSync g a -> Env g -> RSync d (a~>b) -> Env d -> Stack b c -> State c

initState : Async [] a -> State a
initState a = S1 a [] Mt

step : State b -> Maybe (State b)
step (S1 (Foc p)     e          (Fun (Cl t g) c)) = Just $ S2 p e t g c
step (S1 (IL p t el) e                        c ) = let Cl u f = indexAll el e in
                                                    Just $ S2 p e u f (Fun (Cl (IR t) e) c)
step (S1 (HC p t)    e                        c ) = Just $ S2 p e (IR t) e c
step (S2 (Ax el)     e     t  g               c ) = let Cl u f = indexAll el e in
                                                    Just $ S2 u f t g c
step (S2 (IR u)      e (IR t) g               c ) = Just $ S1 t (Cl (IR u) e :: g) c
step _ = Nothing

runQJAM : Term [] a -> (Nat, State a)
runQJAM = iterCount step . initState . encode
