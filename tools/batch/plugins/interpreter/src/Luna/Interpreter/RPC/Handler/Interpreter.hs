---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections   #-}
module Luna.Interpreter.RPC.Handler.Interpreter where

import           Control.Monad.Catch (bracket_)
import qualified Data.Foldable       as Foldable
import qualified Data.Maybe          as Maybe
import qualified Data.Sequence       as Sequence
import qualified Data.Set            as Set

import qualified Flowbox.Bus.Data.Message                                                     as Message
import           Flowbox.Bus.RPC.RPC                                                          (RPC)
import           Flowbox.Control.Error
import qualified Flowbox.Data.SetForest                                                       as SetForest
import           Flowbox.Prelude                                                              hiding (Context)
import           Flowbox.ProjectManager.Context                                               (Context)
import           Flowbox.System.Log.Logger                                                    hiding (error)
import           Flowbox.Tools.Serialize.Proto.Conversion.Basic
import qualified Generated.Proto.Interpreter.Interpreter.Abort.Request                        as Abort
import qualified Generated.Proto.Interpreter.Interpreter.Abort.Status                         as Abort
import qualified Generated.Proto.Interpreter.Interpreter.GetMainPtr.Request                   as GetMainPtr
import qualified Generated.Proto.Interpreter.Interpreter.GetMainPtr.Status                    as GetMainPtr
import qualified Generated.Proto.Interpreter.Interpreter.GetProjectID.Request                 as GetProjectID
import qualified Generated.Proto.Interpreter.Interpreter.GetProjectID.Status                  as GetProjectID
import qualified Generated.Proto.Interpreter.Interpreter.Memory.GetLimits.Request             as MemoryGetLimits
import qualified Generated.Proto.Interpreter.Interpreter.Memory.GetLimits.Status              as MemoryGetLimits
import qualified Generated.Proto.Interpreter.Interpreter.Memory.SetLimits.Request             as MemorySetLimits
import qualified Generated.Proto.Interpreter.Interpreter.Memory.SetLimits.Update              as MemorySetLimits
import qualified Generated.Proto.Interpreter.Interpreter.Ping.Request                         as Ping
import qualified Generated.Proto.Interpreter.Interpreter.Ping.Status                          as Ping
import qualified Generated.Proto.Interpreter.Interpreter.Run.Request                          as Run
import qualified Generated.Proto.Interpreter.Interpreter.Run.Update                           as Run
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.DefaultGet.Request as GetDefaultSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.DefaultGet.Status  as GetDefaultSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.DefaultSet.Request as SetDefaultSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.DefaultSet.Update  as SetDefaultSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.Delete.Request     as DeleteSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.Delete.Update      as DeleteSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.DeleteAll.Request  as DeleteAllSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.DeleteAll.Update   as DeleteAllSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.Get.Request        as GetSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.Get.Status         as GetSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.Insert.Request     as InsertSMode
import qualified Generated.Proto.Interpreter.Interpreter.SerializationMode.Insert.Update      as InsertSMode
import qualified Generated.Proto.Interpreter.Interpreter.SetMainPtr.Request                   as SetMainPtr
import qualified Generated.Proto.Interpreter.Interpreter.SetMainPtr.Update                    as SetMainPtr
import qualified Generated.Proto.Interpreter.Interpreter.SetProjectID.Request                 as SetProjectID
import qualified Generated.Proto.Interpreter.Interpreter.SetProjectID.Update                  as SetProjectID
import qualified Generated.Proto.Interpreter.Interpreter.WatchPoint.Add.Request               as WatchPointAdd
import qualified Generated.Proto.Interpreter.Interpreter.WatchPoint.Add.Update                as WatchPointAdd
import qualified Generated.Proto.Interpreter.Interpreter.WatchPoint.List.Request              as WatchPointList
import qualified Generated.Proto.Interpreter.Interpreter.WatchPoint.List.Status               as WatchPointList
import qualified Generated.Proto.Interpreter.Interpreter.WatchPoint.Remove.Request            as WatchPointRemove
import qualified Generated.Proto.Interpreter.Interpreter.WatchPoint.Remove.Update             as WatchPointRemove
import           Luna.Interpreter.Proto.CallPointPath                                         ()
import           Luna.Interpreter.Proto.DefPoint                                              ()
import qualified Luna.Interpreter.RPC.Handler.Cache                                           as Cache
import           Luna.Interpreter.RPC.Handler.Lift
import qualified Luna.Interpreter.RPC.Handler.Sync                                            as Sync
import           Luna.Interpreter.RPC.QueueInfo                                               (QueueInfo)
import qualified Luna.Interpreter.RPC.QueueInfo                                               as QueueInfo
import qualified Luna.Interpreter.Session.AST.Executor                                        as Executor
import qualified Luna.Interpreter.Session.AST.WatchPoint                                      as WatchPoint
import qualified Luna.Interpreter.Session.Env                                                 as Env
import qualified Luna.Interpreter.Session.Error                                               as Error
import qualified Luna.Interpreter.Session.Memory                                              as Memory
import           Luna.Interpreter.Session.Memory.Manager                                      (MemoryManager)
import           Luna.Interpreter.Session.Session                                             (SessionST)



