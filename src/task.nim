import random
import future, tables, sequtils
import configure, utility
from agent import Agent, action, storeNetworkStatus


proc studyPhase(agent: Agent, target: int, os: bool = false): void =
  var inputs = newSeq[float](INPUTS)

  inputs[0] = BIAS
  for i in 0..<ACTIVATING_BIT_NUM:
    inputs[((target + i) mod BITS) + BIAS_AND_TEACHING] = 1.0

  if os:
    agent.action(inputs, phase=1)
  else:
    discard agent.action(inputs)


proc delayPhase(agent: Agent, delay: int, os: bool = false): void =
  var inputs = newSeq[float](INPUTS)

  inputs[0] = BIAS
  for _ in delay.bounds():
    if os:
      agent.action(inputs, phase=2)
    else:
      discard  agent.action(inputs)


proc choicePhase(agent:  Agent, os: bool = false): float =
  var inputs = newSeq[float](INPUTS)

  inputs[0] = BIAS
  inputs[1] = 1.0

  if os:
    return agent.action(inputs, phase=3, choice_r=REFERENCE_SIGNAL).choice
  else:
    return agent.action(inputs, choice_r=REFERENCE_SIGNAL).choice


proc testPhase(agent: Agent, target: int, os: bool = false): bool =
  var
    indexes = toSeq(0..<BITS)
    answer: float
  
  indexes.shuffle()
  for idx in indexes:
    var inputs = newSeq[float](INPUTS)
    inputs[0] = BIAS
    for i in 0..<ACTIVATING_BIT_NUM:
      inputs[((idx + i) mod BITS) + BIAS_AND_TEACHING] = 1.0
  
    if os:
      answer = agent.action(inputs, phase=4).answer
    else:
      answer = agent.action(inputs).answer

    if answer > 0.333:
      if idx == target:
        return true
      else:
        return false

  return false


proc trial*(agent: var Agent, defaultdelay: int = -1, defaulttarget: int = -1, taskmode: TaskMode = Experiment): void  =
  var
    fitness_of_DTMS: float = 0.0
    indDEC: float = 0.0
    indCAC: float = 0.0
    indCAF: float = 0.0
    indCACF: float = 0.0
    forced: seq[bool]
    hardle: seq[bool]

  # task mode => 0: test, 1: normal analysis, 2: force analysis
  if taskmode == Experiment:
    forced = lc[(if x < FORCE_NUM: true else: false)| (x <- T_SIZE.bounds()), bool]
    hardle = lc[(if x < HARDLE_NUM: true else: false)| (x <- T_SIZE.bounds()), bool]
    forced.shuffle()
    hardle.shuffle()
  elif taskmode == NormalAnalysis:
    forced = lc[false| (_ <- T_SIZE.bounds()), bool]
    hardle = lc[false| (_ <- T_SIZE.bounds()), bool]
  else:
    forced = lc[true| (_ <- T_SIZE.bounds()), bool]
    hardle = lc[false| (_ <- T_SIZE.bounds()), bool]

  # task looop
  for _ in 0..<SAMPLES:
    for i in 0..<T_SIZE:
      let target = if defaulttarget < 0: rand(BITS-1) else: defaulttarget
      var
        agent_cp: Agent
        delay = if defaultdelay < 0: powerRand(0.7).int() + 1 else: defaultdelay

      agent_cp.deepcopy(agent)
      if delay > MAX_DELAY:
        delay = MAX_DELAY

      if hardle[i]:
        delay.inc()
      else:
        studyPhase(agent_cp, target)

      delayPhase(agent_cp, delay)

      # DTMS paradigm
      let
        choice = choicePhase(agent_cp)
        result_of_test = testPhase(agent_cp, target)

      if forced[i]:
        # answer is correct
        if result_of_test:
          fitness_of_DTMS += H_R
          indCAF += 1.0
        # answer is wrong
        else:
          fitness_of_DTMS += PENALTY
      else:
        if choice <= 0.333:
          # answer is correct
          if result_of_test:
            fitness_of_DTMS += H_R
            indCAC += 1.0
          # answer is wrong
          else:
            fitness_of_DTMS += PENALTY
        else:
          fitness_of_DTMS += L_R
          indDEC += 1.0
          if result_of_test:
            indCACF += 1.0

  fitness_of_DTMS /= SAMPLES.float()
  indDEC /= SAMPLES.float()
  indCAC /= SAMPLES.float()
  indCAF /= SAMPLES.float()
  indCACF /= SAMPLES.float()

  agent.fitness = fitness_of_DTMS
  agent.score["indDEC"] = indDEC
  agent.score["indCAC"] = indCAC
  agent.score["indCAF"] = indCAF
  agent.score["indCACF"] = indCACF


proc oneShotTrial*(agent: Agent, defaultdelay: int = -1, defaulttarget: int = -1, controlexperiment: bool = false): int =
  var rslt: int

  # task looop
  let
    target = if defaulttarget < 0: rand(BITS-1) else: defaulttarget
  var delay = if defaultdelay < 0: powerRand(0.7).int() + 1 else: defaultdelay

  #agent.networkRefresh()
  agent.storeNetworkStatus(0)
  agent.life_time.inc()
  if delay > MAX_DELAY:
    delay = MAX_DELAY

  if controlexperiment:
    delay.inc()
  else:
    studyPhase(agent, target, os=true)

  delayPhase(agent, delay, os=true)

  if choicePhase(agent, os=true) <= 0.333:
    if testPhase(agent, target, os=true):
      rslt = 1
    else:
      rslt = 0
  else:
    rslt = -1

  return rslt


proc preTrial*(agent: var Agent, defaultdelay: int = -1, defaulttarget: int = -1): void  =
  var
    fitness_of_DTMS: float = 0.0
    indDEC: float = 0.0
    indCAC: float = 0.0
    indCAF: float = 0.0
    indCACF: float = 0.0

  # task loop
  for _ in SAMPLES.bounds():
    for i in T_SIZE.bounds():
      let target = if defaulttarget < 0: rand(BITS-1) else: defaulttarget
      var
        agent_cp: Agent
        delay = if defaultdelay < 0: powerRand(0.7).int() + 1 else: defaultdelay

      agent_cp.deepcopy(agent)
      if delay > MAX_DELAY:
        delay = MAX_DELAY

      studyPhase(agent_cp, target)
      delayPhase(agent_cp, delay)

      if testPhase(agent_cp, target):
        fitness_of_DTMS += H_R
        indCAF += 1.0
      else:
        fitness_of_DTMS += PENALTY

  fitness_of_DTMS /= SAMPLES.float()
  indCAF /= SAMPLES.float()

  agent.fitness = fitness_of_DTMS
  #if agent.neuralnetwork.mod_id.count(true) < 3:
  #  agent.fitness *= 0.8
  agent.score["indDEC"] = indDEC
  agent.score["indCAC"] = indCAC
  agent.score["indCAF"] = indCAF
  agent.score["indCACF"] = indCACF
