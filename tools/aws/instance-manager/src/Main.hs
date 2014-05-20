---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

import           Options.Applicative (command, command, fullDesc, help, hidden, long, metavar, prefs, progDesc, short, strOption, subparser, switch, value, (<>))
import qualified Options.Applicative as Opt

import qualified Flowbox.AWS.Region                      as Region
import           Flowbox.Control.Applicative
import qualified Flowbox.InstanceManager.Cmd             as Cmd
import qualified Flowbox.InstanceManager.Config          as Config
import qualified Flowbox.InstanceManager.InstanceManager as InstanceManager
import qualified Flowbox.InstanceManager.Version         as Version
import           Flowbox.Options.Applicative             (optIntFlag)
import           Flowbox.Prelude                         hiding (argument, op)
import           Flowbox.System.Log.Logger



rootLogger :: Logger
rootLogger = getLogger "Flowbox"


startParser :: Opt.Parser Cmd.Command
startParser = Cmd.Start <$> ( Cmd.StartOptions <$> strOption ( long "ami"     <> short 'a' <> value (Config.ami     def) <> metavar "ami-id"       <> help ("Specify AMI to run, default is " ++ (Config.ami def)))
                                               <*> strOption ( long "machine" <> short 'm' <> value (Config.machine def) <> metavar "machine-type" <> help ("Specify machine type to run, default is " ++ (Config.machine def)))
                                               <*> credOption
                                               <*> strOption ( long "key"     <> short 'k' <> value (Config.keyName def) <> metavar "key-pair-name" <> help ("Specify key pair name for a created machine, default is " ++ (Config.keyName def)))
                          )


stopParser :: Opt.Parser Cmd.Command
stopParser = Cmd.Stop <$> ( Cmd.StopOptions <$> switch ( long "force" <> short 'f' <> help "Force instance stop" )
                                            <*> credOption
                          )


terminateParser :: Opt.Parser Cmd.Command
terminateParser = Cmd.Terminate <$> ( Cmd.TerminateOptions <$> credOption )


getParser :: Opt.Parser Cmd.Command
getParser = Cmd.Get <$> ( Cmd.GetOptions <$> credOption )


versionParser :: Opt.Parser Cmd.Command
versionParser = Cmd.Version <$> (Cmd.VersionOptions <$> switch ( long "numeric"  <> help "print only numeric version" )
                                )


parser :: Opt.Parser Cmd.Prog
parser = Cmd.Prog <$> subparser ( command "start"     (Opt.info startParser     (progDesc "Start EC2 instance"))
                               <> command "stop"      (Opt.info stopParser      (progDesc "Stop EC2 instance"))
                               <> command "get"       (Opt.info getParser       (progDesc "Get EC2 instance ID and IP"))
                               <> command "terminate" (Opt.info terminateParser (progDesc "Terminate EC2 instance and lose all saved data on its local storage"))
                               <> command "version"   (Opt.info versionParser   (progDesc "Print instance-manager version"))
                                )
                  <*> strOption ( long "region" <> short 'r' <> value (Config.region def) <> metavar "region" <> help ("Specify AWS region, default is " ++ (Config.region def)))
                  <*> switch    ( long "no-color" <> hidden <> help "disable color output" )
                  <*> optIntFlag Nothing 'v' 3 2 "verbose level [0-5], default 3"
                  <**> helper


credOption :: Opt.Parser String
credOption = strOption ( long "cred" <> short 'c' <> value (Config.credentialPath def) <> metavar "path" <> help ("Path to a file with AWS credentials, default is " ++ (Config.credentialPath def)))


opts :: Opt.ParserInfo Cmd.Prog
opts = Opt.info parser (fullDesc <> Opt.progDesc "Flowbox Instance Manager - Amazon Elastic Compute Cloud instance manager")


helper :: Opt.Parser (a -> a)
helper = Opt.abortOption Opt.ShowHelpText $ (long "help" <> short 'h' <> help "show this help text")


main :: IO ()
main = run =<< Opt.customExecParser
              (prefs Opt.showHelpOnError)
              opts


run :: Cmd.Prog -> IO ()
run prog = do
    rootLogger setIntLevel $ Cmd.verbose prog
    let region = Region.fromString $ Cmd.region prog
    case Cmd.cmd prog of
      Cmd.Version   op -> putStrLn $ Version.full (Cmd.numeric op)
      Cmd.Start     op -> InstanceManager.start     region op
      Cmd.Get       op -> InstanceManager.get       region op
      Cmd.Stop      op -> InstanceManager.stop      region op
      Cmd.Terminate op -> InstanceManager.terminate region op

