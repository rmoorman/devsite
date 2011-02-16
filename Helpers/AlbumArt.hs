{-# LANGUAGE CPP #-}
-------------------------------------------------------------------------------
-- |
-- Module      :  Helpers.AlbumArt
-- Copyright   :  (c) Patrick Brisbin 2010 
-- License     :  as-is
--
-- Maintainer  :  pbrisbin@gmail.com
-- Stability   :  unstable
-- Portability :  unportable
--
-------------------------------------------------------------------------------
module Helpers.AlbumArt (getAlbumUrl) where

import Yesod
import Data.Char        (toLower)
import System.Directory (doesFileExist)

coverDir :: String
coverDir = "static/covers/"

fileRoot :: String
fileRoot = "/srv/http/"

urlRoot :: String
#ifdef PROD
urlRoot = "/"
#else
urlRoot = "//pbrisbin.com/"
#endif

extension :: String
extension = ".jpg"

fixFilename :: String -> String
fixFilename = filter (`elem` goodChars) . rmSpaces . map toLower
    where
        goodChars  = ['a'..'z'] ++ ['0'..'9'] ++ "_.-"

        rmSpaces []          = []
        rmSpaces (' ': rest) = '_': rmSpaces rest
        rmSpaces (x  : rest) = x  : rmSpaces rest

getAlbumUrl :: (Yesod m) => (String,String) -> GHandler s m (Maybe String)
getAlbumUrl (artist,album) = liftIO $ do
    let filename = coverDir ++ (fixFilename $ artist ++ " " ++ album) ++ extension
    exists <- doesFileExist $ fileRoot ++ filename
    if exists
        -- add root anchor b/c of subsite
        then return . Just $ urlRoot ++ filename
        else return Nothing
