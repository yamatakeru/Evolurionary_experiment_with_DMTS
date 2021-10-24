import system
import os
import threadpool
import parseopt2
import future
#import arraymancer
import marshal, json
import random, math, sequtils, tables, algorithm, strutils
import configure, utility
import agent, task, infomation
from genotype import Genotype, GenotypeObject
{.experimental.}


proc invdiAanalysis(savepath: string, target_num: int): void =
  var
    target_agent = initAgent()
    analysis_info = initAnalysisScore()

  # load genotype
  block:
    let f: File = open(savepath & "_analysis.json", fmRead)
    defer:
      f.close()
      echo "file closed."
    let
      json_str = f.readAll().replace("nan", "-1.0")
      json_obj = json_str.parseJson()
    echo 0
    target_agent.genotype[] = to[GenotypeObject] json_obj[target_num.intToStr()]["genotype"].pretty()
  echo 1
  var param_temp: Table[string, float]
  for k, v in target_agent.genotype.params.pairs:
    param_temp[k] = v
  target_agent.genotype.params = param_temp
  target_agent.genotype.params["eps"] = 0.0
  target_agent.develop()

  block:
    let f: File = open(savepath & "_behavior.json", fmWrite)
    defer:
      close(f)
      echo "file closed."

    f.writeLine "{"
    f.writeLine "\"phenotype\": ", $$target_agent.neuralnetwork[] & ","
    for i in 0..<BITS:
      f.writeLine "\"", $i, "\": {"
      let test_result = target_agent.oneShotTrial(10, i, controlexperiment=false)
      f.writeLine "\t\"result\": ", $$test_result, ","
      f.writeLine "\t\"status\": ", $$target_agent.network_history
      target_agent.develop()
      if i == 4:
        f.writeLine "\t}"
      else:
        f.writeLine "\t},"
    f.writeLine "}"


# analysis
proc analysis(savepath: string): void =
  var
    pop: AgentSeq = new AgentSeqObject
    target_agents: AgentSeq
    analysis_info = initAnalysisScore()

  # load genotype
  pop[] = lc[initAgent() | (_ <- P_NUM.bounds()), Agent]
  block:
    let f: File = open(savepath & "_genotypes.json", fmRead)
    defer:
      close(f)
      echo "file is closed."

    var idx = 0
    while not f.endOfFile:
      pop[idx].genotype[] = to[GenotypeObject] f.readLine()
      var param_temp: Table[string, float]
      for k, v in pop[idx].genotype.params.pairs:
        param_temp[k] = v
      pop[idx].genotype.params = param_temp
      pop[idx].develop()
      idx.inc()

  let
    delay: int = 50
    intvl: int = 5

  # select hight score agent
  parallel:
    for idx in pop.indices():
      spawn pop[idx].trial(-1)
      #spawn pop[idx].preTrial(-1)

  target_agents = pop.filter(proc(agent: Agent): bool = agent.fitness >= 150.0)
  target_agents.sort(proc(a1, a2: Agent): int = cmp(a2.fitness, a1.fitness))
  echo "target agents: ", $target_agents.len()

  # analysis and save
  block:
    let f: File = open(savepath & "_analysis.json", fmWrite)
    defer:
      close(f)
      echo "file closed."

    f.writeLine "{"
    for idx in target_agents.indices():
      echo "agent: ", $idx
      f.writeLine "\t\"", $idx, "\": {"

      # write genotype
      f.writeLine "\t\t\"genotype\": ", $$target_agents[idx].genotype[], ","

      # write test score
      f.writeLine "\t\t\"test_score\": {"
      for d in countup(0, delay-1, intvl):
        target_agents[idx].develop()
        target_agents[idx].trial(defaultdelay=d+1, taskmode=ScoreAnalysis)
        analysis_info.evalation(target_agents[idx], taskmode=ScoreAnalysis)
        if d == delay-intvl:
          f.writeLine "\t\t\t\"", $d, "\": ", $$analysis_info[]
        else:
          f.writeLine "\t\t\t\"", $d, "\": ", $$analysis_info[], ","
      f.writeLine "\t\t},"

      # write bit test score
      # normal
      f.writeLine "\t\t\"bit_test_score\": {"
      for d in countup(0, delay-1, intvl):
        f.writeLine "\t\t\t\"", $d, "\": {"
        for bit_ptn in BITS.bounds():
          target_agents[idx].develop()
          target_agents[idx].trial(defaultdelay=d+1, defaulttarget=bit_ptn, taskmode=NormalAnalysis)
          analysis_info.evalation(target_agents[idx], taskmode=NormalAnalysis)
          if bit_ptn == BITS-1:
            f.writeLine "\t\t\t\t\"", $bit_ptn, "\": ", $$analysis_info[]
          else:
            f.writeLine "\t\t\t\t\"", $bit_ptn, "\": ", $$analysis_info[], ","
        if d == delay-intvl:
          f.writeLine "\t\t\t}"
        else:
          f.writeLine "\t\t\t},"
      f.writeLine "\t\t},"
      # forced only
      f.writeLine "\t\t\"bit_test_score_f\": {"
      for d in countup(0, delay-1, intvl):
        f.writeLine "\t\t\t\"", $d, "\": {"
        for bit_ptn in BITS.bounds():
          target_agents[idx].develop()
          target_agents[idx].trial(defaultdelay=d+1, defaulttarget=bit_ptn, taskmode=ForceAnalysis)
          analysis_info.evalation(target_agents[idx], taskmode=ForceAnalysis)
          if bit_ptn == BITS-1:
            f.writeLine "\t\t\t\t\"", $bit_ptn, "\": ", $$analysis_info[]
          else:
            f.writeLine "\t\t\t\t\"", $bit_ptn, "\": ", $$analysis_info[], ","
        if d == delay-intvl:
          f.writeLine "\t\t\t}"
        else:
          f.writeLine "\t\t\t},"
      f.writeLine "\t\t}"

      if idx == target_agents.high():
        f.writeLine "\t}"
      else:
        f.writeLine "\t},"
    f.writeLine "}"


