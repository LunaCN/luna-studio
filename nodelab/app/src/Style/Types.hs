module Style.Types where

import Utils.PreludePlus
import Data.Aeson (ToJSON)

data Color   = Color { _r :: Double
                     , _g :: Double
                     , _b :: Double
                     , _a :: Double
                     } deriving (Show, Eq, Generic)

instance ToJSON Color

data Padding = Padding { _top    :: Double
                       , _right  :: Double
                       , _bottom :: Double
                       , _left   :: Double
                       } deriving (Show, Eq, Generic)

instance Default Padding where
    def = Padding 0.0 0.0 0.0 0.0


uniformPadding a = Padding a a a a
xyPadding x y    = Padding y x y x
