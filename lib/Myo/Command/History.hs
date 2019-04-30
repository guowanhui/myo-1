module Myo.Command.History where

import Chiasma.Data.Ident (Ident, sameIdent)
import Control.Monad.DeepState (MonadDeepState)
import Ribosome.Control.Monad.Ribo (prepend)

import Myo.Command.Data.Command (Command)
import Myo.Command.Data.CommandState (CommandState)
import qualified Myo.Command.Data.CommandState as CommandState (history)
import Myo.Command.Data.HistoryEntry (HistoryEntry(HistoryEntry))

pushHistory ::
  MonadDeepState s CommandState m =>
  Command ->
  m ()
pushHistory cmd =
  modifyL @CommandState CommandState.history prep
  where
    prep es = (HistoryEntry cmd) : (filter (not . sameIdent cmd) es)
