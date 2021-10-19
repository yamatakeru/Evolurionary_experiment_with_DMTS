# definition
const
  #U32_MAX*: int = 4294967295.int()
  U32_MAX*: int = 2147483647.int()

  G_NUM*: int = 1000
  P_NUM*: int = 300

  T_SIZE*: int = 300
  FORCE_NUM*: int = T_SIZE div 3
  HARDLE_NUM*: int = 0 #T_SIZE div 10 #50
  MAX_DELAY*: int = 50

  INIT_NN*: int = 16
  MAX_NN*: int = 16
  BIAS_AND_TEACHING*: int = 2
  BITS*: int = 5
  INPUTS*: int = BIAS_AND_TEACHING + BITS
  PARAMS*: int = 5
  H_R*: float = 1.0
  L_R*: float = 0.3
  PENALTY*: float = 0.0
  LEANING_RATE*: float = 1 / 200000

  REFERENCE_SIGNAL*: bool = true

  ACTIVATING_BIT_NUM*: int = 1

  LIM_W*: float = 1.0
  LIM_E*: float = 100.0
  LIM_C*: float = 1.0

  SAMPLES*: int = 2

  THINK*: int = 3
  BIAS*: float = 1.0
  MAX_W*: float = 10.0

  SEGMENT*: int = 10
  CR*: float = 0.1
  P_M*: float = 0.1
  STD_DEV*: float = 0.3

  P_INS*: float = 0.04
  P_DUP*: float = 0.02
  P_DEL*: float = 0.06


type TaskMode* = enum
  Experiment
  NormalAnalysis
  ForceAnalysis
