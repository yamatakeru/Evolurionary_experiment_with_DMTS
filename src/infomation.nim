import tables
import future
import math, sequtils, algorithm
import configure, utility
from agent import Agent, AgentSeq, findBestIndex


type
  AnalysisScoreObject = object
    fitness*: float
    dr*: float
    ac*: float
    af*: float
    acf*: float

  ScoreObject = object
    max*: float
    avg*: float
    dr*: float
    ac*: float
    af*: float
    acf*: float
    best_std*: float
    best_mod*: float
    avg_std*: float
    avg_mod*: float

  AnalysisScore* = ref AnalysisScoreObject
  Score* = ref ScoreObject

  InfomationObject = object
    score*: Table[int, Score]

  Infomation* = ref InfomationObject


proc initAnalysisScore*(): AnalysisScore =
  return AnalysisScore(fitness: 0.0, dr: 0.0, ac: 0.0, af: 0.0, acf: 0.0)


proc initScore*(): Score =
  return Score(max: 0.0, avg: 0.0, dr: 0.0, ac: 0.0, af: 0.0, acf: 0.0,
               best_std: 0.0, best_mod: 0.0, avg_std: 0.0, avg_mod: 0.0)


proc initInfomation*(): Infomation =
  var scoretable = initTable[int, Score]()

  for g in 0..<G_NUM:
    scoretable[g] = initScore()

  return Infomation(score: scoretable)


proc evalation*(score: AnalysisScore, agent: Agent, taskmode: TaskMode = Experiment): void =
  score.fitness = agent.fitness

  if taskmode == Experiment or taskmode == ScoreAnalysis:
    let k = (T_SIZE / 3) * 2

    score.dr = agent.score["indDEC"] / k
    score.ac = agent.score["indCAC"] / (k - score.dr * k)
    score.af = agent.score["indCAF"] / (T_SIZE / 3)
    score.acf = agent.score["indCACF"] / (score.dr * k)
  elif taskmode == NormalAnalysis:
    let k = (T_SIZE / 3) * 3

    score.dr = agent.score["indDEC"] / k
    score.ac = agent.score["indCAC"] / (k - score.dr * k)
    score.af = 0.0
    score.acf = agent.score["indCACF"] / (score.dr * k)
  else:
    score.dr = 0.0
    score.ac = 0.0
    score.af = agent.score["indCAF"] / T_SIZE.float()
    score.acf = 0.0


proc evalation*(score: Score, pop: AgentSeq): void =
  let fits = pop[].map(proc(agent: Agent): float = agent.fitness)

  score.max = fits.max()
  score.avg = fits.sum() / P_NUM.float()

  let
    avgDEC = pop[].map(proc(agent: Agent): float = agent.score["indDEC"]).sum() / P_NUM.float()
    avgCAC = pop[].map(proc(agent: Agent): float = agent.score["indCAC"]).sum() / P_NUM.float()
    avgCAF = pop[].map(proc(agent: Agent): float = agent.score["indCAF"]).sum() / P_NUM.float()
    avgCACF = pop[].map(proc(agent: Agent): float = agent.score["indCACF"]).sum() / P_NUM.float()
    k = (T_SIZE / 3) * 2

  score.dr = avgDEC / k
  score.ac = avgCAC / (k - score.dr * k)
  score.af = avgCAF / (T_SIZE / 3)
  score.acf = avgCACF / (score.dr * k)

  let best_agent = pop[pop.findBestIndex()]

  score.best_std = (best_agent.neuralnetwork.mod_id.count(false) - INPUTS).float()
  score.best_mod = best_agent.neuralnetwork.mod_id.count(true).float()

  score.avg_std = sum(pop[].map(proc(agent: Agent): float = agent.neuralnetwork.mod_id.count(false).float - INPUTS.float())) / P_NUM.float
  score.avg_mod = sum(pop[].map(proc(agent: Agent): float = agent.neuralnetwork.mod_id.count(true).float)) / P_NUM.float


proc evalation*(info: Infomation, pop: AgentSeq, gen: int): void =
  info.score[gen].evalation(pop)
