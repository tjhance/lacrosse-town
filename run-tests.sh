#!/bin/bash

grunt ts:server
nodeunit src/compiled/tests/*.js
