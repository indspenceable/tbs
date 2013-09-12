
class Action
  def prep *args
    YAML.dump(arguments: args, class_name: self.class.name)
  end
  def self.exec(hash, starting_state)
    klass = const_get(hash[:class_name])
    raise "Must be an Action" unless klass < Action
    klass.state_changes(*hash[:arguments], starting_state)
  end

  def self.state_changes actor_uid, *args, starting_state
    scs = []
    raise "Can't use this move!" if starting_state.unit_by_id(actor_uid).fatigue >= fatigue_level
    scs += tire_other_units(actor_uid, starting_state)
    scs += enact_move(actor_uid, *args, scs.any?? scs.last.ending_state : starting_state)
    scs += fatigue_me(actor_uid, scs.any?? scs.last.ending_state : starting_state)
    scs
  end
  def self.tire_other_units actor_uid, starting_state
    # if no actor, return
    return unless actor_uid
    actor = starting_state.unit_by_id(actor_uid)
    ss = starting_state
    scs = []
    # everyone else on that team who has moved gets fatigued
    (ss.units_by_team(actor.team) - [actor]).select{
      |u| u.fatigue == 1
    }.each do |unit|
      scs << StateChange::Fatigue.new(ss, unit.uid, 2)
      ss = scs.last.ending_state
    end
    scs
  end
  def self.fatigue_me(actor_uid, starting_state)
    [StateChange::Fatigue.new(starting_state, actor_uid, fatigue_level)]
  end
  def self.fatigue_level
    2
  end
  def fatigue_level
    self.class.fatigue_level
  end
end

def distance(u1,u2)
  (u1.x - u2.x).abs + (u1.y-u2.y).abs
end

class Movement < Action
  def sprite
    58
  end

  def initialize mpl
    @max_path_length = mpl
  end

  def targetted?
    :path
  end

  def self.enact_move actor_uid, path, starting_state
    gs = starting_state
    state_changes = []

    # Holy Moley, this is ugly...
    catch(:interrupt_movement) do
      path[1,path.length-1].each do |point|
        if gs.block_movement?(actor_uid, point)
          state_changes << StateChange::Blocked.new(gs, actor_uid)
          throw(:interrupt_movement)
        else
          state_changes << StateChange::MoveUnit.new(gs, actor_uid, point)
          gs = state_changes.last.ending_state
          state_changes += gs.terrain_state_changes(actor_uid, point)
          gs = state_changes.last.ending_state
          throw(:interrupt_movement) if gs.unit_by_id(actor_uid).hp < 0
        end
      end
    end
    state_changes
  end

  def max_path_length
    @max_path_length
  end

  def valid_on_path?(point, game, team)
    game.open?(*point) && !(game.unit_at(*point) && game.can_see?(*point, team))
  end

  def display_name
    "Move"
  end
  def self.fatigue_level
    1
  end
end

class MeleeAttack < Action
  def sprite
    53
  end

  def targetted?
    :select_from_target_list
  end

  def initialize power
    @power = power
  end

  def targets actor_uid, game
    actor = game.unit_by_id(actor_uid)
    game.units.select{|u| distance(u,actor) == 1 && u.team != actor.team }.map do |u|
      [u.x, u.y]
    end
  end

  def self.enact_move actor_uid, target, starting_state
    [StateChange::Attack.new(starting_state, actor_uid, starting_state.unit_at(*target).uid, @power)]
  end

  def display_name
    "Attack"
  end
end

class Assasinate < MeleeAttack
  def self.enact_move actor_id, target, starting_state
    if starting_state.can_see_friends?(starting_state.unit_at(*target).uid)
      [StateChange::Attack.new(starting_state, actor_id, starting_state.unit_at(*target).uid, @power)]
    else
      [StateChange::Attack.new(starting_state, actor_id, starting_state.unit_at(*target).uid, @power*3)]
    end
  end

  def display_name
    "Assasinate"
  end
end

class Heal < Action
  def sprite
    20
  end
  def targetted?
    :select_from_target_list
  end
  def targets actor_uid, game
    actor = game.unit_by_id(actor_uid)
    game.units.select{|u| distance(u, actor) <= 3 }.map do |u|
      [u.x, u.y]
    end
  end
  def self.enact_move actor_uid, target, starting_state
    [StateChange::Heal.new(starting_state, actor_uid, starting_state.unit_at(*target).uid)]
  end
  def display_name
    "Heal"
  end
