{-# LANGUAGE DataKinds, DeriveGeneric, FlexibleInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, OverloadedStrings, TypeOperators #-}

module Types where

import Control.Monad (replicateM)
import Data.Aeson (FromJSON(..), ToJSON(..), genericToJSON)
import Data.Aeson.Types (defaultOptions)
import Data.Char (chr)
import Data.Ix (inRange)
import Data.Text.Lazy (Text)
import GHC.Generics (Generic)
import qualified Data.Text.Lazy as T
import Servant (Capture, FromText(..), Get, JSON, Post, Put, Raw, QueryParam, ReqBody, ToText(..), (:<|>), (:>))
import Servant.Docs (DocCapture(..), DocQueryParam(..), ParamKind(..), ToCapture, ToParam, ToSample, toCapture, toParam, toSample)
import Test.QuickCheck (Arbitrary, arbitrary, choose, elements, suchThat)


type VehicleAPI =
       "vehicles" :> "all"                                              :> Get  '[JSON] [Vehicle]
  :<|> "vehicles" :> Capture "id" CaptureInt                            :> Get  '[JSON] Vehicle
  :<|> "vehicles" :>                            ReqBody '[JSON] Vehicle :> Post '[JSON] Vehicle
  :<|> "vehicles" :> Capture "id" CaptureInt :> ReqBody '[JSON] Vehicle :> Put  '[JSON] Vehicle
  -----
  :<|> "vehicles" :> "issues" :> Capture "id" CaptureInt :> QueryParam "sortBy" SortBy :> Get '[JSON] [Issue]
  :<|> "vehicles" :> "issues" :> Capture "id" CaptureInt :> ReqBody '[JSON] [Issue]    :> Put '[JSON] [Issue]


newtype CaptureInt = CaptureInt { fromCaptureInt :: Int } deriving (Eq, FromText, Generic, Show, ToText)


type VehicleAPIWithDocs = VehicleAPI :<|> Raw


data Vehicle = Vehicle { vin    :: Text
                       , year   :: Int
                       , model  :: Text
                       , issues :: [Issue] } deriving (Eq, Generic, Show)


data Issue = Issue { issueType :: IssueType
                   , priority  :: Priority } deriving (Eq, Generic, Show)


data IssueType = Battery
               | Brakes
               | Electrical deriving (Bounded, Enum, Eq, Generic, Show, Ord)


data Priority = High | Med | Low deriving (Bounded, Enum, Eq, Generic, Show, Ord)


data SortBy = ByType | ByPriority


instance FromText SortBy where
  fromText "type"     = Just ByType
  fromText "priority" = Just ByPriority
  fromText _          = Nothing


instance ToText SortBy where
  toText ByType     = "type"
  toText ByPriority = "priority"


instance FromJSON Issue
instance FromJSON IssueType
instance FromJSON Priority
instance FromJSON Vehicle
-- Depending on the version of aeson used, you may not need these "where" blocks.
instance ToJSON   Issue     where
  toJSON = genericToJSON defaultOptions
instance ToJSON   IssueType where
  toJSON = genericToJSON defaultOptions
instance ToJSON   Priority  where
  toJSON = genericToJSON defaultOptions
instance ToJSON   Vehicle   where
  toJSON = genericToJSON defaultOptions


instance Arbitrary Vehicle   where
  arbitrary = Vehicle <$> v <*> y <*> m <*> is
    where
      v  = let genVinChar = chr <$> suchThat (choose (48, 90)) (not . inRange (58, 64))
           in T.pack <$> replicateM 17 genVinChar
      y  = choose (1980, 2017)
      m  = elements [ "M. Plus", "Void", "Pure", "DeLorean" ]
      is = choose (0, 5) >>= \n -> replicateM n arbitrary
instance Arbitrary Issue     where
  arbitrary = Issue <$> arbitrary <*> arbitrary
instance Arbitrary IssueType where
  arbitrary = elements [ minBound .. ]
instance Arbitrary Priority  where
  arbitrary = elements [ minBound .. ]


-- ==================================================
-- Instances concerning doc generation:


-- Instantiate ToCapture to provide info regarding the meaning of a Capture.
instance ToCapture (Capture "id" CaptureInt) where
  toCapture _ = DocCapture "id"                    -- name
                           "(integer) Vehicle id." -- description


-- Instantiate ToSample to provide sample data used in documentation.
instance ToSample Vehicle Vehicle where
  toSample _ = Just Vehicle { vin = "vin", year = 1985, model = "DeLorean", issues = issueList }


issueList :: [Issue]
issueList = [ Issue Battery High, Issue Brakes Low ]


instance ToSample [Vehicle] [Vehicle] where
  toSample _ = Just [ Vehicle { vin = "vin", year = 1985, model = "DeLorean", issues = issueList } ]


instance ToSample [Issue] [Issue] where
  toSample _ = Just [ Issue Battery High ]


-- Instantiate ToParam to provide info regarding the meaning of a QueryParam.
instance ToParam (QueryParam "sortBy" SortBy) where
  toParam _ = DocQueryParam "sortBy"                                        -- name
                            [ "ByType", "ByPriority" ]                      -- example values
                            "Criteria by which to sort the list of issues." -- description
                            Normal                                          -- "Normal", "List" or "Flag"
-- Note: Use "List" for GET parameters with multiple values. Use "Flag" for a "QueryFlag", i.e a value-less GET parameter.
