import random
import tables
import configure, utility, sequtils, algorithm, strutils
import neuralnetwork
import genotype


type
  AgentObject = object
    life_time*: int
    genotype*: Genotype
    neuralnetwork*: Neuralnetwork
    fitness*: float
    fitness_of_DTMS*: float
    fitness_of_BET*: float
    score*: Table[string, float]
    network_history*: Table[string, tuple[inputs:seq[float], neurons:seq[float], weights:seq[seq[float]]]]

  Agent* = ref AgentObject
  AgentSeqObject* = seq[Agent]
  AgentSeq* = ref seq[Agent]


proc initAgent*(): Agent =
  let genotype = initGenotype()
  var
    scoretable = initTable[string, float]()
    nh = initTable[string, tuple[inputs:seq[float], neurons:seq[float], weights:seq[seq[float]]]]()

  for str in @["indDEC", "indCAC", "indCAF", "indCACF"]:
    scoretable[str] = 0.0

  let neuralnetwork = initNeuralnetwork(genotype)

  return Agent(life_time: 0, genotype: genotype, neuralnetwork: neuralnetwork, fitness: 0.0, fitness_of_DTMS: 0.0, fitness_of_BET: 0.0, score: scoretable, network_history: nh)


proc develop*(self: Agent): void =
  self.life_time = 0
  self.neuralnetwork = initNeuralnetwork(self.genotype)
  self.fitness = 0.0
  for str in @["indDEC", "indCAC", "indCAF", "indCACF"]:
    self.score[str] = 0.0
  self.network_history = initTable[string, tuple[inputs:seq[float], neurons:seq[float], weights:seq[seq[float]]]]()


proc networkRefresh*(self: Agent): void =
  self.neuralnetwork.refresh()


proc storeNetworkStatus*(self: Agent, phase: int): void =
  self.network_history[phase.intToStr() & "_" & self.life_time.intToStr()] = self.neuralnetwork.getStatus()


proc action*(self: Agent, inputs: seq[float], phase: int = -1, choice_r: bool = false): tuple {.discardable.} = # v:choice... NM2のchoice処理
  let think_times = THINK
  var
    inputs_cp: seq[float]
    outputs: tuple[choice:float, answer:float]

  for i in 0..<think_times:
    inputs_cp.deepcopy(inputs)
    if choice_r and i != 0: # When current phase is Choice phase.
      for j in BIAS_AND_TEACHING..<INPUTS:
        inputs_cp[j] += 0.25

    outputs = self.neuralnetwork.caluclation(inputs_cp)
    #discard readLine(stdin)

    if phase != -1:
      self.storeNetworkStatus(phase)
      self.life_time.inc()

  return outputs


proc findBestIndex*(self: AgentSeq, pos: int = 0, length: int = P_NUM): int =
  var
    index = pos
    max = self[pos].fitness
    k: int

  for i in bounds(pos+1, pos+length):
    #k = (i + P_NUM) mod P_NUM
    k = i  mod P_NUM
    if max < self[k].fitness:
      index = k
      max = self[k].fitness

  return index


proc selection(self: AgentSeq): void =
  let offset = rand(SEGMENT)
  var index: int

  for i in countup(offset, P_NUM-1, SEGMENT):
    index = self.findBestIndex(i, SEGMENT)
    for j in bounds(i, i+SEGMENT):
      self[(j+P_NUM) mod P_NUM].deepcopy(self[index])


