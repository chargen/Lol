{-|
Module      : Crypto.Lol.Benchmarks.CycBenches
Description : Benchmarks for the 'Cyc' interface.
Copyright   : (c) Eric Crockett, 2011-2017
                  Chris Peikert, 2011-2017
License     : GPL-3
Maintainer  : ecrockett0@email.com
Stability   : experimental
Portability : POSIX

Benchmarks for the 'Cyc' interface.
-}

{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}

{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

module Crypto.Lol.Benchmarks.CycBenches (cycBenches1, cycBenches2) where

import Control.Applicative
import Control.Monad.Random hiding (lift)

import Crypto.Lol
import Crypto.Lol.Utils.Benchmarks
import Crypto.Lol.Types
import Crypto.Random

-- | Benchmarks for single-index 'Cyc' operations.
-- There must be a CRT basis for \(O_m\) over @r@.
{-# INLINABLE cycBenches1 #-}
cycBenches1 :: (Monad rnd, _) => Proxy '(t,m,r) -> Proxy gen -> rnd Benchmark
cycBenches1 ptmr pgen = benchGroup "Cyc" $ ($ ptmr) <$> [
  genBenchArgs "zipWith (*)" bench_mul,
  genBenchArgs "crt" bench_crt,
  genBenchArgs "crtInv" bench_crtInv,
  genBenchArgs "l" bench_l,
  genBenchArgs "lInv" bench_lInv,
  genBenchArgs "*g Pow" bench_mulgPow,
  genBenchArgs "*g Dec" bench_mulgDec,
  genBenchArgs "*g CRT" bench_mulgCRT,
  genBenchArgs "divG Pow" bench_divGPow,
  genBenchArgs "divG Dec" bench_divGDec,
  genBenchArgs "divG CRT" bench_divGCRT,
  genBenchArgs "lift" bench_liftPow,
  genBenchArgs "error" (bench_errRounded 0.1) . addGen pgen
  ]

-- | Benchmarks for inter-ring 'Cyc' operations.
-- There must be a CRT basis for \(O_{m'}\) over @r@.
{-# INLINABLE cycBenches2 #-}
cycBenches2 :: (Monad rnd, _) => Proxy '(t,m,m',r) -> rnd Benchmark
cycBenches2 p = benchGroup "Cyc" $ ($ p) <$> [
  genBenchArgs "twacePow" bench_twacePow,
  genBenchArgs "twaceDec" bench_twaceDec,
  genBenchArgs "twaceCRT" bench_twaceCRT,
  genBenchArgs "embedPow" bench_embedPow,
  genBenchArgs "embedDec" bench_embedDec,
  genBenchArgs "embedCRT" bench_embedCRT
  ]

{-# INLINABLE bench_mul #-}
-- no CRT conversion, just coefficient-wise multiplication
bench_mul :: _ => Cyc t m r -> Cyc t m r -> Bench '(t,m,r)
bench_mul a b =
  let a' = adviseCRT a
      b' = adviseCRT b
  in bench (a' *) b'

{-# INLINABLE bench_crt #-}
-- convert input from Pow basis to CRT basis
bench_crt :: _ => Cyc t m r -> Bench '(t,m,r)
bench_crt = bench adviseCRT . advisePow

{-# INLINABLE bench_crtInv #-}
-- convert input from CRT basis to Pow basis
bench_crtInv :: _ => Cyc t m r -> Bench '(t,m,r)
bench_crtInv = bench advisePow . adviseCRT

{-# INLINABLE bench_l #-}
-- convert input from Dec basis to Pow basis
bench_l :: _ => Cyc t m r -> Bench '(t,m,r)
bench_l = bench advisePow . adviseDec

{-# INLINABLE bench_lInv #-}
-- convert input from Pow basis to Dec basis
bench_lInv :: _ => Cyc t m r -> Bench '(t,m,r)
bench_lInv = bench adviseDec  . advisePow

{-# INLINE bench_liftPow #-}
-- lift an element in the Pow basis
bench_liftPow :: _ => Cyc t m r -> Bench '(t,m,r)
bench_liftPow = bench (liftCyc Pow) . advisePow

{-# INLINABLE bench_mulgPow #-}
-- multiply by g when input is in Pow basis
bench_mulgPow :: _ => Cyc t m r -> Bench '(t,m,r)
bench_mulgPow = bench mulG . advisePow

{-# INLINABLE bench_mulgDec #-}
-- multiply by g when input is in Dec basis
bench_mulgDec :: _ => Cyc t m r -> Bench '(t,m,r)
bench_mulgDec = bench mulG . adviseDec

{-# INLINABLE bench_mulgCRT #-}
-- multiply by g when input is in CRT basis
bench_mulgCRT :: _ => Cyc t m r -> Bench '(t,m,r)
bench_mulgCRT = bench mulG . adviseCRT

{-# INLINABLE bench_divGPow #-}
-- divide by g when input is in Pow basis
bench_divGPow :: _ => Cyc t m r -> Bench '(t,m,r)
bench_divGPow = bench divG . advisePow . mulG

{-# INLINABLE bench_divGDec #-}
-- divide by g when input is in Dec basis
bench_divGDec :: _ => Cyc t m r -> Bench '(t,m,r)
bench_divGDec = bench divG . adviseDec . mulG

{-# INLINABLE bench_divGCRT #-}
-- divide by g when input is in CRT basis
bench_divGCRT :: _ => Cyc t m r -> Bench '(t,m,r)
bench_divGCRT = bench divG . adviseCRT

{-# INLINABLE bench_errRounded #-}
-- generate a rounded error term
bench_errRounded :: forall (t :: Factored -> * -> *) m (r :: *) gen . (Fact m, CryptoRandomGen gen, _)
  => Double -> Bench '(t,m,r,gen)
bench_errRounded v = benchIO $ do
  gen <- newGenIO
  return $ evalRand (roundedGaussian v :: Rand (CryptoRand gen) (Cyc t m (LiftOf r))) gen

-- These need a hint on the kind of the output index. Could use a kind annotation on the forall'd var.
{-# INLINE bench_twacePow #-}
bench_twacePow :: forall t m m' r . (Fact m, _)
  => Cyc t m' r -> Bench '(t,m,m',r)
bench_twacePow = bench (twace :: Cyc t m' r -> Cyc t m r) . advisePow

{-# INLINE bench_twaceDec #-}
bench_twaceDec :: forall t m m' r . (Fact m, _)
  => Cyc t m' r -> Bench '(t,m,m',r)
bench_twaceDec = bench (twace :: Cyc t m' r -> Cyc t m r) . adviseDec

{-# INLINE bench_twaceCRT #-}
bench_twaceCRT :: forall t m m' r . (Fact m, _)
  => Cyc t m' r -> Bench '(t,m,m',r)
bench_twaceCRT = bench (twace :: Cyc t m' r -> Cyc t m r) . adviseCRT

{-# INLINE bench_embedPow #-}
bench_embedPow :: forall t m m' r . (Fact m', _)
  => Cyc t m r -> Bench '(t,m,m',r)
bench_embedPow = bench (advisePow . embed :: Cyc t m r -> Cyc t m' r) . advisePow

{-# INLINE bench_embedDec #-}
bench_embedDec :: forall t m m' r . (Fact m', _)
  => Cyc t m r -> Bench '(t,m,m',r)
bench_embedDec = bench (adviseDec . embed :: Cyc t m r -> Cyc t m' r) . adviseDec

{-# INLINE bench_embedCRT #-}
bench_embedCRT :: forall t m m' r . (Fact m', _)
  => Cyc t m r -> Bench '(t,m,m',r)
bench_embedCRT = bench (adviseCRT . embed :: Cyc t m r -> Cyc t m' r) . adviseCRT
