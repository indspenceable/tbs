require './buff'

class Action
  def initialize unit
    @unit = unit
  end

  def prep *args
    YAML.dump(arguments: args, klass: self)
  end
  def self.exec(hash, starting_state)
    # klass = const_get(hash[:class_name])
    klass = hash[:klass]
    raise "Must be an Action" unless hash[:klass].is_a? Action
    klass.state_changes(*hash[:arguments], starting_state)
  end

  def state_changes actor_uid, *args, starting_state
    scs = []
    raise "Can't use this move!" if starting_state.unit_by_id(actor_uid).fatigue >= fatigue_level
    scs += tire_other_units(actor_uid, starting_state)
    scs += enact_move(actor_uid, *args, scs.any?? scs.last.ending_state : starting_state)
    scs += fatigue_me(actor_uid, scs.any?? scs.last.ending_state : starting_state)
    scs
  end
  def tire_other_units actor_uid, starting_state
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
  def fatigue_me(actor_uid, starting_state)
    [StateChange::Fatigue.new(starting_state, actor_uid, fatigue_level)]
  end
  def fatigue_level
    2
  end
end

def distance(u1,u2)
  (u1.x - u2.x).abs + (u1.y-u2.y).abs
end

class Movement < Action
  def sprite
    58
  end

  def targetted?
    :path
  end

  def enact_move actor_uid, path, starting_state
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
    @unit.buffed_movement_range
  end

  def valid_on_path?(point, game, team)
    game.open?(*point) && !(game.unit_at(*point) && game.can_see?(*point, team))
  end

  def display_name
    "Move"
  end
  def fatigue_level
    1
  end
end

class EndTurn < Action
  def state_changes starting_state
    [
      StateChange::NextTurn.new(starting_state)
    ]
  end
end

class MeleeAttack < Action
  def sprite
    53
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

  def enact_move actor_uid, target, starting_state
    [StateChange::Attack.new(starting_state, actor_uid, starting_state.unit_at(*target).uid, @unit.buffed_attack_power)]
  end

  def display_name
    "Attack"
  end
end

class Assasinate < MeleeAttack
  def enact_move actor_id, target, starting_state
    if starting_state.can_see_friends?(starting_state.unit_at(*target).uid)
      [StateChange::Attack.new(starting_state, actor_id, starting_state.unit_at(*target).uid, @unit.buffed_attack_power)]
    else
      [StateChange::Attack.new(starting_state, actor_id, starting_state.unit_at(*target).uid, @unit.buffed_attack_power*3)]
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
  def enact_move actor_uid, target, starting_state
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
  def enact_move actor_uid, target, starting_state
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
  def enact_move actor_uid, starting_state
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
  def enact_move actor_uid, target, starting_state
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
  def enact_move actor_uid, target, starting_state
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
  def targetted?
    :select_from_targets
  end
  def targets actor_uid, game
    actor = game.unit_by_id(actor_uid)

    targets = []
    (actor.y-@unit.buffed_blink_range).upto(actor.y+@unit.buffed_blink_range).each do |y|
      targets += (actor.x-@unit.buffed_blink_range).upto(actor.x+@unit.buffed_blink_range).map do |x|
        [x,y] unless !game.can_see?(x,y,actor.team) || game.blocked?(x,y) || game.unit_at(x,y)
      end.compact
    end
    targets - [actor.x, actor.y]
  end
  def display_name
    "Blink"
  end
  def enact_move actor_uid, target, starting_state
    if starting_state.block_movement?(actor_uid, target)
      [StateChange::Blocked.new(starting_state, actor_uid)]
    else
      [StateChange::MoveUnit.new(starting_state, actor_uid, target)]
    end
  end
end