proc crossover(pop: AgentSeq): void =
  let
    best_index = pop.findBestIndex()
  var
    pop_cp: AgentSeq
    index: int
    row: int
    col: int
    point0: int
    point1: int

  pop_cp.deepcopy(pop)
  for i in P_NUM.bounds():
    if rand(1.0) > CR or i == best_index or pop[i].genotype.n_size == 0:
      continue

    #index = (rand(P_NUM - SEGMENT) + SEGMENT) mod P_NUM
    index = rand(P_NUM - 1)

    row = pop[i].genotype.n_size
    col = INPUTS + row

    point0 = rand(row-1)
    point1 = rand(col-1)

    if point0 < pop_cp[index].genotype.n_size and point1 < INPUTS+pop_cp[index].genotype.n_size:
      # neuron crossover
      pop[i].genotype.mod_id.delete(point1, INPUTS+pop[i].genotype.n_size-1)
      pop[i].genotype.mod_id.insert(pop_cp[index].genotype.mod_id[point1..^1], point1)
      # weight crossover
      pop[i].genotype.weights.delete(point0, pop[i].genotype.n_size-1)
      pop[i].genotype.weights.insert(pop_cp[index].genotype.weights[point0..^1], point0)
      for j in point0.bounds():
        pop[i].genotype.weights[j].delete(point1, INPUTS+pop[i].genotype.n_size-1)
        pop[i].genotype.weights[j].insert(pop_cp[index].genotype.weights[j][point1..^1], point1)

      # n_size update
      pop[i].genotype.n_size = pop_cp[index].genotype.n_size

    # old virsion crosspver
    #[
    for j in bounds(point0, row):
      if j < pop_cp[index].genotype.n_size:
        pop[i].genotype.mod_id[INPUTS+j] = pop_cp[index].genotype.mod_id[INPUTS+j]
        for k in bounds(point1, col):
          if k < INPUTS+pop_cp[index].genotype.n_size:
            pop[i].genotype.weights[j][k] = pop_cp[index].genotype.weights[j][k]
    ]#

    if rand(1.0) < 0.5:
      pop[i].genotype.params["eta"] = pop_cp[index].genotype.params["eta"]
    if rand(1.0) < 0.5:
      pop[i].genotype.params["eps"] = pop_cp[index].genotype.params["eps"]
    for str in @["A", "B", "C", "D"]:
      if rand(1.0) < 0.5:
        pop[i].genotype.params[str] = pop_cp[index].genotype.params[str]

    pop[i].fitness = (pop[i].fitness + pop_cp[index].fitness) / 2


proc mutation(pop: AgentSeq): void =
  let best_index = pop.findBestIndex()

  for i in P_NUM.bounds():
    if i == best_index:
      continue

    for j in pop[i].genotype.n_size.bounds():
      for k in (INPUTS+pop[i].genotype.n_size).bounds():
        if rand(1.0) < P_M:
          pop[i].genotype.weights[j][k] += normGauss(0.0, STD_DEV)
          if abs(pop[i].genotype.weights[j][k]) > LIM_W:
            pop[i].genotype.weights[j][k] = LIM_W * sign(pop[i].genotype.weights[j][k])

    if rand(1.0) < P_M:
      pop[i].genotype.params["eta"] += normGauss(0.0, STD_DEV * 10.0)
      if abs(pop[i].genotype.params["eta"]) > LIM_E:
        pop[i].genotype.params["eta"] = LIM_E * sign(pop[i].genotype.params["eta"])
    if rand(1.0) < P_M:
      pop[i].genotype.params["eps"] += normGauss(0.0, STD_DEV * 10.0)
      if abs(pop[i].genotype.params["eps"]) > LIM_E:
        pop[i].genotype.params["eps"] = LIM_E * sign(pop[i].genotype.params["eps"])
    for str in @["A", "B", "C", "D"]:
      if rand(1.0) < P_M:
        pop[i].genotype.params[str] += normGauss(0.0, STD_DEV)
        if abs(pop[i].genotype.params[str]) > LIM_C:
          pop[i].genotype.params[str] = LIM_C * sign(pop[i].genotype.params[str])


proc geneticOperator(pop: AgentSeq, elite_save: bool = false): void =
  let
    best_index = pop.findBestIndex()
  var
    index: int

  for i in P_NUM.bounds():
    if elite_save and i == best_index:
      continue

    index = 0
    while index < pop[i].genotype.n_size:
    #for i in agent.genotype.n_size.bounds():
      if rand(1.0) < P_INS:
        pop[i].genotype.insertion()
      if rand(1.0) < P_DUP:
        pop[i].genotype.duplication(index)
      if rand(1.0) < P_DEL:
        pop[i].genotype.deletion(index)

      index.inc()


proc evolutionStrategy*(pop: AgentSeq): void =
  selection(pop)
  crossover(pop)
  mutation(pop)
  geneticOperator(pop, elite_save=false)
