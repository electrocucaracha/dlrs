# Comparing CPU vs GPU peformance on PyTorch with Intel MKL-DNN

The following analysis was made to compare CPU and GPU performance
using AWS instances with same instance types(flavors) on the same 
Availability Zone(us-east-1a).

| Feature               | CPU instance                  | GPU instance                                      |
|-----------------------|-------------------------------|---------------------------------------------------|
| Host OS               | Clear Linux 29810             | Ubuntu Xenial 16.04                               |
| Kernel version        | 5.1.7-128.aws                 | 4.4.0-1087-aws                                    |
| Flavor                | c5d.2xlarge                   | g2.2xlarge                                        |
| vCPUs                 | 8                             | 8                                                 |
| Memory                | 16 GB                         | 15 GB                                             |
| Cost                  | $0.384/hr                     | $0.65/hr                                          |
| Base image            | clearlinux/stacks-pytorch-mkl | caffe2ai/caffe2:c2v0.8.1.cuda8.cudnn7.ubuntu16.04 |
| Docker Runtime        | runc                          | nvidia                                            |
| Docker Version        | 18.06.3                       | 18.09.7                                           |
| Milliseconds per iter | 1581.12                       | 3908.79                                           |
| Iters per second      | 0.632462                      | 0.255834                                          |
| Cost per iter         | $0.0001686528                 | $0.00070575375                                    |

## CPU pytorch-mkl detailed log

    WARNING:root:This caffe2 python run does not have GPU support. Will run in CPU only mode.
    [E init_intrinsics_check.cc:43] CPU feature avx is present on your machine, but the Caffe2 binary is not compiled with it. It means you may not get the full speed of your CPU.
    [E init_intrinsics_check.cc:43] CPU feature avx2 is present on your machine, but the Caffe2 binary is not compiled with it. It means you may not get the full speed of your CPU.
    [E init_intrinsics_check.cc:43] CPU feature fma is present on your machine, but the Caffe2 binary is not compiled with it. It means you may not get the full speed of your CPU.
    [I net_dag_utils.cc:102] Operator graph pruning prior to chain compute took: 2.3039e-05 secs
    [I net.cc:197] Starting benchmark, running warmup runs
    [I net_async_base.h:212] Using specified CPU pool size: 2; device id: -1
    [I net_async_base.h:217] Created new CPU pool, size: 2; device id: -1
    [I net.cc:206] Running main runs
    [I net.cc:217] Main runs finished. Milliseconds per iter: 1581.12. Iters per second: 0.632462
    AlexNet: running forward-backward.

## GPU pytorch-mkl detailed log

    AlexNet: running forward-backward.
    I0719 20:33:05.787708    11 net_dag.cc:122] Operator graph pruning prior to chain compute took: 3.9824e-05 secs
    I0719 20:33:05.787835    11 net_dag.cc:379] Number of parallel execution chains 34 Number of operators = 61
    I0719 20:33:05.787941    11 net_dag.cc:583] Starting benchmark.
    I0719 20:33:05.787959    11 net_dag.cc:584] Running warmup runs.
    I0719 20:33:46.220737    11 net_dag.cc:594] Main runs.
    I0719 20:34:25.308698    11 net_dag.cc:605] Main run finished. Milliseconds per iter: 3908.79. Iters per second: 0.255834
