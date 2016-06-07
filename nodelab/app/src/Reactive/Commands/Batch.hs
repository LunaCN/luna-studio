module Reactive.Commands.Batch  where

import           Utils.PreludePlus

import           Data.Binary                   (encode)
import qualified Data.Binary                   as Binary
import           Data.ByteString.Lazy.Char8    (pack)
import           Data.Int
import           Data.Map                      as Map
import qualified Data.Sequence                 as Seq
import qualified Data.Text.Lazy                as Text
import           Data.UUID.Types               (UUID, nil)
import           Utils.Vector                  (Vector2 (..), x, y)

import           Batch.Workspace               (Workspace)
import qualified Batch.Workspace               as Workspace
import qualified BatchConnector.Commands       as BatchCmd

import           Reactive.Commands.Command     (Command, execCommand, performIO)
import qualified Reactive.Commands.UIRegistry  as UICmd
import           Reactive.Commands.UUID        (registerRequest)
import           Reactive.State.Global         (State, workspace)

import qualified Empire.API.Data.Connection    as Connection
import qualified Empire.API.Data.DefaultValue  as DefaultValue
import           Empire.API.Data.GraphLocation (GraphLocation)
import qualified Empire.API.Data.GraphLocation as GraphLocation
import           Empire.API.Data.Library       (Library, LibraryId)
import qualified Empire.API.Data.Library       as Library
import           Empire.API.Data.Node          (Node (..))
import           Empire.API.Data.Node          (NodeId)
import qualified Empire.API.Data.Node          as Node
import           Empire.API.Data.NodeMeta      (NodeMeta)
import qualified Empire.API.Data.NodeMeta      as NodeMeta
import           Empire.API.Data.Port          (InPort (..))
import qualified Empire.API.Data.Port          as Port
import           Empire.API.Data.PortRef       (AnyPortRef (..), InPortRef (..), OutPortRef (..))
import qualified Empire.API.Data.PortRef       as PortRef
import           Empire.API.Data.Project       (Project, ProjectId)
import qualified Empire.API.Data.Project       as Project


withWorkspace :: (Workspace -> UUID -> IO ()) -> Command State ()
withWorkspace act = do
    uuid      <- registerRequest
    workspace <- use workspace
    performIO $ act workspace uuid

withUUID :: (UUID -> IO ()) -> Command State ()
withUUID act = do
    uuid <- registerRequest
    performIO $ act uuid

addNode :: Text -> NodeMeta -> Maybe NodeId -> Command State ()
addNode = withWorkspace .:. BatchCmd.addNode

createProject :: Text -> Command State ()
createProject = withUUID . BatchCmd.createProject

listProjects ::  Command State ()
listProjects = withUUID BatchCmd.listProjects

createLibrary :: Text -> Text -> Command State ()
createLibrary = withWorkspace .: BatchCmd.createLibrary

listLibraries :: ProjectId -> Command State ()
listLibraries = withUUID . BatchCmd.listLibraries

getProgram :: Command State ()
getProgram = withWorkspace BatchCmd.getProgram

updateNodeMeta :: NodeId -> NodeMeta -> Command State ()
updateNodeMeta = withWorkspace .: BatchCmd.updateNodeMeta

renameNode :: NodeId -> Text -> Command State ()
renameNode = withWorkspace .:  BatchCmd.renameNode

removeNode :: [NodeId] -> Command State ()
removeNode = withWorkspace . BatchCmd.removeNode

connectNodes :: OutPortRef -> InPortRef -> Command State ()
connectNodes = withWorkspace .: BatchCmd.connectNodes

disconnectNodes :: InPortRef -> Command State ()
disconnectNodes = withWorkspace . BatchCmd.disconnectNodes

setDefaultValue :: AnyPortRef -> DefaultValue.PortDefault -> Command State ()
setDefaultValue = withWorkspace .: BatchCmd.setDefaultValue

setInputNodeType :: NodeId -> Text -> Command State ()
setInputNodeType = withWorkspace .: BatchCmd.setInputNodeType

exportProject :: ProjectId -> Command State ()
exportProject = withUUID . BatchCmd.exportProject

importProject :: Text -> Command State ()
importProject = withUUID . BatchCmd.importProject
