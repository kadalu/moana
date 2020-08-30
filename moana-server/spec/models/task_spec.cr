require "./spec_helper"
require "../../src/models/task.cr"

describe Task do
  Spec.before_each do
    Task.clear
  end
end
