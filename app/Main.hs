{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent
import Control.Concurrent.Async
import Control.Concurrent.MVar
import Control.Concurrent.STM
import Control.Monad
import Data.Atomics
import Data.Atomics.Counter
import Data.IORef
import Gauge.Main
import qualified System.Remote.Monitoring as E

main :: IO ()
main = do
  E.forkServer "localhost" 8080

  ref <- newIORef (0 :: Int)
  mvar <- newMVar (0 :: Int)
  tvar <- newTVarIO (0 :: Int)
  newCounter <- newCounter 0
  maxCap <- getNumCapabilities
  print maxCap
  defaultMain $
    flip map [0 .. maxCap - 1] $ \n ->
      bgroup
        (show (n + 1) ++ " threads")
        [ bench "IORef" $
            whnfIO $ do
              xs <- forM [0 .. n] $ \i -> asyncOn i $
                replicateM_ 10000 $ do
                  b <- atomicModifyIORef ref $ \x -> let !x' = x + 1 in x' `seq` (x', ())
                  b `seq` return b
              mapM_ wait xs,
          bench "IORef strict" $
            whnfIO $ do
              xs <- forM [0 .. n] $ \i -> asyncOn i $
                replicateM_ 10000 $ atomicModifyIORef' ref $ \x -> (x + 1, ())
              mapM_ wait xs,
          bench "MVar" $
            whnfIO $ do
              xs <- forM [0 .. n] $ \i -> asyncOn i $
                replicateM_ 10000 $ modifyMVar_ mvar $ \x -> let !x' = x + 1 in return $! x'
              mapM_ wait xs,
          bench "TVar" $
            whnfIO $ do
              xs <- forM [0 .. n] $ \i -> asyncOn i $
                replicateM_ 10000 $ atomically $ modifyTVar' tvar $ \x -> x + 1
              mapM_ wait xs,
          bench "atomicModifyIORefCAS" $
            whnfIO $ do
              xs <- forM [0 .. n] $ \i -> asyncOn i $
                replicateM_ 10000 $ do
                  b <- atomicModifyIORefCAS ref $ \x -> let !x' = x + 1 in x' `seq` (x', ())
                  b `seq` return b
              mapM_ wait xs,
          bench "AtomicCounter" $
            whnfIO $ do
              xs <- forM [0 .. n] $ \i ->
                asyncOn i $
                  replicateM_ 10000 $ incrCounter 1 newCounter
              mapM_ wait xs
        ]
