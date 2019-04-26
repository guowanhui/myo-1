{-# OPTIONS_GHC -F -pgmF htfpp #-}
{-# LANGUAGE TemplateHaskell #-}

module Command.UpdateSpec (htf_thisModulesTests) where

import Chiasma.Data.Ident (identText)
import qualified Chiasma.Data.Ident as Ident (Ident(Str))
import Control.Monad.Trans.Except (ExceptT)
import Data.Default (def)
import Neovim (Neovim, Plugin(..))
import Path (Abs, Dir, Path)
import Ribosome.Api.Autocmd (doautocmd)
import Ribosome.Api.Variable (setVar)
import Ribosome.Control.Monad.Ribo (NvimE)
import Ribosome.Control.Ribosome (Ribosome, newRibosome)
import Ribosome.Nvim.Api.IO (vimCallFunction)
import Ribosome.Nvim.Api.RpcCall (RpcError)
import Ribosome.Plugin (riboPlugin, rpcHandler, sync)
import Ribosome.Test.Await (await)
import Ribosome.Test.Embed (integrationSpecDef)
import Ribosome.Test.Orphans ()
import Test.Framework

import Myo.Command.Data.AddSystemCommandOptions (AddSystemCommandOptions(AddSystemCommandOptions))
import Myo.Command.Data.Command (Command(Command))
import Myo.Command.Data.CommandSettingCodec (CommandSettingCodec(CommandSettingCodec))
import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (commands)
import Myo.Data.Env (Env(_tempDir))
import Myo.Env (bracketMyoTempDir)
import Myo.Plugin (handleError, variables)

commands1 :: [AddSystemCommandOptions]
commands1 =
  [AddSystemCommandOptions (Ident.Str "c1") ["tail"] Nothing Nothing Nothing]

commands2 :: [AddSystemCommandOptions]
commands2 =
  [
    AddSystemCommandOptions (Ident.Str "c1") ["tails"] Nothing Nothing Nothing,
    AddSystemCommandOptions (Ident.Str "c2") ["echo"] Nothing Nothing Nothing
    ]

codec :: [AddSystemCommandOptions] -> CommandSettingCodec
codec cmds =
  CommandSettingCodec (Just cmds) Nothing

cmdData :: MonadDeepState s CommandState m => m [(Text, [Text])]
cmdData =
  fmap extract <$> getL @CommandState CommandState.commands
  where
    extract (Command _ ident lines' _ _) = (identText ident, lines')

$(return [])

plugin :: Path Abs Dir -> IO (Plugin (Ribosome Env))
plugin tempDir = do
  ribo <- newRibosome "myo" def { _tempDir = tempDir }
  return $ riboPlugin "myo" ribo [$(rpcHandler sync 'cmdData)] [] handleError variables

getCmdData ::
  NvimE e m =>
  m [(Text, [Text])]
getCmdData =
  vimCallFunction "CmdData" []

updateCommandsSpec :: ExceptT RpcError (Neovim ()) ()
updateCommandsSpec = do
  setVar "myo_commands" (codec commands1)
  doautocmd "CmdlineLeave"
  await (gassertEqual [("c1", ["tail"])]) getCmdData
  setVar "myo_commands" (codec commands2)
  doautocmd "BufWinEnter"
  await (gassertEqual [("c1", ["tails"]), ("c2", ["echo"])]) getCmdData

test_updateCommands :: IO ()
test_updateCommands =
  bracketMyoTempDir run
  where
    run tempDir = do
      plug <- plugin tempDir
      integrationSpecDef plug updateCommandsSpec