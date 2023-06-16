#!/bin/bash

GIT_SHA=$(git rev-parse --short HEAD)

docker build . -t willcliffy/keydream -t willcliffy/keydream:$GIT_SHA
docker push willcliffy/keydream
docker push willcliffy/keydream:$GIT_SHA
