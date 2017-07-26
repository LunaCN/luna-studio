{-# LANGUAGE TypeFamilies #-}
module LunaStudio.Data.Breadcrumb where

import           Control.DeepSeq      (NFData)
import           Data.Aeson.Types     (FromJSON, FromJSONKey, ToJSON, ToJSONKey)
import           Data.Binary          (Binary)
import           Data.Monoid          (Monoid (..))
import           Data.Semigroup       (Semigroup (..))
import           LunaStudio.Data.Node (NodeId)
import           Prologue             hiding (Monoid, mappend, mempty, (<>))


data BreadcrumbItem = Definition { _nodeId  :: NodeId }
                    | Lambda     { _nodeId  :: NodeId }
                    | Arg        { _nodeId  :: NodeId, _arg :: Int }
                    deriving (Eq, Generic, NFData, Ord, Show)

data Named a = Named { _name       :: Text
                     , _breadcrumb :: a
                     } deriving (Eq, Generic, NFData, Show)

newtype Breadcrumb a = Breadcrumb { _items :: [a] } deriving (Eq, Generic, NFData, Ord, Show)

makeLenses ''BreadcrumbItem
makeLenses ''Breadcrumb
makeLenses ''Named
instance Binary a => Binary (Breadcrumb a)
instance Binary a => Binary (Named a)
instance Binary BreadcrumbItem

instance Monoid (Breadcrumb a) where
    mappend bc1 bc2 = Breadcrumb $ (bc1 ^. items) <> (bc2 ^. items)
    mempty = Breadcrumb def

instance Semigroup (Breadcrumb a) where
    (<>) = mappend

instance Default (Breadcrumb a) where
    def = mempty

containsNode :: Breadcrumb BreadcrumbItem -> NodeId -> Bool
containsNode b nid = any ((nid ==) . view nodeId) $ b ^. items


instance FromJSON a => FromJSONKey (Breadcrumb a)
instance FromJSON a => FromJSON (Breadcrumb a)
instance FromJSON a => FromJSON (Named a)
instance ToJSON a => ToJSONKey (Breadcrumb a)
instance ToJSON a => ToJSON (Breadcrumb a)
instance ToJSON a => ToJSON (Named a)

instance FromJSON BreadcrumbItem
instance FromJSONKey BreadcrumbItem
instance ToJSON BreadcrumbItem
instance ToJSONKey BreadcrumbItem
