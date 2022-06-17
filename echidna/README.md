<<<<<<< HEAD
# Instructions to setup and run ECHIDNA tests of dss-gate

## Pre-requisites

- Clone the dss-gate repository

 `git clone git@github.com:deco-protocol/dss-gate.git`

- Install Docker

Follow instructions based on your Operating System : https://docs.docker.com/get-docker/


## Setup ECHIDNA

### Step 1 : Pull the Trail-Of-Bits ETH Sec ToolBox container image

- Pull the docker image

`docker pull trailofbits/eth-security-toolbox`

<<<<<<< HEAD
- Change to dss-gate directory

`cd .../dss-gate`

### Step 2 : Run the Trail-Of-Bits container

`docker run -it -v "$PWD":/home/training trailofbits/eth-security-toolbox`

<<<<<<< HEAD
Note : Make sure you run this command when your pwd is set to cloned repo folder(i.e dss-gate). This will enable you to access all the files and folders in the current working directory inside the container under `/home/training` folder.

Yay !! Setup is complete

## Run ECHIDNA tests

The echidna tests of dss-gate can be run by below command :

`make echidna-dss-gate`

The corpus will be collected in 'dss-gate/corpus folder'. The corpus is collection of seed input, random inputs, coverage and execution flow of the target contract being tested.
