
---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts #-}

module Flowbox.Batch.Server.Processor where

import qualified Control.Concurrent              as Concurrent
import           Control.Concurrent.MVar         (MVar)
import qualified Control.Concurrent.MVar         as MVar
import           Data.ByteString.Lazy            (ByteString)
import qualified Data.Map                        as Map
import           Network.Socket                  (Socket)
import           Text.ProtocolBuffers            (Int32)
import qualified Text.ProtocolBuffers            as Proto
import qualified Text.ProtocolBuffers.Extensions as Extensions

import           Flowbox.Batch.Server.Handler.Handler           (Handler)
import qualified Flowbox.Batch.Server.Handler.Handler           as Handler
import qualified Flowbox.Batch.Server.Transport.TCP.TCP         as TCP
import           Flowbox.Control.Error
import           Flowbox.Prelude                                hiding (error)
import           Flowbox.System.Log.Logger
import           Flowbox.Tools.Serialize.Proto.Conversion.Basic
import           Generated.Proto.Batch.Exception                (Exception (Exception))
import qualified Generated.Proto.Batch.Exception                as Exception
import qualified Generated.Proto.Batch.Request                  as Request
import qualified Generated.Proto.Batch.Request.Method           as Method
import           Generated.Proto.Batch.Response                 (Response (Response))
import qualified Generated.Proto.Batch.Response.Type            as ResponseType

