#!/usr/bin/env ruby

$: << "#{__dir__}/../lib"
require "omd"

Simple::CLI.run!(OMD::CLI)
