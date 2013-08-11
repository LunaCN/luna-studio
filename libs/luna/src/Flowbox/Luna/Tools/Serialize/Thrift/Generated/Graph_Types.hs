{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-fields #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}
{-# OPTIONS_GHC -fno-warn-unused-matches #-}

-----------------------------------------------------------------
-- Autogenerated by Thrift Compiler (0.9.0)                      --
--                                                             --
-- DO NOT EDIT UNLESS YOU ARE SURE YOU KNOW WHAT YOU ARE DOING --
-----------------------------------------------------------------

module Graph_Types where
import Prelude ( Bool(..), Enum, Double, String, Maybe(..),
                 Eq, Show, Ord,
                 return, length, IO, fromIntegral, fromEnum, toEnum,
                 (.), (&&), (||), (==), (++), ($), (-) )

import Control.Exception
import Data.ByteString.Lazy
import Data.Hashable
import Data.Int
import Data.Text.Lazy ( Text )
import qualified Data.Text.Lazy as TL
import Data.Typeable ( Typeable )
import qualified Data.HashMap.Strict as Map
import qualified Data.HashSet as Set
import qualified Data.Vector as Vector

import Thrift
import Thrift.Types ()

import Attrs_Types


data DefaultValueType = StringV|IntV  deriving (Show,Eq, Typeable, Ord)
instance Enum DefaultValueType where
  fromEnum t = case t of
    StringV -> 0
    IntV -> 1
  toEnum t = case t of
    0 -> StringV
    1 -> IntV
    _ -> throw ThriftException
instance Hashable DefaultValueType where
  hashWithSalt salt = hashWithSalt salt . fromEnum
data NodeType = Type|Call|Default|New|Inputs|Outputs|Tuple|NTuple  deriving (Show,Eq, Typeable, Ord)
instance Enum NodeType where
  fromEnum t = case t of
    Type -> 0
    Call -> 1
    Default -> 2
    New -> 3
    Inputs -> 4
    Outputs -> 5
    Tuple -> 6
    NTuple -> 7
  toEnum t = case t of
    0 -> Type
    1 -> Call
    2 -> Default
    3 -> New
    4 -> Inputs
    5 -> Outputs
    6 -> Tuple
    7 -> NTuple
    _ -> throw ThriftException
instance Hashable NodeType where
  hashWithSalt salt = hashWithSalt salt . fromEnum
type NodeID = Int32

data DefaultValue = DefaultValue{f_DefaultValue_cls :: Maybe DefaultValueType,f_DefaultValue_i :: Maybe Int32,f_DefaultValue_s :: Maybe Text} deriving (Show,Eq,Typeable)
instance Hashable DefaultValue where
  hashWithSalt salt record = salt   `hashWithSalt` f_DefaultValue_cls record   `hashWithSalt` f_DefaultValue_i record   `hashWithSalt` f_DefaultValue_s record  
write_DefaultValue oprot record = do
  writeStructBegin oprot "DefaultValue"
  case f_DefaultValue_cls record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("cls",T_I32,1)
    writeI32 oprot (fromIntegral $ fromEnum _v)
    writeFieldEnd oprot}
  case f_DefaultValue_i record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("i",T_I32,2)
    writeI32 oprot _v
    writeFieldEnd oprot}
  case f_DefaultValue_s record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("s",T_STRING,3)
    writeString oprot _v
    writeFieldEnd oprot}
  writeFieldStop oprot
  writeStructEnd oprot
read_DefaultValue_fields iprot record = do
  (_,_t3,_id4) <- readFieldBegin iprot
  if _t3 == T_STOP then return record else
    case _id4 of 
      1 -> if _t3 == T_I32 then do
        s <- (do {i <- readI32 iprot; return $ toEnum $ fromIntegral i})
        read_DefaultValue_fields iprot record{f_DefaultValue_cls=Just s}
        else do
          skip iprot _t3
          read_DefaultValue_fields iprot record
      2 -> if _t3 == T_I32 then do
        s <- readI32 iprot
        read_DefaultValue_fields iprot record{f_DefaultValue_i=Just s}
        else do
          skip iprot _t3
          read_DefaultValue_fields iprot record
      3 -> if _t3 == T_STRING then do
        s <- readString iprot
        read_DefaultValue_fields iprot record{f_DefaultValue_s=Just s}
        else do
          skip iprot _t3
          read_DefaultValue_fields iprot record
      _ -> do
        skip iprot _t3
        readFieldEnd iprot
        read_DefaultValue_fields iprot record
