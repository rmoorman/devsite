module Helpers.Admin
    ( requireAdmin
    , maybeAdmin
    ) where

import Import
import Control.Monad (unless)

requireAdmin :: Handler ()
requireAdmin = do
    (Entity _ u) <- requireAuth
    unless (userAdmin u) $ permissionDenied "User is not an admin"

maybeAdmin :: Handler Bool
maybeAdmin = do
    mu <- maybeAuth
    return $ case mu of
        Just (Entity _ u) -> userAdmin u
        _                 -> False