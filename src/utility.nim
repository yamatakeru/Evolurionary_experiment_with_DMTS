import math, strutils, stats, sequtils
import random, mersenne
import configure

# math func
proc sigmoid*(x: float): float =
  return 1.0 / (1.0 + exp(-x))


# number op
# sgn in math
proc sign*(n: int): int =
  return if n >= 0: 1 else: -1

proc sign*(n: float): float =
  return if n >= 0.0: 1.0 else: -1.0

proc clip*[T](n: T, mi: T, ma: T): T =
  if n < mi:
    return mi
  elif n > ma:
    return ma
  else:
    return n


# iterator
iterator bounds*(length: int): int =
  var i = 0

  while i < length:
    yield i
    i.inc()

iterator bounds*(lo, length: int): int =
  var i = lo

  while i < length:
    yield i
    i.inc()

iterator indices*(s: seq): int =
  var i = s.low()

  while i <= s.high():
    yield i
    i.inc()


# seq op
proc map*[T, S](s: ref seq[T]; op: proc (x: T): S): ref seq[S] =
  var new_s = new seq[S]
  new_s[] = s[].map(op)

  return new_s

proc filter*[T](s: ref seq[T], pred: proc(x: T): bool): ref seq[T] =
  var new_s = new seq[T]
  new_s[] = s[].filter(pred)

  return new_s

proc apply*[T](s: ref seq[T], op: proc (x: T): T): void =
  for i in s[].indices():
    discard s[i].op()

proc apply*[T](s: ref seq[T], op: proc (x: var T): T): void =
  for i in s[].indices():
    discard s[i].op()


# vector op
proc outer*(seq1, seq2: seq): auto =
  var o = @[seq2].cycle(seq1.len())

  for i in seq2.indices():
    for j, s1v in seq1:
      o[j][i] *= s1v

  return o


# random op
proc initMersenneTwister*(): MersenneTwister =
  let seed = rand(U32_MAX).uint32()

  return newMersenneTwister(seed)


proc getMtRand*(mt: var MersenneTwister, max: float = 1.0): float =
  return max * ((mt.getNum().int() + 1) / (U32_MAX + 2))

proc getMtRand*(mt: var MersenneTwister, max: int): int =
  return mt.getNum().int() mod (max + 1)


proc normGauss*(mt: var MersenneTwister, mean, sigma: float): float = 
  return mean + sigma * sqrt(-2*ln(getMtRand(mt))) * sin(2*PI*getMtRand(mt))

proc normGauss*(mean, sigma: float): float = 
  return mean + sigma * sqrt(-2*ln(rand(1.0))) * sin(2*PI*rand(1.0))


proc powerRand*(lmd: float): float =
  return -1.0 / (lmd * ln(1.0 - rand(1.0)))


# template
#[
template times*(x: SomeOrdinal, y: untyped): stmt =
  for _ in 0..<x:
    y

template times*(x: SomeOrdinal, i: untyped, y: untyped): stmt =
  for i in 0..<x:
    y
]#


# test proc
#[
proc randomTest(): void =
  var
    mt = initMersenneTwister()
    rs: TRunningStat
  const
    precisn = 5

  for j in 0..5:
    for i in 0..1000:
      rs.push(mt.normGauss(1, 1))
    echo("mean: ", $formatFloat(rs.mean,ffDecimal,precisn), 
         " stdDev: ", $formatFloat(rs.standardDeviation(),ffDecimal,precisn))

  for i in 3.bounds():
    echo mt.getMtRand()

proc higherOrderFunction[T, S](x, y: T, op: proc(x, y: T): S): S =
  return op(x, y)
proc addFunc(x, y: int): int =
  return x + y
proc higherOrderFunctionTest*(): void =
  echo "higherOrderFunctionTest"
  echo ">> higherOrderFunction(2, 3, addFunc)"
  echo ">> ", $higherOrderFunction(2, 3, addFunc)
]#