read_DefaultValue iprot = do
  _ <- readStructBegin iprot
  record <- read_DefaultValue_fields iprot (DefaultValue{f_DefaultValue_cls=Nothing,f_DefaultValue_i=Nothing,f_DefaultValue_s=Nothing})
  readStructEnd iprot
  return record
data Node = Node{f_Node_cls :: Maybe NodeType,f_Node_name :: Maybe Text,f_Node_nodeID :: Maybe Int32,f_Node_flags :: Maybe Attrs_Types.Flags,f_Node_attrs :: Maybe Attrs_Types.Attributes,f_Node_defVal :: Maybe DefaultValue} deriving (Show,Eq,Typeable)
instance Hashable Node where
  hashWithSalt salt record = salt   `hashWithSalt` f_Node_cls record   `hashWithSalt` f_Node_name record   `hashWithSalt` f_Node_nodeID record   `hashWithSalt` f_Node_flags record   `hashWithSalt` f_Node_attrs record   `hashWithSalt` f_Node_defVal record  
write_Node oprot record = do
  writeStructBegin oprot "Node"
  case f_Node_cls record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("cls",T_I32,1)
    writeI32 oprot (fromIntegral $ fromEnum _v)
    writeFieldEnd oprot}
  case f_Node_name record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("name",T_STRING,2)
    writeString oprot _v
    writeFieldEnd oprot}
  case f_Node_nodeID record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("nodeID",T_I32,3)
    writeI32 oprot _v
    writeFieldEnd oprot}
  case f_Node_flags record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("flags",T_STRUCT,4)
    Attrs_Types.write_Flags oprot _v
    writeFieldEnd oprot}
  case f_Node_attrs record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("attrs",T_STRUCT,5)
    Attrs_Types.write_Attributes oprot _v
    writeFieldEnd oprot}
  case f_Node_defVal record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("defVal",T_STRUCT,6)
    write_DefaultValue oprot _v
    writeFieldEnd oprot}
  writeFieldStop oprot
  writeStructEnd oprot
read_Node_fields iprot record = do
  (_,_t8,_id9) <- readFieldBegin iprot
  if _t8 == T_STOP then return record else
    case _id9 of 
      1 -> if _t8 == T_I32 then do
        s <- (do {i <- readI32 iprot; return $ toEnum $ fromIntegral i})
        read_Node_fields iprot record{f_Node_cls=Just s}
        else do
          skip iprot _t8
          read_Node_fields iprot record
      2 -> if _t8 == T_STRING then do
        s <- readString iprot
        read_Node_fields iprot record{f_Node_name=Just s}
        else do
          skip iprot _t8
          read_Node_fields iprot record
      3 -> if _t8 == T_I32 then do
        s <- readI32 iprot
        read_Node_fields iprot record{f_Node_nodeID=Just s}
        else do
          skip iprot _t8
          read_Node_fields iprot record
      4 -> if _t8 == T_STRUCT then do
        s <- (read_Flags iprot)
        read_Node_fields iprot record{f_Node_flags=Just s}
        else do
          skip iprot _t8
          read_Node_fields iprot record
      5 -> if _t8 == T_STRUCT then do
        s <- (read_Attributes iprot)
        read_Node_fields iprot record{f_Node_attrs=Just s}
        else do
          skip iprot _t8
          read_Node_fields iprot record
      6 -> if _t8 == T_STRUCT then do
        s <- (read_DefaultValue iprot)
        read_Node_fields iprot record{f_Node_defVal=Just s}
        else do
          skip iprot _t8
          read_Node_fields iprot record
      _ -> do
        skip iprot _t8
        readFieldEnd iprot
        read_Node_fields iprot record
read_Node iprot = do
  _ <- readStructBegin iprot
  record <- read_Node_fields iprot (Node{f_Node_cls=Nothing,f_Node_name=Nothing,f_Node_nodeID=Nothing,f_Node_flags=Nothing,f_Node_attrs=Nothing,f_Node_defVal=Nothing})
  readStructEnd iprot
  return record
data Edge = Edge{f_Edge_portDst :: Maybe Int32,f_Edge_nodeSrc :: Maybe Int32,f_Edge_nodeDst :: Maybe Int32} deriving (Show,Eq,Typeable)
instance Hashable Edge where
  hashWithSalt salt record = salt   `hashWithSalt` f_Edge_portDst record   `hashWithSalt` f_Edge_nodeSrc record   `hashWithSalt` f_Edge_nodeDst record  
