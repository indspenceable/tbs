class Unit
  attr_accessor :x, :y, :moves, :uid, :hp, :team, :buffs
  def initialize x,y, uid, team
    @x, @y = x, y
    @uid = uid
    @hp = max_hp
    @team = team
    @moves = [
      attack_class.new(self),
      *class_moves.map{|x| x.new(self)},
      Defend.new(self),
      Movement.new(self)
    ]
    @buffs = []
  end

  def attack_class
    MeleeAttack
  end

  def sight_range
    5
  end

  def self.attrs hsh
    hsh.each do |k,v|
      define_method(k) do
        v
      end
    end
  end

  def end_of_turn_state_changes(game_state)
    gs = game_state
    scs = []
    buffs.each do |buff|
      scs += buff.end_of_turn_state_changes(gs)
      gs = scs.last.ending_state if scs.any?
    end
    if gs.terrain(x,y)
      scs += self.send(:"terrain_#{gs.terrain(x,y)}", gs)
    end
    scs
  end

  def respond_to? sym
    (sym.to_s =~ /\Abuffed_(.*)\z/ && respond_to?($1)) || super
  end
  # respond to "buffed_xxx methods by injecting them across this units buffs."
  def method_missing sym, *args
    if sym.to_s =~ /\Abuffed_(.*)\z/ && respond_to?($1)
      original_method_name = $1
      buffs.inject(self.send(original_method_name)) do |a, buff|
        method_name = :"adjusted_#{original_method_name}"
        if buff.respond_to?(method_name)
          buff.send(method_name, a)
        else
          a
        end
      end
    else
      super
    end
  end

  def fatigue= f
    @fatigue = f
  end
  def fatigue
    @fatigue
  end

  def class_name
    self.class.name
  end

  def same?(o)
    return false unless o.class == self.class
    [:x, :y, :uid, :hp, :team].each do |s|
      return false unless o.send(s) == self.send(s)
    end
    return true
  end
end

class Warrior < Unit
  attrs max_hp: 30,
    attack_power: 5,
    movement_range: 4,
    class_moves: [
      Knockback, # Push an opponent a few spaces.
      BullRush, # Like knockback, but also move the user.
      Defend, # for a few turns, damage shaving.
    ],
    sprite: 8
end

class Assasin < Unit
  attrs max_hp: 20,
    attack_power: 3,
    movement_range: 7,
    class_moves: [
      Blink,
      # ShadowMeld.new,
    ],
    attack_class: Assasinate,
    sprite: 44,
    blink_range: 3
end

class Cleric < Unit
  attrs max_hp: 25,
    attack_power: 4,
    movement_range: 5,
    class_moves: [
    ],
    sprite:38
end

class Cultist < Unit
  attrs max_hp: 20,
    attack_power: 5,
    movement_range: 5,
    class_moves: [
    ],
    sprite:39
end

class Wizard < Unit
  attrs max_hp: 15,
    attack_power: 3,
    movement_range: 5,
    class_moves: [
      # Fireball.new, # Burst damage, can hurt friendlys
      # Glacier.new, # Blocks a space for a couple of turns. Damages adjacent folks
      # Thunderbolt.new, # Hits in a line - can hurt friendlys
    ],
    sprite:45
end

class Rogue < Unit
  attrs max_hp: 20,
    attack_power: 4,
    movement_range: 7,
    class_moves: [
    ],
    sprite:35
end

class SlimeMonster < Unit
  attrs max_hp: 30,
    attack_power: 4,
    movement_range: 4,
    class_moves: [
    ],
    sprite: 178
end

class Ent < Unit
  attrs max_hp: 40,
    attack_power: 6,
    movement_range: 3,
    class_moves: [
    ],
    sprite: 183
end
