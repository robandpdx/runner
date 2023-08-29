# runner

This is an actions runner docker image for use with [Actions Runner Controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller). The [Dockerfile](Dockerfile) is based on the example in [this documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller#creating-your-own-runner-image). However, rather than using `mcr.microsoft.com/dotnet/runtime-deps:6.0` as the base image, I use `ubuntu:22.04` as the base and install a few tools needed in my workflows.  

The packages of this repo correspond to the [releases of the actions runner](https://github.com/actions/runner/releases).     