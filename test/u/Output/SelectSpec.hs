{-# OPTIONS_GHC -F -pgmF htfpp #-}

module Output.SelectSpec (htf_thisModulesTests) where

import qualified Chiasma.Data.Ident as Ident (Ident(Str))
import Data.Vector (Vector)
import qualified Data.Vector as Vector (fromList, zipWith)
import Prelude hiding (tmuxSpec)
import Ribosome.Api.Window (currentCursor)
import Ribosome.Plugin.Mapping (executeMapping)
import Ribosome.Test.Ui (windowCountIs)
import Ribosome.Test.Unit (fixture)
import System.FilePath ((</>))
import Test.Framework

import Config (outputAutoJump, outputSelectFirst, svar)
import Myo.Command.Data.CommandState (CommandState, OutputState(OutputState))
import qualified Myo.Command.Data.CommandState as CommandState (output)
import Myo.Command.Output (compileAndRenderReport)
import Myo.Data.Env (Myo)
import Myo.Init (initialize'')
import Myo.Output.Data.Location (Location(Location))
import Myo.Output.Data.OutputEvent (
  LangOutputEvent(LangOutputEvent),
  OutputEventMeta(OutputEventMeta),
  )
import Myo.Output.Data.OutputEvents (OutputEvents)
import Myo.Output.Lang.Haskell.Report (HaskellMessage(FoundReq1, NoMethod), formatReportLine)
import Myo.Output.Lang.Haskell.Syntax (haskellSyntax)
import Myo.Output.Lang.Report (parsedOutputCons)
import Myo.Plugin (mappingOutputSelect)
import Unit (tmuxSpec)

events :: Text -> Vector OutputEventMeta
events file =
  Vector.fromList [OutputEventMeta (Just (Location file 9 (Just 2))) 0, OutputEventMeta Nothing 1]

messages :: Vector HaskellMessage
messages =
  Vector.fromList [FoundReq1 "TypeA" "TypeB", NoMethod "fmap"]

parsedOutput :: Text -> OutputEvents
parsedOutput file =
  parsedOutputCons formatReportLine (Vector.zipWith LangOutputEvent (events file) messages)

outputSelectSpec :: Myo ()
outputSelectSpec = do
  file <- fixture $ "output" </> "select" </> "File.hs"
  let po = parsedOutput (toText file)
  initialize''
  setL @CommandState CommandState.output (Just (OutputState (Ident.Str "test") [haskellSyntax] po def Nothing))
  compileAndRenderReport
  windowCountIs 2
  executeMapping mappingOutputSelect
  (line, col) <- currentCursor
  gassertEqual (9, 2) (line, col)

test_outputSelect :: IO ()
test_outputSelect =
  tmuxSpec (svar outputSelectFirst True . svar outputAutoJump False) outputSelectSpec