logger :: LoggerIO
logger = getLoggerIO $(moduleName)


getProjectID :: GetProjectID.Request -> RPC Context (SessionST mm) GetProjectID.Status
getProjectID request = do
    projectID <- liftSession Env.getProjectIDMaybe
    return $ GetProjectID.Status request $ fmap encodeP projectID


setProjectID :: MemoryManager mm => SetProjectID.Request -> RPC Context (SessionST mm) SetProjectID.Update
setProjectID request@(SetProjectID.Request tprojectID) = do
    liftSession $ Env.setProjectID $ decodeP tprojectID
    Sync.syncLibManager
    Cache.deleteAll tprojectID
    Cache.modifyAll tprojectID
    return $ SetProjectID.Update request


getMainPtr :: GetMainPtr.Request -> RPC Context (SessionST mm) GetMainPtr.Status
getMainPtr request = do
    projectID <- liftSession Env.getProjectIDMaybe
    mainPtr   <- liftSession Env.getMainPtrMaybe
    let tmainPtr = (encode .: (,)) <$> projectID <*> mainPtr
    return $ GetMainPtr.Status request tmainPtr


setMainPtr :: SetMainPtr.Request -> RPC Context (SessionST mm) SetMainPtr.Update
setMainPtr request@(SetMainPtr.Request tmainPtr) = do
    (projectID, mainPtr) <- decodeE tmainPtr
    Sync.testProjectID projectID
    liftSession $ Env.setMainPtr mainPtr
    return $ SetMainPtr.Update request


run :: QueueInfo -> Message.CorrelationID -> Run.Request -> RPC Context (SessionST mm) Run.Update
run queueInfo crl request = do
    r <- lift $ bracket_ (liftIO $ QueueInfo.enterRun queueInfo crl)
            (liftIO $ QueueInfo.quitRun queueInfo) $
            liftSession' Executor.processMain
    hoistEither $ fmapL Error.format r
    return $ Run.Update request


watchPointAdd :: WatchPointAdd.Request -> RPC Context (SessionST mm) WatchPointAdd.Update
watchPointAdd request@(WatchPointAdd.Request tcallPointPath) = do
    (projectID, callPointPath) <- decodeE tcallPointPath
    Sync.testProjectID projectID
    liftSession $ WatchPoint.add callPointPath
    return $ WatchPointAdd.Update request


watchPointRemove :: WatchPointRemove.Request -> RPC Context (SessionST mm) WatchPointRemove.Update
watchPointRemove request@(WatchPointRemove.Request tcallPointPath) = do
    (projectID, callPointPath) <- decodeE tcallPointPath
    Sync.testProjectID projectID
    liftSession $ WatchPoint.delete callPointPath
    return $ WatchPointRemove.Update request