# experiment
proc experiment(savepath: string): void =
  var
    pop: AgentSeq = new AgentSeqObject
    experiment_info: Infomation

  setMaxPoolSize(MaxThreadPoolSize) # 256
  #setMaxPoolSize(MaxDistinguishedThread) # 32

  while true:
    pop[] = lc[initAgent() | (_ <- P_NUM.bounds()), Agent]
    experiment_info = initInfomation()
    # trial loop
    for gen in G_NUM.bounds():
      # parallel excution
      #parallel:
      #  for idx in pop.indices():
      #    spawn pop[idx].trial()
      if gen <= 100:
        parallel:
          for idx in pop.indices():
            spawn pop[idx].preTrial()
      else:
        parallel:
          for idx in pop.indices():
            spawn pop[idx].trial()

      # evalation
      experiment_info.evalation(pop, gen)

      # show infomation
      echo ">> ", $gen, "\n  M: ", $round(experiment_info.score[gen].max, 3), "\t A: ", $round(experiment_info.score[gen].avg, 3)
      echo "  D: ", $round(experiment_info.score[gen].dr, 3), "\tC: ", $round(experiment_info.score[gen].ac, 3), "\tF: ", $round(experiment_info.score[gen].af, 3)
      echo "  NN_M: ", $experiment_info.score[gen].best_std, "\t", $experiment_info.score[gen].best_mod
      echo "  NN_A: ", $round(experiment_info.score[gen].avg_std, 3), "\t", $round(experiment_info.score[gen].avg_mod, 3)

      # continue or restart?
      if gen == 200 and experiment_info.score[gen].max < 150.0:
        break

      # evoltion
      pop.evolutionStrategy()
      pop.apply(proc(agent: Agent): Agent = agent.develop())

      # save
      if gen != 0 and gen mod 100 == 0:
        # save genom
        block:
          let f: File = open(savepath & "_genotypes_" & $gen & ".json", fmWrite)
          defer:
            close(f)
            echo "file1 closed."

          for idx, agent in pop:
            f.writeLine $$agent.genotype[]

        # save genom
        block:
          let f: File = open(savepath & "_genotypes2_" & $gen & ".json", fmWrite)
          defer:
            close(f)
            echo "file2 closed."

          f.writeLine "{"
          for idx, agent in pop:
            if idx == P_NUM-1:
              f.writeLine "\"", $idx, "\": ", $$agent.genotype[]
            else:
              f.writeLine "\"", $idx, "\": ", $$agent.genotype[], ","
          f.writeLine "}"

  # save genom1
  block:
    let f: File = open(savepath & "_genotypes.json", fmWrite)
    defer:
      close(f)
      echo "file1 closed."

    for idx, agent in pop:
      f.writeLine $$agent.genotype[]

  # save genom2
  block:
    let f: File = open(savepath & "_genotypes2.json", fmWrite)
    defer:
      close(f)
      echo "file2 closed."

    f.writeLine "{"
    for idx, agent in pop:
      if idx == P_NUM-1:
        f.writeLine "\"", $idx, "\": ", $$agent.genotype[]
      else:
        f.writeLine "\"", $idx, "\": ", $$agent.genotype[], ","
    f.writeLine "}"

  # save score
  block:
    let f: File = open(savepath & "_info.json", fmWrite)
    defer:
      close(f)
      echo "file3 closed."

    f.writeLine "{"
    for idx in G_NUM.bounds():
      if idx == G_NUM-1:
        f.writeLine "\"", $idx, "\": ", $$experiment_info.score[idx][]
      else:
        f.writeLine "\"", $idx, "\": ", $$experiment_info.score[idx][], ","
    f.writeLine "}"


proc mainRoutine(savepath: string, analysis: int, agent_num: int): int =
  if analysis == 1:
    # analysis
    echo "Run Analysis."
    analysis(savepath)

  elif analysis == 0:
    # experiment
    echo "Run Experiment."
    experiment(savepath)
  else:
    echo "Run invdiAanalysis."
    invdiAanalysis(savepath, agent_num)

  return 0



if isMainModule:
  var
    savepath: string
    analysis: int = 0
    agent_num: int = -1

  randomize()

  # parse
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      if key != nil:
        savepath = key
    of cmdLongOption, cmdShortOption:
      if key == "analysis" or key == "a":
        if val == "true":
          analysis = 1
      elif key == "i_analysis" or key == "ia":
        agent_num = val.parseInt
        analysis = 2
    of cmdEnd:
      discard

  if savepath != nil:
    system.programResult = mainRoutine(savepath, analysis, agent_num)
  else:
    echo "Run Experiment : ./main path"
    echo "Run Analysis   : ./main path -analysis_signal"
    system.programResult = 1