write_Edge oprot record = do
  writeStructBegin oprot "Edge"
  case f_Edge_portDst record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("portDst",T_I32,2)
    writeI32 oprot _v
    writeFieldEnd oprot}
  case f_Edge_nodeSrc record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("nodeSrc",T_I32,3)
    writeI32 oprot _v
    writeFieldEnd oprot}
  case f_Edge_nodeDst record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("nodeDst",T_I32,4)
    writeI32 oprot _v
    writeFieldEnd oprot}
  writeFieldStop oprot
  writeStructEnd oprot
read_Edge_fields iprot record = do
  (_,_t13,_id14) <- readFieldBegin iprot
  if _t13 == T_STOP then return record else
    case _id14 of 
      2 -> if _t13 == T_I32 then do
        s <- readI32 iprot
        read_Edge_fields iprot record{f_Edge_portDst=Just s}
        else do
          skip iprot _t13
          read_Edge_fields iprot record
      3 -> if _t13 == T_I32 then do
        s <- readI32 iprot
        read_Edge_fields iprot record{f_Edge_nodeSrc=Just s}
        else do
          skip iprot _t13
          read_Edge_fields iprot record
      4 -> if _t13 == T_I32 then do
        s <- readI32 iprot
        read_Edge_fields iprot record{f_Edge_nodeDst=Just s}
        else do
          skip iprot _t13
          read_Edge_fields iprot record
      _ -> do
        skip iprot _t13
        readFieldEnd iprot
        read_Edge_fields iprot record
read_Edge iprot = do
  _ <- readStructBegin iprot
  record <- read_Edge_fields iprot (Edge{f_Edge_portDst=Nothing,f_Edge_nodeSrc=Nothing,f_Edge_nodeDst=Nothing})
  readStructEnd iprot
  return record
data Graph = Graph{f_Graph_nodes :: Maybe (Map.HashMap Int32 Node),f_Graph_edges :: Maybe (Vector.Vector Edge)} deriving (Show,Eq,Typeable)
instance Hashable Graph where
  hashWithSalt salt record = salt   `hashWithSalt` f_Graph_nodes record   `hashWithSalt` f_Graph_edges record  
write_Graph oprot record = do
  writeStructBegin oprot "Graph"
  case f_Graph_nodes record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("nodes",T_MAP,1)
    (let {f [] = return (); f ((_kiter17,_viter18):t) = do {do {writeI32 oprot _kiter17;write_Node oprot _viter18};f t}} in do {writeMapBegin oprot (T_I32,T_STRUCT,fromIntegral $ Map.size _v); f (Map.toList _v);writeMapEnd oprot})
    writeFieldEnd oprot}
  case f_Graph_edges record of {Nothing -> return (); Just _v -> do
    writeFieldBegin oprot ("edges",T_LIST,2)
    (let f = Vector.mapM_ (\_viter19 -> write_Edge oprot _viter19) in do {writeListBegin oprot (T_STRUCT,fromIntegral $ Vector.length _v); f _v;writeListEnd oprot})
    writeFieldEnd oprot}
  writeFieldStop oprot
  writeStructEnd oprot
read_Graph_fields iprot record = do
  (_,_t21,_id22) <- readFieldBegin iprot
  if _t21 == T_STOP then return record else
    case _id22 of 
      1 -> if _t21 == T_MAP then do
        s <- (let {f 0 = return []; f n = do {k <- readI32 iprot; v <- (read_Node iprot);r <- f (n-1); return $ (k,v):r}} in do {(_ktype24,_vtype25,_size23) <- readMapBegin iprot; l <- f _size23; return $ Map.fromList l})
        read_Graph_fields iprot record{f_Graph_nodes=Just s}
        else do
          skip iprot _t21
          read_Graph_fields iprot record
      2 -> if _t21 == T_LIST then do
        s <- (let f n = Vector.replicateM (fromIntegral n) ((read_Edge iprot)) in do {(_etype31,_size28) <- readListBegin iprot; f _size28})
        read_Graph_fields iprot record{f_Graph_edges=Just s}
        else do
          skip iprot _t21
          read_Graph_fields iprot record
      _ -> do
        skip iprot _t21
        readFieldEnd iprot
        read_Graph_fields iprot record
read_Graph iprot = do
  _ <- readStructBegin iprot
  record <- read_Graph_fields iprot (Graph{f_Graph_nodes=Nothing,f_Graph_edges=Nothing})
  readStructEnd iprot
  return record
