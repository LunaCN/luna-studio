{-# OPTIONS_GHC -fno-warn-orphans #-}
module TextEditor.State.Global where

import Common.Prelude

import qualified Data.Set      as Set
import qualified System.Random as Random

import Common.Action.Command                    (Command)
import Data.Aeson                               (ToJSON, toJSON)
import Data.Map                                 (Map)
import Data.Set                                 (Set)
import Data.Time.Clock                          (UTCTime)
import Data.UUID.Types                          (UUID)
import Data.Word                                (Word8)
import Luna.Benchmark                           (HasRequestTimes, requestTimes)
import LunaStudio.API.Graph.CollaborationUpdate (ClientId)
import System.Random                            (StdGen)
import TextEditor.Event.Event                   (Event)


data State = State
    { _lastEvent        :: Maybe Event
    , _eventNum         :: Int
    , _pendingRequests  :: Map UUID UTCTime
    , _ignoredResponses :: Set UUID
    , _clientId         :: ClientId
    , _random           :: StdGen
    }

instance ToJSON StdGen where
    toJSON _ = toJSON "(random-generator)"

makeLenses ''State

mkState :: ClientId -> StdGen -> State
mkState = State def def def def

nextRandom :: Command State Word8
nextRandom = uses random Random.random >>= \(val, rnd) -> random .= rnd >> return val

instance HasRequestTimes State where
    requestTimes = pendingRequests

-- === Ignored responses === --

ignoreResponse :: UUID -> Command State ()
ignoreResponse uuid = ignoredResponses %= Set.insert uuid

checkResponse :: UUID -> Command State Bool
checkResponse uuid = do
    responses <- use ignoredResponses
    let shouldHandle = Set.notMember uuid responses
    ignoredResponses .= Set.delete uuid responses
    pure shouldHandle
