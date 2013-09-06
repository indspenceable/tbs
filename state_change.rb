require 'yaml'
module StateChange
  class StateChange
    def starting_state
      YAML.load(@start_yaml)
    end
    def ending_state
      YAML.load(@end_yaml)
    end
    def initialize ss, *_
      @start_yaml = YAML.dump(ss)
      s = starting_state
      enact(s)
      @end_yaml = YAML.dump(s)
    end
    # we need to do a display thing here... observer type behavior?
  end

  # The initial gamestate
  class StartGame < StateChange
    def initialize ss
      super(ss)
    end
    def enact(gs)
    end
  end

  # Move a unit to a space
  class MoveUnit < StateChange
    def initialize ss, uid, point
      @uid = uid
      @point = point
      super(ss)
    end
    def enact(gs)
      u = gs.unit_by_id(@uid)
      u.x, u.y = @point
    end
  end

  class Attack < StateChange
    def initialize ss, uid, target_id, power
      @uid = uid
      @tuid = target_id
      @power = power
      super(ss)
    end
    def enact(gs)
      u = gs.unit_by_id(@uid)
      t = gs.unit_by_id(@tuid)
      t.hp -= @power
    end
  end

  class Knockback < StateChange
    def initialize ss, uid, target_id
      @uid = uid
      @tuid = target_id
      super(ss)
    end
    def enact(gs)
      u = gs.unit_by_id(@uid)
      t = gs.unit_by_id(@tuid)
      #TODO make sure that unit can move to that location.
      t.x += (t.x - u.x)
      t.y += (t.y - u.y)
      t.hp -= 3
    end
  end

  class Heal < StateChange
    def initialize ss, uid, target_id
      @uid = uid
      @tuid = target_id
      super(ss)
    end
    def enact(gs)
      u = gs.unit_by_id(@uid)
      t = gs.unit_by_id(@tuid)
      t.hp += 3
    end
  end

  class Defense < StateChange
    def initialize ss, uid
      @uid = uid
      super(ss)
    end
    def enact(gs)
    end
  end

  class Slime < StateChange
    def initialize ss, uid
      @uid = uid
      super(ss)
    end
    def enact(gs)
      u = gs.unit_by_id(@uid)
      u.hp -= 3
    end
  end

  class Death < StateChange
    def initialize ss, uid
      @uid = uid
      super(ss)
    end
    def enact(gs)
      gs.remove_unit_by_id!(@uid)
    end
  end
end
