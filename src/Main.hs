{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}
module Main where

import Control.Concurrent
import Control.Monad
import Control.Monad.Identity
import Control.Monad.IO.Class
import Control.Monad.Ref
import Control.Monad.Trans.Class
import Control.Monad.Trans.Maybe
import Data.Dependent.Sum (DSum (..))
import Data.IORef
import qualified Data.Map.Lazy as Map
import Data.Maybe
import Data.Monoid ((<>))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import GHCJS.DOM hiding (runWebGUI)
import qualified GHCJS.DOM.Types as DOM
import GHCJS.DOM.Document
import GHCJS.DOM.Element
import GHCJS.DOM.Node
import Foreign.JavaScript.TH
import Graphics.UI.Gtk hiding (Widget, (:=>))
import Graphics.UI.Gtk.WebKit.Types hiding (Event, Widget, Text, Window)
import Graphics.UI.Gtk.WebKit.WebView
import Graphics.UI.Gtk.WebKit.WebSettings
import Graphics.UI.Gtk.WebKit.WebFrame
import Reflex
import Reflex.PerformEvent.Base
import Reflex.Dom hiding (Window)
import Reflex.Host.Class
import System.Directory

main :: IO ()
main = do
  forkIO $ initGUI >> mainGUI
  handleCommands Map.empty
  postGUIAsync mainQuit
  putStrLn "Killed the GUI thread."
  where
    handleCommands windowsByName = do
      line <- putStrLn "Command?" >> getLine
      case words line of
        ["create", windowName] -> do
          case Map.lookup windowName windowsByName of
            Just _ -> do
              putStrLn $ "A window named " ++ windowName ++ " already exists."
              handleCommands windowsByName
            Nothing -> do
              initialDisplayText <- putStrLn "Initial text?" >> TIO.getLine 
              window <- postGUISync $ startUpdatableTextWindow initialDisplayText
              putStrLn $ "Created a window named: " ++ windowName
              handleCommands $ Map.insert windowName window windowsByName
        ["update", windowName] -> do
          case Map.lookup windowName windowsByName of
            Just window -> do
              newDisplayText <- putStrLn "New text?" >> TIO.getLine
              result <- postGUISync $ trySetDisplayText window newDisplayText
              if result
                then do
                  putStrLn "Changed the text."
                  handleCommands windowsByName
                else do
                  putStrLn "Unable to update the text."
                  handleCommands $ Map.delete windowName windowsByName
            Nothing -> do
              putStrLn $ "No window name " ++ windowName ++ " exists."
              handleCommands windowsByName
        ["quit"] -> putStrLn "Goodbye."
        _ -> do
          putStrLn "Not a recognized command."
          handleCommands windowsByName

data UpdatableTextWindow =
  UpdatableTextWindow {
    trySetDisplayText :: T.Text -> IO Bool
  }

startUpdatableTextWindow :: T.Text -> IO UpdatableTextWindow
startUpdatableTextWindow initialDisplayText = do
  webView <- webViewNew
  
  do
    webFrame <- webViewGetMainFrame webView
    pwd <- getCurrentDirectory
    webFrameLoadString webFrame "" Nothing $ "file://" <> pwd <> "/"

  fireRef <- newIORef Nothing
  (displayTextUpdated, displayTextUpdatedTriggerRef) <- runSpiderHost $ do
    (ev, tr) <- newEventWithTriggerRef
    void $ subscribeEvent ev
    return (ev, tr)

  _ <- webView `on` loadFinished $ \_ -> do
    Just doc <- liftM (fmap DOM.castToHTMLDocument) $ webViewGetDomDocument webView
    Just body <- getBody doc
    (_, FireCommand fire) <-
      withWebViewSingleton webView $ \sWebView ->
        attachWidget' body sWebView $
          updatableTextWidget initialDisplayText displayTextUpdated
    writeIORef fireRef $ Just fire

  _ <- webView `on` objectDestroy $ writeIORef fireRef Nothing

  scrolledWindow <- scrolledWindowNew Nothing Nothing
  scrolledWindow `containerAdd` webView

  do
    window <- windowNew
    -- _ <- timeoutAddFull (yield >> return True) priorityHigh 10 -- not sure what this does; leaving it out for now
    window `containerAdd` scrolledWindow
    widgetShowAll window

  return $
    UpdatableTextWindow {
      trySetDisplayText = \newDisplayText -> fmap isJust . runMaybeT $ do
        fire <- MaybeT $ readIORef fireRef
        displayTextUpdatedTrigger <- MaybeT $ readRef displayTextUpdatedTriggerRef
        lift $ runSpiderHost $ fire [displayTextUpdatedTrigger :=> Identity newDisplayText] $ return ()
        return ()
    }

updatableTextWidget :: T.Text -> Event Spider T.Text -> Widget v ()
updatableTextWidget initialDisplayText displayTextUpdated =
  el "div" $ do
    displayText <- holdDyn initialDisplayText displayTextUpdated
    dynText displayText

