---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances  #-}

module Luna.Data.Serialize.Proto.Conversion.NodeDefault where

import qualified Data.Map as Map

import           Flowbox.Control.Error
import           Flowbox.Prelude
import           Flowbox.Tools.Serialize.Proto.Conversion.Basic
import qualified Generated.Proto.Nodedefault.DefaultsMap        as Gen
import qualified Generated.Proto.Nodedefault.DefaultsMap.Entry  as Gen
import qualified Luna.Graph.Node                                as Node
import           Luna.Graph.View.Default.DefaultsMap            (DefaultsMap)
import           Luna.Graph.View.Default.Value                  (Value)
import           Luna.Graph.View.PortDescriptor                 (PortDescriptor)



instance Convert DefaultsMap Gen.DefaultsMap where
    encode = Gen.DefaultsMap . encodeList . Map.toList
    decode (Gen.DefaultsMap items) = Map.fromList <$> decodeList items


instance Convert (PortDescriptor, (Node.ID, Value)) Gen.Entry where
    encode (inPort, (nodeID, value)) = Gen.Entry (encodeListP inPort) (encodePJ nodeID) (encodePJ value)
    decode (Gen.Entry inPort mnodeID mvalue) = do
        nodeID <- mnodeID <?> "Failed to decode DefaultsMap.Entry: 'nodeID' field is missing"
        value  <- mvalue  <?> "Failed to decode DefaultsMap.Entry: 'value' field is missing"
        return (decodeListP inPort, (decodeP nodeID, decodeP value))

