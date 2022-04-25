
module CheckTest where

import Control.Monad
import Data.Char (chr, isHexDigit)
import Data.FileEmbed
import Data.Foldable (for_)
import Data.Map (fromList)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Read (hexadecimal)
import Data.Void

import Hedgehog
import Test.Hspec
import Test.Hspec.Megaparsec
import Test.Tasty.Hspec

import VerifPal.Types
import VerifPal.Check (process, ModelState(..), emptyModelState, ModelError(..), ProcessingCounter)
import VerifPal.Parser
import Data.Map (Map)
import qualified Data.Map as Map

import Cases

shouldNotFail modelState =
  msErrors modelState `shouldBe` []

shouldFail modelState =
  msErrors modelState `shouldNotBe` []

spec_parsePrincipal :: Spec
spec_parsePrincipal = do
  describe "process" $ do
    it "validates data/alice1.vp" $
      process alice1modelast `shouldBe`
      ModelState {
          msPrincipalConstants = fromList [("Alice",fromList [(Constant {constantName = "a"},(Generates,3)),(Constant {constantName = "c0"},(Public,0)),(Constant {constantName = "c1"},(Public,1)),(Constant {constantName = "m1"},(Private,2))])],
          msProcessingCounter = 4,
          msConstants = fromList [
              (Constant {constantName = "a"},Generates),
              (Constant {constantName = "c0"},Public),
              (Constant {constantName = "c1"},Public),
              (Constant {constantName = "m1"},Private)
          ], msErrors = [], msQueryResults = []}

shouldOverlapWith modelState constant =
  msErrors modelState `shouldContain`
    [OverlappingConstant constant "can't generate the same thing twice"]

shouldMissConstant modelState (constantName, errorText) =
  -- TODO this way of testing for the Text of the missingconstant is not great.
  msErrors modelState `shouldContain`
    [MissingConstant (Constant constantName) errorText]

shouldHave modelState (principalName, constants) =
  case Map.lookup principalName (msPrincipalConstants modelState) of
    Nothing -> fail "Principal not found" -- True `shouldBe` False
    Just principalMap ->
      forM_ constants (\constant -> Map.member constant principalMap `shouldBe` True)

shouldHaveEquivalence modelState wantedConstants =
  msQueryResults modelState `shouldSatisfy` any predicate
  where
    predicate (Query (EquivalenceQuery actualConstants) _queryOptions, True) =
      actualConstants == map (\c -> Constant c) wantedConstants
    predicate _ = False

shouldHaveFresh modelState constant =
  msQueryResults modelState `shouldSatisfy` any isFresh
  where
    isFresh (Query (FreshnessQuery constant2) _queryOptions, True) =
      Constant constant == constant2
    isFresh _ = False

shouldHaveNotFresh modelState constant =
  msQueryResults modelState `shouldSatisfy` any isNotFresh
  where
    isNotFresh (Query (FreshnessQuery constant2) _queryOptions, False) =
      Constant constant == constant2
    isNotFresh _ = False

mkModelState :: [(Text, Knowledge)] -> ModelState
mkModelState constants = ModelState
  { msConstants = mkConstants constants
  , msPrincipalConstants = Map.empty
  , msProcessingCounter = 0
  , msQueryResults = []
  , msErrors = []
  }

mkConstants :: [(Text, Knowledge)] -> Map Constant Knowledge
mkConstants constants =
  Map.fromList [ (Constant name, knowledge) | (name, knowledge) <- constants ]

mkPrincipalMap:: [(Text, Knowledge, ProcessingCounter)] -> Map Constant (Knowledge, ProcessingCounter)
mkPrincipalMap constants = Map.fromList
  [ (Constant name, (knowledge, count)) | (name, knowledge, count) <- constants ]

spec_process :: Spec
spec_process = do
  describe "process" $ do
    it "validates data/alice1.vp" $ do
      let modelState = process alice1modelast
      modelState `shouldHave` ("Alice", Constant <$> ["a", "c0", "c1", "m1"])
      msConstants modelState `shouldBe`
        mkConstants [("a", Generates), ("c0", Public), ("c1", Public), ("m1", Private)]

    it "rejects model with duplicates 1" $ do
      shouldNotFail (process dup1model)

    it "rejects model with duplicates 2" $ do
      process dup2model `shouldOverlapWith` Constant "x"

    it "rejects model with duplicates 3" $ do
      shouldNotFail (process dup3model)

    it "rejects model with duplicates 4" $ do
      process dup4model `shouldOverlapWith` Constant "x"

    it "validates data/abknows.vp" $ do
      let modelState = process abknowsast
      modelState `shouldHave` ("A", Constant <$> ["x"])
      modelState `shouldHave` ("B", Constant <$> ["x"])
      msConstants modelState `shouldBe` mkConstants [("x", Private)]

    it "rejects model with conflicting public/private knows" $
      process bad_publicprivate_ast `shouldOverlapWith` Constant "x"

    it "rejects model with conflicting generates/knows private" $
      process bad_generatesknows_ast `shouldOverlapWith` Constant "x"

    it "rejects model with conflicting knows private/knows password" $
      process bad_passwordprivate_ast `shouldOverlapWith` Constant "x"

    it "validates data/abknows.vp" $
      process abknowsast `shouldBe` ModelState {msConstants = fromList [(Constant {constantName = "x"},Private)], msPrincipalConstants = fromList [("A",fromList [(Constant {constantName = "x"},(Private,0))]),("B",fromList [(Constant {constantName = "x"},(Private,1))])],
          msProcessingCounter = 2, msQueryResults = [], msErrors = [NotImplemented "confidentiality query not implemented"]}

    it "rejects model with conflicting knows public/knows private" $
      process bad_publicprivate_ast `shouldOverlapWith` Constant "x"

    it "rejects model with conflicting generates/knows private" $
      process bad_generatesknows_ast `shouldOverlapWith` Constant "x"

    it "rejects model with conflicting knows private/knows password" $
      process bad_passwordprivate_ast `shouldOverlapWith` Constant "x"

    it "rejects model with missing constant in confidentialityquery" $
      process bad_undefinedconstant_in_cfquery_ast `shouldMissConstant` ("y","TODO")

    it "rejects model that sends constant before it's defined" $ do
      let modelState = process bad_early_constant_ast
      modelState `shouldMissConstant`("yo","sender reference to unknown constant")

    it "rejects model that references undefined constant" $ do
      let modelState = process bad_assignment_to_undefined_ast
      shouldFail modelState
      modelState `shouldMissConstant` ("b","assignment to unbound constant")

