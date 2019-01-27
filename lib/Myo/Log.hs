module Myo.Log(
  debug,
  info,
  debugS,
  infoS,
  R.p,
  R.prefixed,
  trees,
) where

import qualified Control.Lens as Lens (toListOf)
import Control.Monad.IO.Class (liftIO)
import Data.Foldable (traverse_)
import Chiasma.Ui.ShowTree (printViewTree)
import Ribosome.Control.Ribo (Ribo)
import qualified Ribosome.Control.Ribo as Ribo (inspect)
import qualified Ribosome.Log as R (debug, info, p, prefixed)
import Myo.Data.Myo (Myo)
import Myo.Ui.View (envTreesLens)

debug :: String -> Ribo e ()
debug = R.debug "myo"

info :: String -> Ribo e ()
info = R.info "myo"

debugS :: Show a => a -> Ribo e ()
debugS = R.debug "myo"

infoS :: Show a => a -> Ribo e ()
infoS = R.info "myo"

trees :: Myo ()
trees = do
  ts <- Ribo.inspect $ Lens.toListOf envTreesLens
  traverse_ printViewTree ts
