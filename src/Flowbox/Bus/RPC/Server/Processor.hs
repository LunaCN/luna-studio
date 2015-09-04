---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Flowbox.Bus.RPC.Server.Processor where

import           Control.Monad              (liftM)
import           Control.Monad.Trans.Either (eitherT, hoistEither)
import           Data.Either                as Either
import qualified Data.Maybe                 as Maybe
--import           Data.Typeable
import qualified Control.Monad.Catch       as Catch
import           Control.Monad.Trans.State (StateT)
import           Data.Binary               (Binary)
import Control.Monad.Trans.Either          (EitherT)

import           Flowbox.Bus.Data.Message   (CorrelationID, Message)
import qualified Flowbox.Bus.Data.Message   as Message
import           Flowbox.Bus.Data.Topic     ((/+))
import           Flowbox.Bus.RPC.HandlerMap (HandlerMap)
import qualified Flowbox.Bus.RPC.HandlerMap as HandlerMap
import qualified Flowbox.Bus.RPC.RPC        as RPC
import           Flowbox.Bus.RPC.Types
import           Flowbox.Prelude            hiding (error)
import           Flowbox.System.Log.Logger



logger :: LoggerIO
logger = getLoggerIO $moduleName


singleResult :: MonadIO m => (a -> m b) -> a -> m [b]
singleResult f a = liftM return $ f a


noResult :: MonadIO m => (a -> m ()) -> a -> m [Response]
noResult f a = f a >> return []


-- FIXME: typ malo mowi
optResult :: MonadIO m => (a -> m (Maybe b)) -> a -> m [b]
optResult f a = liftM Maybe.maybeToList $ f a


process :: forall s m. (Catch.MonadCatch m, MonadIO m, Functor m)
        => HandlerMap s m -> CorrelationID -> Message -> StateT s m [Message]
process handlerMap correlationID msg = either handleError (\message -> do
        m <- message
        logger debug $ show m
        message
    ) handleMessage
    where
        call :: (Catch.MonadCatch m, MonadIO m, Functor m) => HandlerMap.Callback s m
        call method = do
            eitherT errorHandler applyArgs deserializeMsg
            where
                deserializeMsg :: (Binary a, Typeable a) => EitherT String (StateT s m) a
                deserializeMsg = do
                    req    <- hoistEither request
                    unpackValue $ req ^. arguments
                errorHandler err = do logger error err
                                      return (ErrorResult err, [])
                applyArgs desReq = do
                    status <- RPC.run $ method correlationID desReq
                    case status of
                        Left err -> do logger error err
                                       return (ErrorResult err, [])
                        Right (res, update) -> return (Status $ packValue res, update)
        mkResponse :: Either String ((Result, [Value]) -> Response)
        mkResponse = make <$> functionName
            where make fname (result', updates) = Response fname result' updates
        respond :: Response -> [Message]
        respond resp = [Message.mk ((msg ^. Message.topic) /+ "response") resp]
        functionName :: Either String FunctionName
        functionName = (^. requestMethod) <$> request
        request :: Either String Request
        request = RPC.messageGet' $ msg ^. Message.message

        handleError :: Monad m => String -> StateT s m [Message]
        handleError s = return $ respond $ Response fname (ErrorResult s) []
                where fname = either (const "") id functionName

        handleMessage :: Either String (StateT s m [Message])
        handleMessage = do
            let hmap = HandlerMap.lookupAndCall handlerMap call :: FunctionName -> StateT s m (Result, [Value])
            f <- mkResponse
            (fmap . fmap) (respond . f) $ hmap . functionName

