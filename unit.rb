class Unit
  attr_accessor :x, :y, :moves, :uid, :hp, :team
  def initialize x,y, uid, team
    @x, @y = x, y
    @uid = uid
    @hp = max_hp
    @team = team
    @moves = [
      attack_class.new(attack_power),
      *class_moves,
      Movement.new(movement_range)
    ]
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
end

class Warrior < Unit
  attrs max_hp: 30,
    attack_power: 7,
    movement_range: 4,
    class_moves: [
      Knockback.new, # Push an opponent a few spaces.
      Defend.new, # for a few turns, damage shaving
    ],
    sprite: 8
end

class Assasin < Unit
  attrs max_hp: 15,
    attack_power: 3,
    movement_range: 7,
    class_moves: [
      # Blink.new(3),
      # ShadowMeld.new,
    ],
    attack_class: Assasinate,
    sprite: 44
end
