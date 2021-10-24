# About

This repository provides source code and data used in a paper: *Evolution of metamemory based on self-reference to own memory in artificial neural network with neuromodulation*.

This repository is released under the MIT License, see `LICENSE`.

# Getting Started

You can compiles this sorce code by executing a python program as follows:

```shell
$ python build.py
```

Also, you can get a result of this experiment by executing a python program as follows:

```shell
$ python run.py [save_path] [number_of_trials]
```

Moreover, you can get behaviors of a network for each task target (default delay num is 10) by executing a python program as follows:

```shell
$ python run.py -ia [analyzed_data_path] [number_of_target_network]
```

If you want to analyze your experiment data, please use `analysis.ipynb`. When you analyze your experiment's result, you should make an appropriate change to the target path in the notebook file.