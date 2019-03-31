module Myo.Output.Lang.Haskell.Parser where

import Control.Applicative (Alternative)
import Control.Monad ((<=<))
import Data.Attoparsec.Text (parseOnly)
import qualified Data.ByteString.UTF8 as ByteString (fromString, toString)
import Data.Either.Combinators (mapLeft)
import Data.Functor (void)
import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import qualified Data.Text as Text (pack)
import Text.Parser.Char (CharParsing, anyChar, char, digit, newline, noneOf, notChar, string)
import Text.Parser.Combinators (choice, eof, many, manyTill, notFollowedBy, skipMany, skipOptional, try)
import Text.Parser.LookAhead (LookAheadParsing, lookAhead)
import Text.Parser.Token (TokenParsing, brackets, natural, whiteSpace)

import Myo.Output.Data.Location (Location(Location))
import Myo.Output.Data.OutputError (OutputError)
import qualified Myo.Output.Data.OutputError as OutputError (OutputError(Parse))
import Myo.Output.Data.OutputEvent (OutputEvent)
import Myo.Output.Data.OutputParser (OutputParser(OutputParser))
import Myo.Output.Data.ParsedOutput (ParsedOutput)
import Myo.Output.Lang.Haskell.Data.HaskellEvent (EventType, HaskellEvent(HaskellEvent))
import qualified Myo.Output.Lang.Haskell.Data.HaskellEvent as EventType (EventType(..))
import Myo.Output.Lang.Haskell.Report (haskellReport)

colon :: CharParsing m => m Char
colon =
  char ':'

ws :: TokenParsing m => m ()
ws =
  skipOptional whiteSpace

locationLine ::
  Monad m =>
  CharParsing m =>
  TokenParsing m =>
  m (Location, EventType)
locationLine = do
  path <- manyTill anyChar (try $ choice [newline, colon])
  lineno <- natural <* colon
  colno <- natural <* colon
  skipOptional whiteSpace
  tpe <- choice [EventType.Error <$ string "error", EventType.Warning <$ string "warning"]
  _ <- colon
  ws
  skipOptional (brackets (many $ noneOf "]"))
  ws
  return (Location path (fromIntegral lineno) (Just (fromIntegral colno)), tpe)

emptyLine :: Monad m => CharParsing m => m Char
emptyLine =
  newline *> newline

dot :: CharParsing m => m Char
dot =
  char '•'

singleMessage ::
  Monad m =>
  CharParsing m =>
  m (NonEmpty String)
singleMessage =
  pure <$> manyTill anyChar (choice [void emptyLine, eof])

multiMessage ::
  Monad m =>
  CharParsing m =>
  TokenParsing m =>
  LookAheadParsing m =>
  m (NonEmpty String)
multiMessage = do
  head <- part
  tail <- many part
  return $ head :| tail
  where
    part = ws *> dot *> ws *> manyTill anyChar (choice [void $ lookAhead dot, void emptyLine, eof])

event ::
  Monad m =>
  CharParsing m =>
  TokenParsing m =>
  LookAheadParsing m =>
  m HaskellEvent
event = do
  (location, tpe) <- locationLine
  msgs <- choice [multiMessage, singleMessage]
  skipMany newline
  return $ HaskellEvent location tpe (Text.pack <$> msgs)

parseHaskellErrors ::
  Monad m =>
  CharParsing m =>
  TokenParsing m =>
  LookAheadParsing m =>
  m [HaskellEvent]
parseHaskellErrors =
  many event

parseHaskell :: Text -> Either OutputError ParsedOutput
parseHaskell =
  haskellReport <=< mapLeft OutputError.Parse . parseOnly parseHaskellErrors

haskellOutputParser :: OutputParser
haskellOutputParser =
  OutputParser parseHaskell