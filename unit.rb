class Unit
  attr_accessor :x, :y, :moves, :uid, :hp
  def initialize x,y, uid
    @x, @y = x, y
    @uid = uid
    @hp = max_hp
    @moves = [
      MeleeAttack.new(attack_power),
      *class_moves,
      Movement.new(movement_range)
    ]
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
    attack_power: 5,
    movement_range: 5,
    class_moves: [
      Knockback.new, # Push an opponent a few spaces.
      Defend.new, # for a few turns, damage shaving
    ],
    sprite: 1
end
