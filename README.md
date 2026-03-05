# runner

This is an actions runner docker image for use with [Actions Runner Controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller). The [Dockerfile](Dockerfile) is based on the example in [this documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller#creating-your-own-runner-image). However, rather than using `mcr.microsoft.com/dotnet/runtime-deps:6.0` as the base image, I use `ubuntu:24.04` as the base and install a few tools needed in my workflows.  

The packages of this repo correspond to the [releases of the actions runner](https://github.com/actions/runner/releases).     

## Tools cache

This image pre-populates the GitHub Actions tool cache at `/opt/hostedtoolcache`.

- `node`: the latest 3 LTS major lines (latest patch version of each), stored at `/opt/hostedtoolcache/node/<version>/<arch>`
- `uv`: the latest release at image build time, stored at `/opt/hostedtoolcache/uv/<version>/<arch>`

The following environment variables are set for compatibility with setup actions:

- `AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache`
- `RUNNER_TOOL_CACHE=/opt/hostedtoolcache`