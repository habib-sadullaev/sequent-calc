module ClasByNeed.Operational.FuseIteration

import Control.Monad.State
import ClasByNeed.Identifier
import ClasByNeed.Syntax
import ClasByNeed.Redex
import ClasByNeed.Substitution
import ClasByNeed.Operational.Decompose

%hide Redex.contract
%access public export
%default covering

-- Fuse `iter`, `refocus`, and `contract` into a set of mutually tail-recursive
-- recursive functions.

data Result x a = FinalAnswer x (Term x a) a (MetaContext x a)
                | Stuck x (Force x a) (Demanded x a)
                | CoStuck a (Value x a) (MetaContext x a)

mutual                  
  continue : (Eq a, Alternative m, MonadState (List a) m) =>      
             MetaContext a a -> Decomposition a a -> m (Result a a)
  continue  MEmpty          w                = iter w
  continue (MLet k a c1 x) (Answer y t b k') = continue k (Answer y t b k')
  continue (MLet k a c1 x) (Rdx r k')        = continue k (Rdx r k')
  continue (MLet k a c1 x) (Need y f d)      = 
      if x == y 
        then continue k (Rdx (ForceLet a c1 x d f) k)
        else continue k (Need y f (DLet a c1 x d))
  continue (MLet k a c1 x) (CoNeed b v k')   = continue k (CoNeed b v k')

  refocusCommand : (Eq a, Alternative m, MonadState (List a) m) =>
                   Command a a -> MetaContext a a -> m (Result a a)
  refocusCommand (C t e) k = refocusContext e t k
  
  refocusContext : (Eq a, Alternative m, MonadState (List a) m) =>
                   Context a a -> Term a a -> MetaContext a a -> m (Result a a)
  refocusContext (Mut x c) t k = refocusTermLet t x c k
  refocusContext (CoVal e) t k = refocusTermCoVal t e k
  
  refocusTermLet : (Eq a, Alternative m, MonadState (List a) m) =>
                   Term a a -> a -> Command a a -> MetaContext a a -> m (Result a a)
  refocusTermLet (Mu a c1) x c k = refocusCommand c (MLet k a c1 x)
  refocusTermLet (Val v)   x c k = continue k (Rdx (LetVal v x c) k)
  
  refocusTermCoVal : (Eq a, Alternative m, MonadState (List a) m) =>
                     Term a a -> CoValue a a -> MetaContext a a -> m (Result a a)
  refocusTermCoVal (Mu a c) e k = continue k (Rdx (MuLazy a c e) k)
  refocusTermCoVal (Val v)  e k = refocusCoValue e v k
  
  refocusCoValue : (Eq a, Alternative m, MonadState (List a) m) =>
                   CoValue a a -> Value a a -> MetaContext a a -> m (Result a a)
  refocusCoValue (CoVar a)      v k = continue k (CoNeed a v k)
  refocusCoValue (FLet x f tau) v k = continue k (Rdx (FLetVal v x f tau) k)
  refocusCoValue (Fce f)        v k = refocusValue v f k
  
  refocusValue : (Eq a, Alternative m, MonadState (List a) m) =>
                 Value a a -> Force a a -> MetaContext a a -> m (Result a a)
  refocusValue (Var x)   f k = continue k (Need x f DEmpty)
  refocusValue (Lam x t) f k = refocusForce f x t k
  
  refocusForce : (Eq a, Alternative m, MonadState (List a) m) =>
                 Force a a -> a -> Term a a -> MetaContext a a -> m (Result a a)
  refocusForce (App u e)  x t k = continue k (Rdx (Beta x t u e) k)
  refocusForce (CoFree a) x t k = continue k (Answer x t a k)

  refocus : (Eq a, Alternative m, MonadState (List a) m) =>
            Command a a -> MetaContext a a -> m (Result a a)
  refocus c k = refocusCommand c k
  
  contract : (Eq a, Alternative m, MonadState (List a) m) => 
             Redex a a -> MetaContext a a -> m (Result a a)
  contract (Beta x t u e)       k = 
    do x' <- fresh
       let t' = t /// x := x'
       refocus (C u (Mut x' (C t' (CoVal e)))) k
  contract (LetVal v x c)       k = c //  x := v >>= flip refocus k
  contract (MuLazy a c e)       k = c //* a := e >>= flip refocus k
  contract (FLetVal v x f tau)  k = 
    let c' = fillDemand (fromEnv tau) (C (Val v) (CoVal $ Fce f)) in
    c' //  x := v >>= flip refocus k
  contract (ForceLet a c x d f) k = 
    let tau = fromDemand d in
    refocus (C (Mu a c) (CoVal $ FLet x f tau)) k
  
  iter : (Eq a, Alternative m, MonadState (List a) m) =>
         Decomposition a a -> m (Result a a)
  iter (Answer x t a k) = pure $ FinalAnswer x t a k
  iter (Need x f d)     = pure $ Stuck x f d
  iter (CoNeed a v k)   = pure $ CoStuck a v k
  iter (Rdx r k)        = contract r k

run : (Eq a, Alternative m, MonadState (List a) m) =>
      Command a a -> m (Result a a)
run c = refocus c MEmpty