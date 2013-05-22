{-# LANGUAGE TypeFamilies, FlexibleInstances, StandaloneDeriving #-}
module IdeSession.Strict.Container
  ( StrictContainer(..)
  , Strict(..)
    -- * For convenience, we export the names of the lazy types too
  , Maybe
  , Map
  , IntMap
  , Trie
  ) where

import Data.IntMap (IntMap)
import qualified Data.IntMap as IntMap
import Data.Map (Map)
import qualified Data.Map as Map
import qualified Data.List as List
import Control.Applicative ((<$>))
import Data.Trie (Trie)
import Data.Foldable as Foldable
import Data.Binary (Binary(..))

class StrictContainer t where
  data Strict (t :: * -> *) :: * -> *
  force   :: t a -> Strict t a
  project :: Strict t a -> t a

{------------------------------------------------------------------------------
  IntMap
------------------------------------------------------------------------------}

instance StrictContainer IntMap where
  newtype Strict IntMap v = StrictIntMap { toLazyIntMap :: IntMap v }
    deriving Show

  force m = IntMap.foldl' (flip seq) () m `seq` StrictIntMap m
  project = toLazyIntMap

instance Binary v => Binary (Strict IntMap v) where
  put = put . IntMap.toList . toLazyIntMap
  get = (force . IntMap.fromList) <$> get

{------------------------------------------------------------------------------
  Lists
------------------------------------------------------------------------------}

instance StrictContainer [] where
  newtype Strict [] a = StrictList { toLazyList :: [a] }
    deriving (Show, Eq)

  force m = List.foldl' (flip seq) () m `seq` StrictList m
  project = toLazyList

-- TODO: we can do better than this if we cache the length of the list
instance Binary a => Binary (Strict [] a) where
  put = put . toLazyList
  get = force <$> get

{------------------------------------------------------------------------------
  Map
------------------------------------------------------------------------------}

instance StrictContainer (Map k) where
  newtype Strict (Map k) v = StrictMap { toLazyMap :: Map k v }
    deriving (Show)

  force m = Map.foldl' (flip seq) () m `seq` StrictMap m
  project = toLazyMap

instance (Ord k, Binary k, Binary v) => Binary (Strict (Map k) v) where
  put = put . Map.toList . toLazyMap
  get = (force . Map.fromList) <$> get

{------------------------------------------------------------------------------
  Maybe
------------------------------------------------------------------------------}

instance StrictContainer Maybe where
  newtype Strict Maybe a = StrictMaybe { toLazyMaybe :: Maybe a }
    deriving (Show)

  force Nothing  = StrictMaybe Nothing
  force (Just x) = x `seq` StrictMaybe $ Just x
  project = toLazyMaybe

instance Binary a => Binary (Strict Maybe a) where
  put = put . toLazyMaybe
  get = force <$> get

deriving instance Eq a => Eq (Strict Maybe a)

instance Functor (Strict Maybe) where
  fmap f = force . fmap f . toLazyMaybe

{------------------------------------------------------------------------------
  Trie
------------------------------------------------------------------------------}

instance StrictContainer Trie where
  newtype Strict Trie a = StrictTrie { toLazyTrie :: Trie a }
    deriving (Show)

  force m = Foldable.foldl (flip seq) () m `seq` StrictTrie m
  project = toLazyTrie
