#!/bin/bash

grunt babel 
nodeunit src/compiled/tests/*.js
