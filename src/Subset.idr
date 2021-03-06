module Subset

import Data.List
import Data.List.Elem

--%access public export
%default total

public export
Subset : List a -> List a -> Type
Subset xs ys = {0 x : a} -> Elem x xs -> Elem x ys

export
ext : Subset g d -> Subset (b::g) (b::d)
ext _  Here      = Here
ext r (There el) = There (r el)

contract : Elem y d -> Subset (y::d) d
contract el  Here     = el
contract _  (There s) = s

permute : Subset (a::b::g) (b::a::g)
permute  Here              = There Here
permute (There  Here     ) = Here
permute (There (There el)) = There (There el)

public export
data IsSubset : List a -> List a -> Type where
  Id    :                      IsSubset           l            l
  ConsR : IsSubset     l  m -> IsSubset           l  (      a::m)
  Cons2 : IsSubset     l  m -> IsSubset (      a::l) (      a::m)
  Swap  : IsSubset     l  m -> IsSubset (   a::b::l) (   b::a::m)
  Rot   : IsSubset     l  m -> IsSubset (a::b::c::l) (c::a::b::m)
  CtrH  :                      IsSubset (   a::a::l) (      a::l)
  CtrT  : IsSubset (a::l) m -> IsSubset (   a::b::l) (      b::m)

ctr : Elem a l -> IsSubset (a :: l) l
ctr  Here      = CtrH
ctr (There el) = CtrT $ ctr el

public export
shift : IsSubset l m -> Subset l m
shift  Id        el                        = el
shift (ConsR s)  el                        = There $ shift s el
shift (Cons2 s)  Here                      = Here
shift (Cons2 s) (There  el)                = There $ shift s el
shift (Swap s)   Here                      = There Here
shift (Swap s)  (There  Here)              = Here
shift (Swap s)  (There (There el))         = There $ There $ shift s el
shift (Rot s)    Here                      = There Here
shift (Rot s)   (There  Here)              = There $ There Here
shift (Rot s)   (There (There  Here))      = Here
shift (Rot s)   (There (There (There el))) = There $ There $ There $ shift s el
shift  CtrH      Here                      = Here
shift  CtrH     (There el)                 = el
shift (CtrT s)   Here                      = There $ shift s Here
shift (CtrT s)  (There Here)               = Here
shift (CtrT s)  (There (There el))         = There $ shift s (There el)

-- partial subsets

SubsetM : (g : List a) -> (d : List a) -> Type
SubsetM {a} g d = {0 x : a} -> Elem x g -> Maybe (Elem x d)

extM : SubsetM g d -> SubsetM (b::g) (b::d)
extM _  Here      = Just Here
extM r (There el) = There <$> r el

contractM : SubsetM (y::d) d
contractM  Here     = Nothing
contractM (There s) = Just s
