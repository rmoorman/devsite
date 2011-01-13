-------------------------------------------------------------------------------
-- |
-- Module      :  Controller
-- Copyright   :  (c) Patrick Brisbin 2010 
-- License     :  as-is
--
-- Maintainer  :  pbrisbin@gmail.com
-- Stability   :  unstable
-- Portability :  unportable
--
-------------------------------------------------------------------------------
module Controller (withServer) where

import Yesod
import DevSite
import Handlers

import Helpers.Posts       (migratePosts)
import Helpers.Auth.HashDB (migrateUsers)
import Helpers.MPC

import Yesod.Helpers.Auth
import Database.Persist.GenericSql

import qualified Settings

-- | Instantiate the Yesod route types
mkYesodDispatch "DevSite" resourcesDevSite

-- | Create a Wai App of the site
withServer :: (Application -> IO a) -> IO a
withServer f = Settings.withConnectionPool $ \p -> do
    runSqlPool (runMigration migratePosts) p
    runSqlPool (runMigration migrateUsers) p
    let h = DevSite p
    toWaiApp h >>= f
