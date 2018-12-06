module ClasByNeed.Operational.EliminateDeadCode

import Control.Monad.State
import ClasByNeed.Identifier
import ClasByNeed.Syntax
import ClasByNeed.Redex
import ClasByNeed.Substitution
import ClasByNeed.Operational.Decompose

%hide Redex.contract
%access public export
%default covering

-- Deforest decomposition entirely and eliminate dead functions and cases from 
-- the code.

data Result x a = FinalAnswer x (Term x a) a (MetaContext x a)
                | Stuck x (Force x a) (Demanded x a)
                | CoStuck a (Value x a) (MetaContext x a)

mutual
  refocusCommand : (Eq a, Alternative m, MonadState (List a) m) =>
                   Command a a -> MetaContext a a -> m (Result a a)
  refocusCommand (C t e) k = refocusContext e t k
  
  refocusContext : (Eq a, Alternative m, MonadState (List a) m) =>
                   Context a a -> Term a a -> MetaContext a a -> m (Result a a)
  refocusContext (Mut x c) t k  = refocusTermLet t x c k
  refocusContext (CoVal e) t k  = refocusTermCoVal t e k

  refocusTermLet : (Eq a, Alternative m, MonadState (List a) m) =>
                   Term a a -> a -> Command a a -> MetaContext a a -> m (Result a a)
  refocusTermLet (Mu a c1) x c k = refocusCommand c (MLet k a c1 x)
  refocusTermLet (Val v)   x c k = c // x := v >>= flip refocus k
  
  refocusTermCoVal : (Eq a, Alternative m, MonadState (List a) m) =>
                     Term a a -> CoValue a a -> MetaContext a a -> m (Result a a)
  refocusTermCoVal (Mu a c) e k = c //* a := e >>= flip refocus k
  refocusTermCoVal (Val v)  e k = refocusCoValue e v k
  
  refocusCoValue : (Eq a, Alternative m, MonadState (List a) m) =>
                   CoValue a a -> Value a a -> MetaContext a a -> m (Result a a)
  refocusCoValue (CoVar a)      v k = pure $ CoStuck a v k
  refocusCoValue (FLet x f tau) v k = 
    let c' = fillDemand (fromEnv tau) (C (Val v) (CoVal $ Fce f)) in
    c' // x := v >>= flip refocus k
  refocusCoValue (Fce f)        v k = refocusValue v f k
  
  refocusValue : (Eq a, Alternative m, MonadState (List a) m) =>
                 Value a a -> Force a a -> MetaContext a a -> m (Result a a)
  refocusValue (Var x)   f k = continue k x f DEmpty
  refocusValue (Lam x t) f k = refocusForce f x t k
  
  refocusForce : (Eq a, Alternative m, MonadState (List a) m) =>
                 Force a a -> a -> Term a a -> MetaContext a a -> m (Result a a)
  refocusForce (App u e)  x t k  = 
    do x' <- fresh
       let t' = t /// x := x'
       refocus (C u (Mut x' (C t' (CoVal e)))) k
  refocusForce (CoFree a) x t k  = pure $ FinalAnswer x t a k
  
  refocus : (Eq a, Alternative m, MonadState (List a) m) =>
            Command a a -> MetaContext a a -> m (Result a a)
  refocus c k = refocusCommand c k

  continue : (Eq a, Alternative m, MonadState (List a) m) =>          
             MetaContext a a -> a -> Force a a -> Demanded a a -> m (Result a a)  
  continue  MEmpty         y f d = pure $ Stuck y f d
  continue (MLet k a c1 x) y f d = 
    if x == y 
      then
        let tau = fromDemand d in
        refocus (C (Mu a c1) (CoVal $ FLet x f tau)) k
      else continue k y f (DLet a c1 x d)
        
run : (Eq a, Alternative m, MonadState (List a) m) =>
      Command a a -> m (Result a a)
run c = refocus c MEmpty
