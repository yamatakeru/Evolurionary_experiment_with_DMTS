import random
import math, stats, future, tables, sequtils
import configure, utility
from genotype import Genotype


type
  NeuralnetworkObject = object
    n_size*: int
    mod_id*: seq[bool]
    inputs*: seq[float]
    neurons*: seq[float]
    origin_weights*: seq[seq[float]]
    weights*: seq[seq[float]]
    params*: Table[string, float]

  Neuralnetwork* = ref NeuralnetworkObject


proc initNeuralnetwork*(genotype: Genotype): Neuralnetwork =
  let
    neurons = newSeq[float](genotype.n_size)
    inputs = newSeq[float](INPUTS)
  var
    pheno_weights = genotype.weights
    pheno_params = genotype.params

  for i in genotype.n_size.bounds():
    for j in (INPUTS+genotype.n_size).bounds():
      pheno_weights[i][j] = pow(pheno_weights[i][j], 3.0) * 10.0
      if abs(pheno_weights[i][j]) < 0.1:
        pheno_weights[i][j] = 0.0

  pheno_params["eta"] = if abs(pheno_params["eta"]) > 0.0: pheno_params["eta"] else: 0.0
  pheno_params["eps"] = if abs(pheno_params["eps"]) > 0.0: pheno_params["eps"] else: 0.0
  for str in @["A", "B", "C", "D"]:
    pheno_params[str] = pow(pheno_params[str], 3.0)
    if abs(pheno_params[str]) < 0.1:
      pheno_params[str] = 0.0

  return Neuralnetwork(n_size: genotype.n_size, mod_id: genotype.mod_id, inputs: inputs, neurons: neurons, origin_weights: pheno_weights, weights: pheno_weights, params: pheno_params)


proc refresh*(self: Neuralnetwork): void =
  for i in 0..<self.n_size:
    for j in 0..<(INPUTS+self.n_size):
      self.weights[i][j] = self.origin_weights[i][j]

  for i in 0..<self.n_size:
    self.neurons[i] = 0.0


proc getStatus*(self: Neuralnetwork): tuple =
  var status: tuple[inputs:seq[float], neurons:seq[float], weights:seq[seq[float]]] = (self.inputs, self.neurons, self.weights)

  return status


proc updateWeights(neuralnetwork: Neuralnetwork, inputs: seq[float], outs: seq[float], mouts: seq[float], second_oder_mod: bool = false): void =
  let
    eta = neuralnetwork.params["eta"]
    #eps = neuralnetwork.params["eps"]
    A = neuralnetwork.params["A"]
    B = neuralnetwork.params["B"]
    C = neuralnetwork.params["C"]
    D = neuralnetwork.params["D"]
    #avg_activate = mean(outs.map(proc(x: float): float = abs(x)))
  var
    k: int
    weights_temp = neuralnetwork.weights

  for i in neuralnetwork.n_size.bounds():
    for j in (INPUTS+neuralnetwork.n_size).bounds():
      if weights_temp[i][j] != 0.0:
        if j < INPUTS:
          #neuralnetwork.weights[i][j] += LEANING_RATE * mouts[i] * (eta * (A * inputs[j] * outs[i] + B * inputs[j] + C * outs[i] + D) - (eps * avg_activate * weights_temp[i][j]))
          neuralnetwork.weights[i][j]+= mouts[i] * eta * (A * inputs[j] * outs[i] + B * inputs[j] + C * outs[i] + D)
          #neuralnetwork.weights[i][j] = neuralnetwork.origin_weights[i][j] + mouts[i] * eta * (A * inputs[j] * outs[i] + B * inputs[j] + C * outs[i] + D)

          #neuralnetwork.weights[i][j]+= 0 * eta * (A * inputs[j] * outs[i] + B * inputs[j] + C * outs[i] + D)
        else:
          if second_oder_mod:
            if (not neuralnetwork.mod_id[INPUTS+i]) and neuralnetwork.mod_id[j]:
              continue
          else:
            if neuralnetwork.mod_id[j]:
              continue
          k = j - INPUTS
          #neuralnetwork.weights[i][j] += LEANING_RATE * mouts[i] * (eta * (A * outs[k] * outs[i] + B * outs[k] + C * outs[i] + D) - (eps * avg_activate * weights_temp[i][j]))
          neuralnetwork.weights[i][j] += mouts[i] * eta * (A * outs[k] * outs[i] + B * outs[k] + C * outs[i] + D)
          #neuralnetwork.weights[i][j] = neuralnetwork.origin_weights[i][j] + mouts[i] * eta * (A * outs[k] * outs[i] + B * outs[k] + C * outs[i] + D)

          #neuralnetwork.weights[i][j] += 0 * eta * (A * outs[k] * outs[i] + B * outs[k] + C * outs[i] + D)

        if abs(neuralnetwork.weights[i][j]) > 10.0:
          neuralnetwork.weights[i][j] = MAX_W * sgn(neuralnetwork.weights[i][j]).float

    #if max(abs(max(neuralnetwork.weights[i])), abs(min(neuralnetwork.weights[i]))) > 11.0:#MAX_W:
    #  echo "over wight!: ", $max(neuralnetwork.weights[i]), ", ", $min(neuralnetwork.weights[i])

  #echo $neuralnetwork.weights[0][0], " ", $neuralnetwork.weights[0][1]


proc caluclation*(neuralnetwork: Neuralnetwork, inputs: seq[float]): tuple =
  neuralnetwork.inputs = inputs.mapIt((it + normGauss(0.0, 0.1)).clip(-1.0, 1.0))
  let vector = concat(neuralnetwork.inputs, neuralnetwork.neurons)#.mapIt((it + normGauss(0.0, 0.01)).clip(-1.0, 1.0)))
  #echo inputs
  #echo neuralnetwork.inputs
  #echo vector
  #discard readLine(stdin)
  var
    outs = newSeq[float](neuralnetwork.n_size)
    mouts = newSeq[float](neuralnetwork.n_size)
    outputs: tuple[choice:float, answer:float]

  for i in neuralnetwork.n_size.bounds():
    for j in (INPUTS+neuralnetwork.n_size).bounds():
      if neuralnetwork.mod_id[j]:
        mouts[i] += vector[j] * neuralnetwork.weights[i][j]
      else:
        outs[i] += vector[j] * neuralnetwork.weights[i][j]

    mouts[i] = tanh(mouts[i]) + normGauss(0.0, 0.0001)
    outs[i] = tanh(outs[i]) + normGauss(0.0, 0.0001)

  neuralnetwork.updateWeights(neuralnetwork.inputs, outs, mouts, second_oder_mod=false)
  neuralnetwork.neurons = outs

  if neuralnetwork.mod_id.count(false) - INPUTS >= 2:
    let stds = zip(neuralnetwork.mod_id[INPUTS..^1], neuralnetwork.neurons).filter(proc(neuron: tuple): bool = not neuron.a)[0..<2]
    outputs = (stds[0].b, stds[1].b)
  elif neuralnetwork.mod_id.count(false) - INPUTS == 1:
    let stds = zip(neuralnetwork.mod_id[INPUTS..^1], neuralnetwork.neurons).filter(proc(neuron: tuple): bool = not neuron.a)[0]
    outputs = (stds.b, 0.0)
  else:
    outputs = (0.0, 0.0)

  return outputs
