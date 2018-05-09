{-# LANGUAGE GeneralizedNewtypeDeriving, TypeOperators #-}
module Analysis.Abstract.Dead
( Dead(..)
, revivingTerms
, killingModules
, providingDeadSet
) where

import Control.Abstract.Evaluator
import Data.Abstract.Module
import Data.Semigroup.Reducer as Reducer
import Data.Semilattice.Lower
import Data.Set (delete)
import Prologue

-- | A set of “dead” (unreachable) terms.
newtype Dead term = Dead { unDead :: Set term }
  deriving (Eq, Foldable, Lower, Monoid, Ord, Semigroup, Show)

deriving instance Ord term => Reducer term (Dead term)

-- | Update the current 'Dead' set.
killAll :: Member (State (Dead term)) effects => Dead term -> Evaluator location value effects ()
killAll = raise . put

-- | Revive a single term, removing it from the current 'Dead' set.
revive :: (Member (State (Dead term)) effects, Ord term) => term -> Evaluator location value effects ()
revive t = raise (modify (Dead . delete t . unDead))

-- | Compute the set of all subterms recursively.
subterms :: (Ord term, Recursive term, Foldable (Base term)) => term -> Dead term
subterms term = term `cons` para (foldMap (uncurry cons)) term


revivingTerms :: ( Corecursive term
                 , Member (State (Dead term)) effects
                 , Ord term
                 )
              => SubtermAlgebra (Base term) term (Evaluator location value effects a)
              -> SubtermAlgebra (Base term) term (Evaluator location value effects a)
revivingTerms recur term = revive (embedSubterm term) *> recur term

killingModules :: ( Foldable (Base term)
                  , Member (State (Dead term)) effects
                  , Ord term
                  , Recursive term
                  )
               => SubtermAlgebra Module term (Evaluator location value effects a)
               -> SubtermAlgebra Module term (Evaluator location value effects a)
killingModules recur m = killAll (subterms (subterm (moduleBody m))) *> recur m

providingDeadSet :: Evaluator location value (State (Dead term) ': effects) a -> Evaluator location value effects (a, Dead term)
providingDeadSet = runState lowerBound
