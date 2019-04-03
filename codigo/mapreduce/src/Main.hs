module Main where

import Control.Parallel.Strategies
import Data.List
import Data.List.Split
import Control.Monad
import Data.Ord

-- Funcoes auxiliares

-- | parmap utilizando strategias
parmap :: (NFData b) => (a -> b) -> [a] -> [b]
parmap f xs = fmap f xs `using` parList rdeepseq

-- | Ordena lista pela chave da tupla
sortByKey :: (Ord a) => [(a,t)] -> [(a,t)]
sortByKey = sortBy (comparing fst)

-- | Agrupa lista pela chave
groupByKey :: (Ord a) => [(a, t)] -> [[(a, t)]]
groupByKey = groupBy agrupaTupla

agrupaTupla :: (Eq a) => (a, t0) -> (a, t0) -> Bool
agrupaTupla (a1, b1) (a2, b2) = a1==a2

-- | ordena e depois agrupa
sortAndgroup :: (Eq a, Ord a) => [(a,t)] -> [[(a,t)]]
sortAndgroup = (groupByKey . sortByKey)

-- | Operador pipeline
(|>) = flip ($)


-- Map Reduce

type RDD a = [a]

-- | junta o resultado do Mapper e envia para o Reducer
shuffler :: (Eq a, Ord a) => RDD [(a,t)] -> RDD (a,[t])
shuffler = fmap shuffle . sortAndgroup . join
  where shuffle ((k,v):kvs) = (k, v : fmap snd kvs)

-- | Executa o mapper
runMapper :: (NFData k2, NFData v2) 
          =>  ((k1, v1) -> [(k2, v2)]) -- Mapper
          -> RDD [(k1,v1)]             -- Entrada
          -> RDD [(k2, v2)]            -- Saida
runMapper mapper rdd = join (parmap (fmap mapper) rdd) -- rdd >>= fmap mapper

-- | Executa o reducer
runReducer :: (NFData k2, NFData v2) 
           => ((k1, [v1]) -> (k2, v2))  -- Reducer
           -> RDD (k1, [v1])            -- Entrada
           -> RDD (k2, v2)              -- Saida
runReducer reducer = parmap reducer

-- | Cria um job
mrJob :: (NFData k2, NFData v2, NFData k3, NFData v3, Ord k2)
      => ((k1,v1) -> [(k2,v2)])      -- Mapper
      -> ((k2, [v2]) -> (k3, v3))    -- Reducer
      -> RDD [(k1,v1)]               -- Entrada
      -> RDD (k3, v3)                -- Saida
mrJob mapper reducer rdd = runMapper mapper rdd |> shuffler |> runReducer reducer


-- Exemplo de aplicacao

mapperTok :: (Integer, String) -> [(String, Integer)]
mapperTok (i, s)   = zip (words s) (repeat 1)

reducerTok :: (String, [Integer]) -> (String, Integer)
reducerTok (k, vs) = (k, sum vs)

main = do 
  text <- readFile "rdd.txt"
  let text' = zip [1..] $ lines text
      rdd   = chunksOf 100 text'
      
  print $ mrJob mapperTok reducerTok rdd