watchPointList :: WatchPointList.Request -> RPC Context (SessionST mm) WatchPointList.Status
watchPointList request = do
    list      <- liftSession $ SetForest.toList <$> WatchPoint.all
    projectID <- liftSession Env.getProjectID
    return $ WatchPointList.Status request $ encodeList $ map (projectID,) list


ping :: Ping.Request -> RPC Context (SessionST mm) Ping.Status
ping request = do
    logger info "Ping received"
    return $ Ping.Status request


abort :: Abort.Request -> RPC Context (SessionST mm) Abort.Status
abort = return . Abort.Status


getDefaultSerializationMode :: GetDefaultSMode.Request -> RPC Context (SessionST mm) GetDefaultSMode.Status
getDefaultSerializationMode request = do
    mode <- liftSession Env.getDefaultSerializationMode
    return $ GetDefaultSMode.Status request mode


setDefaultSerializationMode :: SetDefaultSMode.Request -> RPC Context (SessionST mm) SetDefaultSMode.Update
setDefaultSerializationMode request@(SetDefaultSMode.Request mode) = do
    liftSession $ Env.setDefaultSerializationMode mode
    return $ SetDefaultSMode.Update request


getSerializationMode :: GetSMode.Request -> RPC Context (SessionST mm) GetSMode.Status
getSerializationMode request@(GetSMode.Request tcallPointPath) = do
    (projectID, callPointPath) <- decodeE tcallPointPath
    Sync.testProjectID projectID
    modes <- liftSession $ Env.lookupSerializationModes callPointPath
    return $ GetSMode.Status request $ Sequence.fromList $ Maybe.maybe [] Set.toList modes


insertSerializationMode :: InsertSMode.Request -> RPC Context (SessionST mm) InsertSMode.Update
insertSerializationMode request@(InsertSMode.Request tcallPointPath modes) = do
    (projectID, callPointPath) <- decodeE tcallPointPath
    Sync.testProjectID projectID
    liftSession $ Env.insertSerializationModes callPointPath $ Set.fromList $ Foldable.toList modes
    return $ InsertSMode.Update request


deleteSerializationMode :: DeleteSMode.Request -> RPC Context (SessionST mm) DeleteSMode.Update
deleteSerializationMode request@(DeleteSMode.Request tcallPointPath modes) = do
    (projectID, callPointPath) <- decodeE tcallPointPath
    Sync.testProjectID projectID
    liftSession $ Env.deleteSerializationModes callPointPath $ Set.fromList $ Foldable.toList modes
    return $ DeleteSMode.Update request


deleteAllSerializationMode :: DeleteAllSMode.Request -> RPC Context (SessionST mm) DeleteAllSMode.Update
deleteAllSerializationMode request@(DeleteAllSMode.Request tcallPointPath) = do
    (projectID, callPointPath) <- decodeE tcallPointPath
    Sync.testProjectID projectID
    liftSession $ Env.clearSerializationModes callPointPath
    return $ DeleteAllSMode.Update request


getMemoryLimits :: MemoryGetLimits.Request -> RPC Context (SessionST mm) MemoryGetLimits.Status
getMemoryLimits request = do
    memConfig <- liftSession Env.getMemoryConfig
    return $ MemoryGetLimits.Status request (memConfig ^. Memory.memoryUpperLimit)
                                            (memConfig ^. Memory.memoryLowerLimit)


setMemoryLimits :: MemorySetLimits.Request -> RPC Context (SessionST mm) MemorySetLimits.Update
setMemoryLimits request@(MemorySetLimits.Request upper lower) = do
    liftSession $ Env.setMemoryConfig $ Memory.Config upper lower
    return $ MemorySetLimits.Update request
