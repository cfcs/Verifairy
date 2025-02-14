
module ParserTest where

import Control.Monad
import Data.Char (chr, isHexDigit)
import Data.FileEmbed
import Data.Foldable (for_)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Read (hexadecimal)
import Data.Void

import VerifPal.Types
import VerifPal.Parser (parsePrincipal, parseModelPart, parseModel)

import Hedgehog.Gen
import Hedgehog.Range
import Test.Hspec
import Test.Hspec.Megaparsec
import Test.Tasty.Hspec
import Text.Megaparsec.Error
import Hedgehog
import Cases

hprop_doesntCrash :: Hedgehog.Property
hprop_doesntCrash =
  withTests 1000 $
  verifiedTermination $ property $ do
    random <- forAll $ Hedgehog.Gen.text (Hedgehog.Range.constant 0 300) Hedgehog.Gen.unicode
    let parsed = parseModel random
    parsed === parsed

spec_parsePrincipal :: Spec
spec_parsePrincipal = do
  describe "parsePrincipal" $ do
    it "parses data/alice1.vp" $
      parsePrincipal alice1 `shouldParse` alice1ast

    it "parses data/bob1.vp" $
      parsePrincipal bob1 `shouldParse` bob1ast

    it "parses data/equations1.vp" $
      parsePrincipal equations1 `shouldParse` equations1ast

  describe "parseModelPart" $ do
    it "parses data/alice1.vp" $
      parseModelPart alice1 `shouldParse` ModelPrincipal alice1ast

    it "parses data/message1.vp" $
      parseModelPart message1 `shouldParse` ModelMessage message1ast

    it "parses data/phase1.vp" $
      parseModelPart phase1 `shouldParse` ModelPhase phase1ast

  describe "parseModel" $ do
    it "parses data/alice1model.vp" $
      parseModel alice1model `shouldParse` alice1modelast

    it "parses data/bob1model.vp" $
      parseModel bob1model `shouldParse` bob1modelast

    it "parses data/simple1.vp" $
      parseModel simple1 `shouldParse` simple1ast

    it "parses data/simple1_complete_active.vp" $
      parseModel simple1_complete_active `shouldParse` simple1_complete_active_ast

    it "parses data/simple2.vp" $
      parseModel simple2 `shouldParse` simple2ast

    it "parses data/freshness1.vp" $
      parseModel freshness1 `shouldParse` freshness1model

    it "parses data/freshness2.vp" $
      parseModel freshness2 `shouldParse` freshness2ast

    it "parses data/abknows.vp" $
      parseModel abknows `shouldParse` abknowsast

    it "parses data/bad_publicprivate.vp" $
      parseModel bad_publicprivate `shouldParse` bad_publicprivate_ast

    it "parses data/bad_passwordprivate.vp" $
      parseModel bad_passwordprivate `shouldParse` bad_passwordprivate_ast

    it "parses foreign_models/verifpal/test/challengeresponse.vp" $
      parseModel challengeResponse `shouldParse` challengeResponseModel

    it "parses foreign_models/verifpal/test/ringsign.vp" $
      parseModel foreignRingSign `shouldParse` foreignRingSignModel

    it "parses data/knows_freshness.vp" $
      parseModel knows_freshness `shouldParse` knows_freshness_ast

    it "parses data/freshness_aliased.vp" $
      parseModel freshness_aliased `shouldParse` freshness_aliased_ast

    it "parses data/freshness_concat.vp" $
      parseModel freshness_concat `shouldParse` freshness_concat_ast

    it "parses data/abknows.vp" $
      parseModel abknows `shouldParse` abknowsast

    it "parses data/bad_publicprivate.vp" $
      parseModel bad_publicprivate `shouldParse` bad_publicprivate_ast

    it "parses data/bad_passwordprivate.vp" $
      parseModel bad_passwordprivate `shouldParse` bad_passwordprivate_ast

    it "parses data/bad_generatesknows.vp" $
      parseModel bad_generatesknows `shouldParse` bad_generatesknows_ast

    it "parses data/bad_undefinedconstant_in_cfquery.vp" $
      parseModel bad_undefinedconstant_in_cfquery `shouldParse` bad_undefinedconstant_in_cfquery_ast

    it "parses data/bad_early_constant.vp" $
      parseModel bad_early_constant `shouldParse` bad_early_constant_ast

    it "parses data/concat.vp" $
      parseModel model_concat `shouldParse` model_concat_ast

    it "parses data/bad_knows_freshness.vp" $
      parseModel bad_knows_freshness `shouldParse` bad_knows_freshness_ast

    it "parses data/equivalence1.vp" $
      parseModel equivalence1 `shouldParse` equivalence1_ast

    it "parses data/equivalence2.vp" $
      parseModel equivalence2 `shouldParse` equivalence2_ast

    it "parses data/equivalence3.vp" $
      parseModel equivalence3 `shouldParse` equivalence3_ast

    it "parses data/equivalence4.vp" $
      parseModel equivalence4 `shouldParse` equivalence4_ast

    it "parses data/equivalence5.vp" $
      parseModel equivalence5 `shouldParse` equivalence5_ast

    it "parses data/equations2.vp" $
      parseModel equations2 `shouldParse` equations2_ast

    it "parses data/confidentiality1.vp" $
      parseModel confidentiality1 `shouldParse` confidentiality1_ast

    it "parses data/confidentiality2.vp" $
      parseModel confidentiality2 `shouldParse` confidentiality2_ast

    --it "parses data/extraneous.vp" $
      -- TODO should NOT parse this; should be an error
      --  "a" `shouldBe` "a"
--      parseModel confidentiality2 `shouldBe` (Left (ParseErrorBundle(ParseError 1 2)))