import qualified Generated.Proto.Batch.AST.AddClass.Args                    as AddClass
import qualified Generated.Proto.Batch.AST.AddClass.Result                  as AddClass
import qualified Generated.Proto.Batch.AST.AddFunction.Args                 as AddFunction
import qualified Generated.Proto.Batch.AST.AddFunction.Result               as AddFunction
import qualified Generated.Proto.Batch.AST.AddModule.Args                   as AddModule
import qualified Generated.Proto.Batch.AST.AddModule.Result                 as AddModule
import qualified Generated.Proto.Batch.AST.Definitions.Args                 as Definitions
import qualified Generated.Proto.Batch.AST.Definitions.Result               as Definitions
import qualified Generated.Proto.Batch.AST.Remove.Args                      as Remove
import qualified Generated.Proto.Batch.AST.Remove.Result                    as Remove
import qualified Generated.Proto.Batch.AST.ResolveDefinition.Args           as ResolveDefinition
import qualified Generated.Proto.Batch.AST.ResolveDefinition.Result         as ResolveDefinition
import qualified Generated.Proto.Batch.AST.UpdateDataClasses.Args           as UpdateDataClasses
import qualified Generated.Proto.Batch.AST.UpdateDataClasses.Result         as UpdateDataClasses
import qualified Generated.Proto.Batch.AST.UpdateDataCls.Args               as UpdateDataCls
import qualified Generated.Proto.Batch.AST.UpdateDataCls.Result             as UpdateDataCls
import qualified Generated.Proto.Batch.AST.UpdateDataCons.Args              as UpdateDataCons
import qualified Generated.Proto.Batch.AST.UpdateDataCons.Result            as UpdateDataCons
import qualified Generated.Proto.Batch.AST.UpdateDataMethods.Args           as UpdateDataMethods
import qualified Generated.Proto.Batch.AST.UpdateDataMethods.Result         as UpdateDataMethods
import qualified Generated.Proto.Batch.AST.UpdateFunctionInputs.Args        as UpdateFunctionInputs
import qualified Generated.Proto.Batch.AST.UpdateFunctionInputs.Result      as UpdateFunctionInputs
import qualified Generated.Proto.Batch.AST.UpdateFunctionName.Args          as UpdateFunctionName
import qualified Generated.Proto.Batch.AST.UpdateFunctionName.Result        as UpdateFunctionName
import qualified Generated.Proto.Batch.AST.UpdateFunctionOutput.Args        as UpdateFunctionOutput
import qualified Generated.Proto.Batch.AST.UpdateFunctionOutput.Result      as UpdateFunctionOutput
import qualified Generated.Proto.Batch.AST.UpdateFunctionPath.Args          as UpdateFunctionPath
import qualified Generated.Proto.Batch.AST.UpdateFunctionPath.Result        as UpdateFunctionPath
import qualified Generated.Proto.Batch.AST.UpdateModuleCls.Args             as UpdateModuleCls
import qualified Generated.Proto.Batch.AST.UpdateModuleCls.Result           as UpdateModuleCls
import qualified Generated.Proto.Batch.AST.UpdateModuleFields.Args          as UpdateModuleFields
import qualified Generated.Proto.Batch.AST.UpdateModuleFields.Result        as UpdateModuleFields
import qualified Generated.Proto.Batch.AST.UpdateModuleImports.Args         as UpdateModuleImports
import qualified Generated.Proto.Batch.AST.UpdateModuleImports.Result       as UpdateModuleImports
import qualified Generated.Proto.Batch.FileSystem.CP.Args                   as CP
import qualified Generated.Proto.Batch.FileSystem.CP.Result                 as CP
import qualified Generated.Proto.Batch.FileSystem.LS.Args                   as LS
import qualified Generated.Proto.Batch.FileSystem.LS.Result                 as LS
import qualified Generated.Proto.Batch.FileSystem.MkDir.Args                as MkDir
import qualified Generated.Proto.Batch.FileSystem.MkDir.Result              as MkDir
import qualified Generated.Proto.Batch.FileSystem.MV.Args                   as MV
import qualified Generated.Proto.Batch.FileSystem.MV.Result                 as MV
import qualified Generated.Proto.Batch.FileSystem.RM.Args                   as RM
import qualified Generated.Proto.Batch.FileSystem.RM.Result                 as RM
import qualified Generated.Proto.Batch.FileSystem.Stat.Args                 as Stat
import qualified Generated.Proto.Batch.FileSystem.Stat.Result               as Stat
import qualified Generated.Proto.Batch.FileSystem.Touch.Args                as Touch
import qualified Generated.Proto.Batch.FileSystem.Touch.Result              as Touch
import qualified Generated.Proto.Batch.Graph.AddNode.Args                   as AddNode
import qualified Generated.Proto.Batch.Graph.AddNode.Result                 as AddNode
import qualified Generated.Proto.Batch.Graph.Connect.Args                   as Connect
import qualified Generated.Proto.Batch.Graph.Connect.Result                 as Connect
import qualified Generated.Proto.Batch.Graph.Disconnect.Args                as Disconnect
import qualified Generated.Proto.Batch.Graph.Disconnect.Result              as Disconnect
import qualified Generated.Proto.Batch.Graph.NodeByID.Args                  as NodeByID
import qualified Generated.Proto.Batch.Graph.NodeByID.Result                as NodeByID
import qualified Generated.Proto.Batch.Graph.NodesGraph.Args                as NodesGraph
import qualified Generated.Proto.Batch.Graph.NodesGraph.Result              as NodesGraph
import qualified Generated.Proto.Batch.Graph.RemoveNode.Args                as RemoveNode
import qualified Generated.Proto.Batch.Graph.RemoveNode.Result              as RemoveNode
import qualified Generated.Proto.Batch.Graph.UpdateNode.Args                as UpdateNode
import qualified Generated.Proto.Batch.Graph.UpdateNode.Result              as UpdateNode
import qualified Generated.Proto.Batch.Library.BuildLibrary.Args            as BuildLibrary
import qualified Generated.Proto.Batch.Library.BuildLibrary.Result          as BuildLibrary
import qualified Generated.Proto.Batch.Library.CreateLibrary.Args           as CreateLibrary
import qualified Generated.Proto.Batch.Library.CreateLibrary.Result         as CreateLibrary
import qualified Generated.Proto.Batch.Library.Libraries.Args               as Libraries
import qualified Generated.Proto.Batch.Library.Libraries.Result             as Libraries
import qualified Generated.Proto.Batch.Library.LibraryByID.Args             as LibraryByID
import qualified Generated.Proto.Batch.Library.LibraryByID.Result           as LibraryByID
import qualified Generated.Proto.Batch.Library.LoadLibrary.Args             as LoadLibrary
import qualified Generated.Proto.Batch.Library.LoadLibrary.Result           as LoadLibrary
import qualified Generated.Proto.Batch.Library.RunLibrary.Args              as RunLibrary
import qualified Generated.Proto.Batch.Library.RunLibrary.Result            as RunLibrary
import qualified Generated.Proto.Batch.Library.StoreLibrary.Args            as StoreLibrary
import qualified Generated.Proto.Batch.Library.StoreLibrary.Result          as StoreLibrary
import qualified Generated.Proto.Batch.Library.UnloadLibrary.Args           as UnloadLibrary
import qualified Generated.Proto.Batch.Library.UnloadLibrary.Result         as UnloadLibrary
import qualified Generated.Proto.Batch.Maintenance.Dump.Args                as Dump
import qualified Generated.Proto.Batch.Maintenance.Dump.Result              as Dump
import qualified Generated.Proto.Batch.Maintenance.Initialize.Args          as Initialize
import qualified Generated.Proto.Batch.Maintenance.Initialize.Result        as Initialize
import qualified Generated.Proto.Batch.Maintenance.Ping.Args                as Ping
import qualified Generated.Proto.Batch.Maintenance.Ping.Result              as Ping
import qualified Generated.Proto.Batch.Maintenance.Shutdown.Args            as Shutdown
import qualified Generated.Proto.Batch.Maintenance.Shutdown.Result          as Shutdown
import qualified Generated.Proto.Batch.NodeDefault.NodeDefaults.Args        as NodeDefaults
import qualified Generated.Proto.Batch.NodeDefault.NodeDefaults.Result      as NodeDefaults
import qualified Generated.Proto.Batch.NodeDefault.RemoveNodeDefault.Args   as RemoveNodeDefault
import qualified Generated.Proto.Batch.NodeDefault.RemoveNodeDefault.Result as RemoveNodeDefault
import qualified Generated.Proto.Batch.NodeDefault.SetNodeDefault.Args      as SetNodeDefault
import qualified Generated.Proto.Batch.NodeDefault.SetNodeDefault.Result    as SetNodeDefault
import qualified Generated.Proto.Batch.Parser.ParseExpr.Args                as ParseExpr
import qualified Generated.Proto.Batch.Parser.ParseExpr.Result              as ParseExpr
import qualified Generated.Proto.Batch.Parser.ParseNodeExpr.Args            as ParseNodeExpr
import qualified Generated.Proto.Batch.Parser.ParseNodeExpr.Result          as ParseNodeExpr
import qualified Generated.Proto.Batch.Parser.ParsePat.Args                 as ParsePat
import qualified Generated.Proto.Batch.Parser.ParsePat.Result               as ParsePat
import qualified Generated.Proto.Batch.Parser.ParseType.Args                as ParseType
import qualified Generated.Proto.Batch.Parser.ParseType.Result              as ParseType
import qualified Generated.Proto.Batch.Process.Processes.Args               as Processes
import qualified Generated.Proto.Batch.Process.Processes.Result             as Processes
import qualified Generated.Proto.Batch.Process.Terminate.Args               as Terminate
import qualified Generated.Proto.Batch.Process.Terminate.Result             as Terminate
import qualified Generated.Proto.Batch.Project.CloseProject.Args            as CloseProject
import qualified Generated.Proto.Batch.Project.CloseProject.Result          as CloseProject
import qualified Generated.Proto.Batch.Project.CreateProject.Args           as CreateProject
import qualified Generated.Proto.Batch.Project.CreateProject.Result         as CreateProject
import qualified Generated.Proto.Batch.Project.OpenProject.Args             as OpenProject
import qualified Generated.Proto.Batch.Project.OpenProject.Result           as OpenProject
import qualified Generated.Proto.Batch.Project.ProjectByID.Args             as ProjectByID
import qualified Generated.Proto.Batch.Project.ProjectByID.Result           as ProjectByID
import qualified Generated.Proto.Batch.Project.Projects.Args                as Projects
import qualified Generated.Proto.Batch.Project.Projects.Result              as Projects
import qualified Generated.Proto.Batch.Project.StoreProject.Args            as StoreProject
import qualified Generated.Proto.Batch.Project.StoreProject.Result          as StoreProject
import qualified Generated.Proto.Batch.Project.UpdateProject.Args           as UpdateProject
import qualified Generated.Proto.Batch.Project.UpdateProject.Result         as UpdateProject
import qualified Generated.Proto.Batch.Properties.GetProperties.Args        as GetProperties
import qualified Generated.Proto.Batch.Properties.GetProperties.Result      as GetProperties
import qualified Generated.Proto.Batch.Properties.SetProperties.Args        as SetProperties
import qualified Generated.Proto.Batch.Properties.SetProperties.Result      as SetProperties



