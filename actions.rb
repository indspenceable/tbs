
def distance(u1,u2)
  (u1.x - u2.x).abs + (u1.y-u2.y).abs
end

class Movement
  def sprite
    58
  end

  def initialize mpl
    @max_path_length = mpl
  end

  def targetted?
    :path
  end

  def add_state_changes actor, path, starting_state
    gs = starting_state
    state_changes = []

    # Holy Moley, this is ugly...
    catch(:interrupt_movement) do
      path[1,path.length-1].each do |point|
        if gs.block_movement?(actor.uid, point)
          state_changes << StateChange::Blocked.new(gs, actor.uid)
          throw(:interrupt_movement)
        else
          state_changes << StateChange::MoveUnit.new(gs, actor.uid, point)
          gs = state_changes.last.ending_state
          state_changes += gs.terrain_state_changes(actor.uid, point)
          gs = state_changes.last.ending_state
          throw(:interrupt_movement) if gs.unit_by_id(actor.uid).hp < 0
        end
      end
    end
    state_changes
  end

  def max_path_length
    @max_path_length
  end

  def valid_on_path?(point, game)
    game.open?(*point) && !(game.unit_at(*point) && game.can_see?(*point, 0))
  end

  def display_name
    "Move"
  end
end

class MeleeAttack
  def sprite
    53
  end

  def targetted?
    :select_from_targets
  end

  def initialize power
    @power = power
  end

  def targets actor, game
    game.units.select{|u| distance(u,actor) == 1 && u.team != actor.team }.map do |u|
      [u.x, u.y]
    end
  end

  def add_state_changes actor, target, starting_state
    [StateChange::Attack.new(starting_state, actor.uid, starting_state.unit_at(*target).uid, @power)]
  end

  def display_name
    "Attack"
  end
end

class Assasinate < MeleeAttack
  def add_state_changes actor, target, starting_state
    if starting_state.can_see_friends?(starting_state.unit_at(*target).uid)
      puts "BOOM"
      [StateChange::Attack.new(starting_state, actor.uid, starting_state.unit_at(*target).uid, @power)]
    else
      puts "Loom :("
      [StateChange::Attack.new(starting_state, actor.uid, starting_state.unit_at(*target).uid, @power*3)]
    end
  end

  def display_name
    "Assasinate"
  end
end

class Heal
  def sprite
    20
  end
  def targetted?
    :select_from_targets
  end
  def targets actor, game
    game.units.select{|u| distance(u, actor) <= 3 }.map do |u|
      [u.x, u.y]
    end
  end
  def add_state_changes actor, target, starting_state
    [StateChange::Heal.new(starting_state, actor.uid, starting_state.unit_at(*target).uid)]
  end
  def display_name
    "Heal"
  end
end

class Bow
  def sprite
    64
  end
    def targetted?
    :select_from_targets
  end
  def targets actor, game
    _targets = []
    4.times do |i|
      x = (i+0)%2 * ((i/2)*2-1)
      y = (i+1)%2 * ((i/2)*2-1)
      5.times do |j|
        puts "Looking at #{actor.x + x*(j+1)}, #{actor.y + y*(j+1)}"
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
  def add_state_changes actor, target, starting_state
    [StateChange::Attack.new(starting_state, actor.uid, starting_state.unit_at(*target).uid)]
  end
  def display_name
    "Bow"
  end
end

class Defend
  def sprite
    48
  end
  def targetted?
    false
  end
  def add_state_changes actor, starting_state
    [StateChange::Defense.new(starting_state, actor.uid)]
  end
  def display_name
    "Defensive Stance"
  end
end

class Knockback
  def sprite
    57
  end
  def targetted?
    :select_from_targets
  end
  def targets actor, game
    game.units.select{|u| distance(u,actor) == 1 && u.team != actor.team }.map do |u|
      [u.x, u.y]
    end
  end
  def add_state_changes actor, target, starting_state
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
