#!/usr/bin/env bash
tcaVersion=$(grep -Po 'LB_VERSION\K[^\r\n]+' Dockerfile)
printf "##teamcity[buildNumber '%s']\n" ${tcaVersion}