loggerIO :: LoggerIO
loggerIO = getLoggerIO "Flowbox.Batch.Server.ZMQ.Processor"


responseExt :: ResponseType.Type -> Maybe Int32 -> r -> Extensions.Key Maybe Response r -> ByteString
responseExt t i r rspkey = Proto.messageWithLengthPut
                         $ Extensions.putExt rspkey (Just r)
                         $ Response t i $ Extensions.ExtField Map.empty

response :: ResponseType.Type -> Maybe Int32 -> ByteString
response t i = Proto.messageWithLengthPut
             $ Response t i $ Extensions.ExtField Map.empty


process :: Handler h => MVar Socket -> h -> ByteString -> Int32 -> IO ByteString
process notifySocket handler encodedRequest requestID = case Proto.messageWithLengthGet encodedRequest of
                                     -- TODO [PM] : move messageWithLengthGet from here
    Left   e           -> fail $ "Error while decoding request: " ++ e
    Right (request, _) -> case Request.method request of
        Method.AST_AddModule            -> call Handler.addModule            AddModule.req            AddModule.rsp
        Method.AST_AddClass             -> call Handler.addClass             AddClass.req             AddClass.rsp
        Method.AST_AddFunction          -> call Handler.addFunction          AddFunction.req          AddFunction.rsp
        Method.AST_Definitions          -> call Handler.definitions          Definitions.req          Definitions.rsp
        Method.AST_UpdateModuleCls      -> call Handler.updateModuleCls      UpdateModuleCls.req      UpdateModuleCls.rsp
        Method.AST_UpdateModuleImports  -> call Handler.updateModuleImports  UpdateModuleImports.req  UpdateModuleImports.rsp
        Method.AST_UpdateModuleFields   -> call Handler.updateModuleFields   UpdateModuleFields.req   UpdateModuleFields.rsp
        Method.AST_UpdateDataCls        -> call Handler.updateDataCls        UpdateDataCls.req        UpdateDataCls.rsp
        Method.AST_UpdateDataCons       -> call Handler.updateDataCons       UpdateDataCons.req       UpdateDataCons.rsp
        Method.AST_UpdateDataClasses    -> call Handler.updateDataClasses    UpdateDataClasses.req    UpdateDataClasses.rsp
        Method.AST_UpdateDataMethods    -> call Handler.updateDataMethods    UpdateDataMethods.req    UpdateDataMethods.rsp
        Method.AST_UpdateFunctionName   -> call Handler.updateFunctionName   UpdateFunctionName.req   UpdateFunctionName.rsp
        Method.AST_UpdateFunctionPath   -> call Handler.updateFunctionPath   UpdateFunctionPath.req   UpdateFunctionPath.rsp
        Method.AST_UpdateFunctionInputs -> call Handler.updateFunctionInputs UpdateFunctionInputs.req UpdateFunctionInputs.rsp
        Method.AST_UpdateFunctionOutput -> call Handler.updateFunctionOutput UpdateFunctionOutput.req UpdateFunctionOutput.rsp
        Method.AST_Remove               -> call Handler.remove               Remove.req               Remove.rsp
        Method.AST_ResolveDefinition    -> call Handler.resolveDefinition    ResolveDefinition.req    ResolveDefinition.rsp

        Method.FileSystem_LS    -> call Handler.ls    LS.req    LS.rsp
        Method.FileSystem_Stat  -> call Handler.stat  Stat.req  Stat.rsp
        Method.FileSystem_MkDir -> call Handler.mkdir MkDir.req MkDir.rsp
        Method.FileSystem_Touch -> call Handler.touch Touch.req Touch.rsp
        Method.FileSystem_RM    -> call Handler.rm    RM.req    RM.rsp
        Method.FileSystem_CP    -> call Handler.cp    CP.req    CP.rsp
        Method.FileSystem_MV    -> call Handler.mv    MV.req    MV.rsp

        Method.Graph_NodesGraph -> call Handler.nodesGraph NodesGraph.req NodesGraph.rsp
        Method.Graph_NodeByID   -> call Handler.nodeByID   NodeByID.req   NodeByID.rsp
        Method.Graph_AddNode    -> call Handler.addNode    AddNode.req    AddNode.rsp
        Method.Graph_UpdateNode -> call Handler.updateNode UpdateNode.req UpdateNode.rsp
        Method.Graph_RemoveNode -> call Handler.removeNode RemoveNode.req RemoveNode.rsp
        Method.Graph_Connect    -> call Handler.connect    Connect.req    Connect.rsp
        Method.Graph_Disconnect -> call Handler.disconnect Disconnect.req Disconnect.rsp

        Method.Library_Libraries     -> call Handler.libraries     Libraries.req     Libraries.rsp
        Method.Library_LibraryByID   -> call Handler.libraryByID   LibraryByID.req   LibraryByID.rsp
        Method.Library_CreateLibrary -> call Handler.createLibrary CreateLibrary.req CreateLibrary.rsp
        Method.Library_LoadLibrary   -> call Handler.loadLibrary   LoadLibrary.req   LoadLibrary.rsp
        Method.Library_UnloadLibrary -> call Handler.unloadLibrary UnloadLibrary.req UnloadLibrary.rsp
        Method.Library_StoreLibrary  -> call Handler.storeLibrary  StoreLibrary.req  StoreLibrary.rsp
        Method.Library_BuildLibrary  -> call Handler.buildLibrary  BuildLibrary.req  BuildLibrary.rsp
        Method.Library_RunLibrary    -> call Handler.runLibrary    RunLibrary.req    RunLibrary.rsp

        Method.Maintenance_Initialize -> call Handler.initialize Initialize.req Initialize.rsp
        Method.Maintenance_Ping       -> call Handler.ping       Ping.req       Ping.rsp
        Method.Maintenance_Dump       -> call Handler.dump       Dump.req       Dump.rsp
        Method.Maintenance_Shutdown   -> call Handler.shutdown   Shutdown.req   Shutdown.rsp

        Method.NodeDefault_NodeDefaults      -> call Handler.nodeDefaults      NodeDefaults.req      NodeDefaults.rsp
        Method.NodeDefault_SetNodeDefault    -> call Handler.setNodeDefault    SetNodeDefault.req    SetNodeDefault.rsp
        Method.NodeDefault_RemoveNodeDefault -> call Handler.removeNodeDefault RemoveNodeDefault.req RemoveNodeDefault.rsp

        Method.Parser_ParseExpr     -> call Handler.parseExpr     ParseExpr.req     ParseExpr.rsp
        Method.Parser_ParsePat      -> call Handler.parsePat      ParsePat.req      ParsePat.rsp
        Method.Parser_ParseType     -> call Handler.parseType     ParseType.req     ParseType.rsp
        Method.Parser_ParseNodeExpr -> call Handler.parseNodeExpr ParseNodeExpr.req ParseNodeExpr.rsp

        Method.Process_Processes     -> call Handler.processes     Processes.req     Processes.rsp
        Method.Process_Terminate     -> call Handler.terminate     Terminate.req     Terminate.rsp

        Method.Project_Projects      -> call Handler.projects      Projects.req      Projects.rsp
        Method.Project_ProjectByID   -> call Handler.projectByID   ProjectByID.req   ProjectByID.rsp
        Method.Project_CreateProject -> call Handler.createProject CreateProject.req CreateProject.rsp
        Method.Project_OpenProject   -> call Handler.openProject   OpenProject.req   OpenProject.rsp
        Method.Project_UpdateProject -> call Handler.updateProject UpdateProject.req UpdateProject.rsp
        Method.Project_CloseProject  -> call Handler.closeProject  CloseProject.req  CloseProject.rsp
        Method.Project_StoreProject  -> call Handler.storeProject  StoreProject.req  StoreProject.rsp

        Method.Properties_GetProperties -> call Handler.getProperties GetProperties.req GetProperties.rsp
        Method.Properties_SetProperties -> call Handler.setProperties SetProperties.req SetProperties.rsp
        where
            call method reqkey rspkey = if Request.async request == Just True
                then do loggerIO debug $ "async call " ++ show requestID
                        asyncCall method reqkey rspkey
                else do loggerIO debug $ "sync call " ++ show requestID
                        syncCall  method reqkey rspkey

            asyncCall method reqkey rspkey = do
                _ <- Concurrent.forkIO $ do b <- syncCall method reqkey rspkey
                                            MVar.withMVar notifySocket (\s -> TCP.sendData s b)
                return $ response ResponseType.Accept (Just requestID)

            syncCall method reqkey rspkey = do
                e <- runEitherT $ scriptIO $ unsafeCall method reqkey rspkey
                case e of
                    Left  m -> do loggerIO error m
                                  let exc = Exception $ encodePJ m
                                  return $ responseExt ResponseType.Exception (Just requestID) exc Exception.rsp
                    Right a ->    return a

            unsafeCall method reqkey rspkey = do
                r <- case Extensions.getExt reqkey request of
                    Right (Just args) -> do loggerIO debug $ show args
                                            method handler args
                    Left   e'         -> fail $ "Error while getting extension: " ++ e'
                    _                 -> fail $ "Error while getting extension"
                loggerIO trace $ show r
                return $ responseExt ResponseType.Result (Just requestID) r rspkey
