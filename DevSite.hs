{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies    #-}
{-# LANGUAGE QuasiQuotes     #-}
-------------------------------------------------------------------------------
-- |
-- Module      :  DevSite
-- Copyright   :  (c) Patrick Brisbin 2010 
-- License     :  as-is
--
-- Maintainer  :  pbrisbin@gmail.com
-- Stability   :  unstable
-- Portability :  unportable
--
-------------------------------------------------------------------------------
module DevSite where

import Yesod
import Yesod.Helpers.Auth
import Yesod.Helpers.MPC
import Yesod.Helpers.Stats
import Yesod.Form.Core (GFormMonad(..))

import Data.Char (toLower)
import Data.List (intercalate)
import Database.Persist.GenericSql

import Helpers.RssFeed
import Helpers.Auth.HashDB

import qualified Settings

-- | The main site type
data DevSite = DevSite { connPool :: ConnectionPool }

type Handler     = GHandler DevSite DevSite
type Widget      = GWidget  DevSite DevSite
type FormMonad a = GFormMonad DevSite DevSite a

-- | Define all of the routes and handlers
mkYesodData "DevSite" [$parseRoutes|
/      RootR  GET
/about AboutR GET
/stats StatsR GET

/manage                ManagePostsR GET POST
/manage/edit/#String   EditPostR    GET POST
/manage/delete/#String DelPostR     GET

/posts         PostsR GET
/posts/#String PostR  GET
/tags          TagsR  GET
/tags/#String  TagR   GET

/feed         FeedR    GET
/feed/#String FeedTagR GET

/favicon.ico FaviconR GET
/robots.txt  RobotsR  GET

/auth     AuthR Auth getAuth
/apps/mpc MpcR  MPC  getMPC
|]

-- | Make my site an instance of Yesod so we can actually use it
instance Yesod DevSite where 
    approot _ = Settings.approot

    -- | handle authentication
    authRoute _ = Just $ AuthR LoginR

    -- | override defaultLayout to provide an overall template and css
    --   file
    defaultLayout widget = do
        mmesg <- getMessage
        pc    <- widgetToPageContent $ do
            widget
            rssLink FeedR "rss feed"
            addCassius $(Settings.cassiusFile "root-css")
            -- todo: ifIsSubSite, add breadcrumbs here
        hamletToRepHtml [$hamlet|
            !!!
            %html!lang="en"
                %head
                    %meta!name="author"!content="pbrisbin"
                    %meta!name="description"!content="pbrisbin dot com"
                    %meta!http-equiv="Content-Type"!content="text/html; charset=UTF-8"
                    ^pageHead.pc^
                    %title $pageTitle.pc$
                %body
                    $maybe mmesg msg
                        #message 
                            %p.centered $msg$
                    #body
                        ^pageBody.pc^
                    #footer
                        ^footerTemplate^
            |]

-- | Make my site an instance of breadcrumbs so that i can simply call
--   the breadcrumbs function to get automagical breadcrumb links
instance YesodBreadcrumbs DevSite where
    -- root is the parent node
    breadcrumb RootR  = return ("root" , Nothing) 

    -- about and stats go back home
    breadcrumb AboutR = return ("about", Just RootR)
    breadcrumb StatsR = return ("stats", Just RootR)

    -- all posts goes back home and individual posts go to all posts
    breadcrumb PostsR       = return ("all posts", Just RootR)
    breadcrumb (PostR slug) = return (format slug, Just PostsR)

        where
            -- switch underscores with spaces
            format []         = []
            format ('_':rest) = ' ': format rest
            format (x:rest)   = x  : format rest

    -- all tags goes back home and individual tags go to all tags
    breadcrumb TagsR      = return ("all tags", Just RootR)
    breadcrumb (TagR tag) = return (map toLower tag, Just TagsR)

    -- management pages
    breadcrumb ManagePostsR     = return ("manage posts", Just RootR)
    breadcrumb (EditPostR slug) = return ("edit post", Just ManagePostsR)

    -- subsites
    breadcrumb (AuthR _) = return ("login", Just RootR)
    breadcrumb (MpcR  _) = return ("mpc"  , Just RootR)

    -- be sure to fail noticably so i fix it when it happens
    breadcrumb _ = return ("404", Just RootR)

-- | Make my site an instance of Persist so that i can store post
--   metatdata in a db
instance YesodPersist DevSite where
    type YesodDB DevSite = SqlPersist
    runDB db = fmap connPool getYesod >>= runSqlPool db

-- | Handle authentication with my custom HashDB plugin
instance YesodAuth DevSite where
    type AuthId DevSite = UserId

    loginDest  _ = RootR
    logoutDest _ = RootR
    getAuthId    = getAuthIdHashDB AuthR 
    showAuthId _ = showIntegral
    readAuthId _ = readIntegral
    authPlugins  = [authHashDB]

-- | In-browser mpd controls
instance YesodMPC DevSite where
    mpdConfig  = return . Just $ MpdConfig "192.168.0.5" 6600 ""
    authHelper = requireAuth >>= \_ -> return ()

-- | Track statistics
instance YesodStats DevSite where
    blacklist = return ["192.168.0.1","66.30.118.211"]

-- | Add breadcrumbs to a page
addBreadcrumbs :: Widget ()
addBreadcrumbs = do
    (t, h) <- liftHandler breadcrumbs
    addHamlet [$hamlet|
    #breadcrumbs
        %p
            $forall h node
                %a!href=@fst.node@ $snd.node$ 
                \ / 
            \ $t$
    |]

-- | Add a list of words to the html head as keywords
addKeywords :: [String] -> Widget ()
addKeywords keywords = addHamletHead [$hamlet| %meta!name="keywords"!content=$format.keywords$ |]
    where 
        format :: [String] -> Html
        format = string . intercalate ", "

-- | Standard foot
footerTemplate :: Hamlet DevSiteRoute
footerTemplate = [$hamlet|
    %p
        %a!href=@RootR@ pbrisbin
        \ dot com 2010 
        %span.float_right
            powered by 
            %a!href="http://docs.yesodweb.com/" yesod
    |]
