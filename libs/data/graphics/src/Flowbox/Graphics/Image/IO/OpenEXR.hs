---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
module Flowbox.Graphics.Image.IO.OpenEXR (
      readFromEXR
    ) where

import qualified Data.Array.Accelerate    as A
import qualified Data.Array.Accelerate.IO as A
import           Data.Char                (toLower)
import qualified Data.Vector.Storable     as SV
import           Control.Monad            (forM)
import           GHC.Float                as GHC (float2Double)

import           Flowbox.Codec.EXR              hiding (name)
import           Flowbox.Graphics.Image.Channel
import           Flowbox.Graphics.Image.Image   (Image)
import qualified Flowbox.Graphics.Image.Image   as Image
import           Flowbox.Graphics.Image.View    (View)
import qualified Flowbox.Graphics.Image.View    as View
import           Flowbox.Math.Matrix            as M hiding (any, (++))
import           Flowbox.Prelude



readFromEXR :: FilePath -> IO (Maybe Image)
readFromEXR path = do
    exr <- openEXRFile path
    case exr of
        Just file -> do
            partsNum <- getParts file
            parts <- forM [0..partsNum-1] $ readEXRPart file

            return $ makeImage parts
        _         -> return Nothing


readEXRPart :: EXRFile -> Int -> IO View
readEXRPart exr part = do
    channelsNames <- getChannels exr part
    channels <- forM channelsNames $ \name -> do
        floatArray <- readScanlineChannelA exr part name
        let doubleArray = convertToDouble floatArray
        return $ ChannelFloat (convertToLunaName name) (FlatData $ Raw doubleArray)

    let newChannels = addAlphaIfAbsent channels

    partName <- maybe "rgba" id <$> getPartName exr part
    return $ makeView partName newChannels

addAlphaIfAbsent :: [Channel] -> [Channel]
addAlphaIfAbsent channels@(x:_) = if alphaPresent then channels else alpha : channels
    where alphaPresent = any (\chan -> name chan == "rgba.a") channels

          ChannelFloat _ (FlatData matrix) = x

          alpha = ChannelFloat "rgba.a" $ FlatData $ M.fill (M.shape matrix) 1.0

convertToLunaName :: String -> String
convertToLunaName [name] = "rgba." ++ [toLower name]
convertToLunaName name   = name

makeView :: String -> [Channel] -> View
makeView name channels = foldr View.append (View.empty name) channels

makeImage :: [View] -> Maybe Image
makeImage (x:xs) = Just $ foldr Image.insert (Image.singleton x) xs
makeImage _      = Nothing

convertToDouble :: A.Shape sh => A.Array sh Float -> A.Array sh Double
convertToDouble matrix = doubleMatrix
    where ((), floatVector) = A.toVectors matrix
          doubleVector = SV.map GHC.float2Double floatVector
          doubleMatrix = A.fromVectors (A.arrayShape matrix) ((), doubleVector)
