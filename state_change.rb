module StateChanges
  class StateChange
    def starting_state
      YAML.load(@start_yaml)
    end
    def ending_state
      YAML.load(@end_yaml)
    end
    def initialize ss, es
      @start_yaml = YAML.dump(ss)
      @end_yaml = YAML.dump(es)
    end
    # we need to do a display thing here... observer type behavior?
  end

  # The initial gamestate
  class StartGame < StateChange
    def initialize ss
      super(ss, ss)
    end
  end
  class Move
    def initialize unit, p1, p2
      @unit = unit
      @start = p1
      @end = p2
    end
  end
end
