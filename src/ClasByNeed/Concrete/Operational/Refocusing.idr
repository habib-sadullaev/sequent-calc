module ClasByNeed.Concrete.Operational.Refocusing

import Control.Monad.Syntax
import Control.Monad.State
import ClasByNeed.Concrete.Syntax
import ClasByNeed.Concrete.Redex
import ClasByNeed.Concrete.Result
import ClasByNeed.Concrete.Operational.Decompose

%access public export
%default covering

-- An optimized interpreter that deforests `decomp . recomp k` into an
-- in-place `refocus k`.

total
refocus : Eq x => MetaContext x a -> Command x a -> Decomposition x a
refocus k c = decompCommand c k

iter : (Eq a, Alternative m, MonadState (List a) m) => Decomposition a a -> m (ResultM a a)
iter (Answer x t a k) = pure $ FinalAnswerM x t a k
iter (Need x f d)     = pure $ StuckM x f d
iter (CoNeed a v k)   = pure $ CoStuckM a v k
iter (Rdx r k)        = (iter . refocus k <=< contract) r

run : (Eq a, Alternative m, MonadState (List a) m) => Command a a -> m (ResultM a a)                    
run = iter . refocus MEmpty
    