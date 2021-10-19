import random
import future, tables, sequtils
import configure, utility


type
  GenotypeObject* = object
    n_size*: int
    mod_id*: seq[bool]
    weights*: seq[seq[float]]
    params*: Table[string, float]

  GenotypeObject2* = object
    n_size*: int
    mod_id*: seq[bool]
    weights*: seq[seq[float]]
    connect_mask*: seq[seq[float]]
    params*: seq[Table[string, float]]

  Genotype* = ref GenotypeObject
  Genotype2* = ref GenotypeObject2


proc initGenotype*(): Genotype =
  let
    n_size = rand(INIT_NN-1) + 1
    mod_id = concat(lc[false| (_<- INPUTS.bounds()), bool],
                    lc[(if rand(1.0) < 0.5: true else: false)| (_<- n_size.bounds()), bool])
    weights = lc[(lc[rand(2.0) - 1.0| (y <- (INPUTS+n_size).bounds()), float])| (x <- n_size.bounds()), seq[float]]
  var
    paramtable = initTable[string, float]()

  paramtable["eta"] = rand(200.0) - 100.0
  paramtable["eps"] = rand(200.0) - 100.0
  for str in @["A", "B", "C", "D"]:
    paramtable[str] = rand(2.0) - 1.0

  return Genotype(n_size: n_size, mod_id: mod_id, weights: weights, params: paramtable)

#proc initGenotype2*(): Genotype2 =
#  discard


proc insertion*(genotype: Genotype): void =
  if genotype.n_size < MAX_NN:
    for i in genotype.n_size.bounds():
      genotype.weights[i].insert(2.0*rand(1.0)-1.0, INPUTS+genotype.n_size)

    genotype.weights.insert(lc[2.0*rand(1.0)-1.0| (_<- (INPUTS+genotype.n_size+1).bounds()), float], genotype.n_size)
    genotype.mod_id.insert(if rand(1.0) < 0.5: true else: false, INPUTS+genotype.n_size)

    genotype.n_size.inc()


proc duplication*(genotype: Genotype, index: int): void =
  if genotype.n_size < MAX_NN:
    for i in genotype.n_size.bounds():
      genotype.weights[i].insert(2.0*rand(1.0)-1.0, INPUTS+genotype.n_size)

    genotype.weights.insert(genotype.weights[index], genotype.n_size)
    genotype.weights[genotype.n_size][INPUTS+genotype.n_size] = genotype.weights[index][INPUTS+index]
    genotype.mod_id.insert(genotype.mod_id[INPUTS+index], INPUTS+genotype.n_size)

    genotype.n_size.inc()


proc deletion*(genotype: Genotype, index: int): void =
  if genotype.n_size > 0:
    genotype.weights.delete(index, index)
    for i in (genotype.n_size-1).bounds():
      genotype.weights[i].delete(INPUTS+index, INPUTS+index)

    genotype.mod_id.delete(INPUTS+index, INPUTS+index)

    genotype.n_size.dec()