end

class Bow < Action
  def sprite
    64
  end
    def targetted?
    :select_from_target_list
  end
  def targets actor_uid, game
    actor = game.unit_by_id(actor_uid)
    _targets = []
    4.times do |i|
      x = (i+0)%2 * ((i/2)*2-1)
      y = (i+1)%2 * ((i/2)*2-1)
      5.times do |j|
        u = game.unit_at(actor.x + x*(j+1), actor.y + y*(j+1))
        if u
          _targets << u if u.team != actor.team
          break
        elsif game.blocked?(actor.x + x*(j+1), actor.y + y*(j+1))
          break
        end
      end
    end
    _targets.map{|u| [u.x, u.y]}
  end
  def self.enact_move actor_uid, target, starting_state
    [StateChange::Attack.new(starting_state, actor_uid, starting_state.unit_at(*target).uid)]
  end
  def display_name
    "Bow"
  end
end

class Defend < Action
  def sprite
    48
  end
  def targetted?
    false
  end
  def self.enact_move actor_uid, starting_state
    [StateChange::Defense.new(starting_state, actor_uid)]
  end
  def display_name
    "Defensive Stance"
  end
end

class Knockback < Action
  def sprite
    57
  end
  def targetted?
    :select_from_target_list
  end
  def targets actor_uid, game
    actor = game.unit_by_id(actor_uid)
    game.units.select{|u| distance(u,actor) == 1 && u.team != actor.team }.map do |u|
      [u.x, u.y]
    end
  end
  def self.enact_move actor_uid, target, starting_state
    actor = starting_state.unit_by_id(actor_uid)

    target_unit = starting_state.unit_at(*target)
    sx, sy = target_unit.x, target_unit.y
    state_changes = [
      StateChange::Knockback.new(starting_state, actor.uid, starting_state.unit_at(*target).uid)
    ]
    ending_state = state_changes.last.ending_state
    target_unit = ending_state.unit_by_id(target_unit.uid)
    nx, ny = target_unit.x, target_unit.y
    state_changes += ending_state.terrain_state_changes(target_unit.uid, [nx, ny]) if nx != sx || ny != sy
    state_changes
  end

  def display_name
    "Knockback"
  end
end
class BullRush < Knockback
  def self.enact_move actor_uid, target, starting_state
    actor = starting_state.unit_by_id(actor_uid)

    target_unit = starting_state.unit_at(*target)
    sx, sy = target_unit.x, target_unit.y
    state_changes = [
      StateChange::Knockback.new(starting_state, actor.uid, starting_state.unit_at(*target).uid),
    ]
    ending_state = state_changes.last.ending_state
    target_unit = ending_state.unit_by_id(target_unit.uid)
    nx, ny = target_unit.x, target_unit.y
    if nx != sx || ny != sy
      state_changes += ending_state.terrain_state_changes(target_unit.uid, [nx, ny])
      state_changes << StateChange::MoveUnit.new(state_changes.last.ending_state, actor.uid, [sx,sy])
    end
    state_changes
  end

  def display_name
    "Bull Rush"
  end
end

class Blink < Action
  def initialize range
    @range = range
  end
  def targetted?
    :select_from_targets
  end
  def targets actor_uid, game
    actor = game.unit_by_id(actor_uid)

    targets = []
    (actor.y-@range).upto(actor.y+@range).each do |y|
      targets += (actor.x-@range).upto(actor.x+@range).map do |x|
        [x,y] unless !game.can_see?(x,y,actor.team) || game.blocked?(x,y) || game.unit_at(x,y)
      end.compact
    end
    targets - [actor.x, actor.y]
  end
  def display_name
    "Blink"
  end
  def self.enact_move actor_uid, target, starting_state
    if starting_state.block_movement?(actor_uid, target)
      [StateChange::Blocked.new(starting_state, actor_uid)]
    else
      [StateChange::MoveUnit.new(starting_state, actor_uid, target)]
    end
  end
end