spec_freshness :: Spec
spec_freshness = do
  describe "process" $ do
    it "checks simple freshness query" $ do
      let modelState = process freshness1model
      modelState `shouldHaveFresh` "x"
      modelState `shouldHaveNotFresh` "y"

    it "validates data/knows_freshness.vp" $ do
      let modelState = process knows_freshness_ast
      shouldNotFail modelState
      modelState `shouldHaveFresh` "a"

    it "validates data/freshness_aliased.vp" $ do
      let modelState = process freshness_aliased_ast
      shouldNotFail modelState
      modelState `shouldHaveFresh` "a"
      modelState `shouldHaveFresh` "b"
      modelState `shouldHaveFresh` "c"

    it "validates data/freshness_concat.vp" $ do
      let modelState = process freshness_concat_ast
      shouldNotFail modelState
      modelState `shouldHaveFresh` "b"
      modelState `shouldHaveFresh` "c"
      modelState `shouldHaveFresh` "d"

    it "rejects freshness query on (knows private)" $ do
      let modelState = process bad_knows_freshness_ast
      shouldNotFail modelState
      modelState `shouldHaveNotFresh` "a"

spec_equivalence :: Spec
spec_equivalence = do
  describe "process" $ do
    it "checks equivalence1 query" $ do
      let modelState = process equivalence1_ast
      shouldNotFail modelState
      modelState `shouldBe` ModelState {
        msConstants = fromList [
            (Constant {constantName = "encrypted"},Assignment (EPrimitive (ENC (EConstant (Constant {constantName = "key"})) (EConstant (Constant {constantName = "msg"}))) HasntQuestionMark)),
            (Constant {constantName = "from_a"},Assignment (EPrimitive (DEC (EConstant (Constant {constantName = "key"})) (EConstant (Constant {constantName = "encrypted"}))) HasntQuestionMark)),
            (Constant {constantName = "key"},Private),
            (Constant {constantName = "msg"},Private)],
        msPrincipalConstants = fromList [("A",fromList [(Constant {constantName = "encrypted"},(Assignment (EPrimitive (ENC (EConstant (Constant {constantName = "key"})) (EConstant (Constant {constantName = "msg"}))) HasntQuestionMark),2)),(Constant {constantName = "key"},(Private,1)),(Constant {constantName = "msg"},(Private,0))]),("B",fromList [(Constant {constantName = "encrypted"},(Assignment (EPrimitive (ENC (EConstant (Constant {constantName = "key"})) (EConstant (Constant {constantName = "msg"}))) HasntQuestionMark),7)),(Constant {constantName = "from_a"},(Assignment (EPrimitive (DEC (EConstant (Constant {constantName = "key"})) (EConstant (Constant {constantName = "encrypted"}))) HasntQuestionMark),8)),(Constant {constantName = "key"},(Private,5))])],
        msProcessingCounter = 11,
        msErrors = [],
        msQueryResults = [(Query {queryKind = EquivalenceQuery {equivalenceConstants = [Constant {constantName = "msg"},Constant {constantName = "from_a"}]}, queryOptions = Nothing},True)]}
      modelState `shouldHaveEquivalence` ["msg", "from_a"]
    it "checks equivalence2 query" $ do
      let modelState = process equivalence2_ast
      shouldNotFail modelState
      modelState `shouldHaveEquivalence` ["a", "b_a"]
      modelState `shouldHaveEquivalence` ["b", "b_b"]
      modelState `shouldHaveEquivalence` ["c", "b_c"]
    it "checks equivalence3 query" $ do
      let modelState = process equivalence3_ast
      shouldNotFail modelState
      modelState `shouldHaveEquivalence` ["a", "b"]
      modelState `shouldHaveEquivalence` ["c", "d"]
    it "checks equations2 queries" $ do
      let modelState = process equations2_ast
      shouldNotFail modelState
      -- TODO should NOT have: modelState `shouldHaveEquivalence` ["a", "b"]
      modelState `shouldHaveEquivalence` ["gyx", "gxy"]
