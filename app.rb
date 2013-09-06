require 'gosu'
require './game'
require './state_change'

ALPHA_COLOR = Gosu::Color.argb(0x66ffffff)

# TODO this should all be encapsulated somewhere.
def point_dist(x,y,x2,y2)
  (x-x2).abs + (y-y2).abs
end
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
end

class Assasinate < MeleeAttack
  def add_state_changes actor, target, starting_state
    if false
      [StateChange::Attack.new(starting_state, actor.uid, starting_state.unit_at(*target).uid, @power*3)]
    else
      [StateChange::Attack.new(starting_state, actor.uid, starting_state.unit_at(*target).uid, @power)]
    end
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
    state_changes = [
      StateChange::Knockback.new(starting_state, actor.uid, starting_state.unit_at(*target).uid)
    ]
    state_changes += state_changes.last.ending_state.terrain_state_changes(actor.uid, point)
  end
end

require './unit.rb'

class GameUi < Gosu::Window
  def initialize
    super(640,480,false)


    starting_game_state = Game.new(20,15) do |x,y|
      rand(2) == 0 ? :wall : rand(3) == 0 ? :slime : :floor
    end


    @tiles = Gosu::Image.load_tiles(self, 'tiles.png', 32, 32, true)
    @effects = Gosu::Image.load_tiles(self, 'effects.png', 32, 32, true)
    @chars = Gosu::Image.load_tiles(self, 'characters.png', 32, 32, true)
    @selector_x, @selector_y = 0,0

    classes = [Warrior, Assasin]

    16.times.map do |i|
      x,y = rand(20),rand(15)
      team = i%2
      while starting_game_state.unit_at(x,y) || starting_game_state.blocked?(x,y)
        x,y = rand(20),rand(15)
      end

      starting_game_state.add_unit!(classes.shuffle.shift.new(x, y, i, team))
    end

    @state_changes = [StateChange::StartGame.new(starting_game_state)]
    current_state


    @current_action = :select_unit
    @current_unit = nil
  end

  def buttons
    # {
    #   :left => Gosu::Gp0Left,
    #   :right => Gosu::Gp0Right,
    #   :up => Gosu::Gp0Up,
    #   :down => Gosu::Gp0Down,
    #   :cancel => Gosu::Gp0Button1,
    #   :select => Gosu::Gp0Button5,
    # }
    {
      left: Gosu::KbLeft,
      right: Gosu::KbRight,
      up: Gosu::KbUp,
      down: Gosu::KbDown,
      cancel: Gosu::KbX,
      select: Gosu::KbZ,
    }
  end

  def can_update_state?
    @count ||= 3
    @count >= 3
  end

  def most_recent_state?
    @current_state_id == @state_changes.length-1
  end

  def most_recent_state
    @state_changes[-1].ending_state
  end

  def current_state
    @current_state_id ||= -1
    if (!most_recent_state? && can_update_state?) || @state.nil?
      @current_state_id += 1
      @count = 0
      @state = @state_changes[@current_state_id].ending_state
    end
    return @state


    @state_count ||= -1
    return @state if @state_count < @state_changes.length ||
      (@state && !can_update_state?)
    @state_count += 1
    @cached_state = @state_changes[@state_count]
    @state = @cached_state.ending_state
    @count = 0
    @state
  end

  def tiles_to_sprite
    {:floor => 12, :wall => 5, :slime => 66}
  end

  def draw
    @count ||= 3
    @count += 1

    current_state.each_with_x_y do |tile, x, y|
      @tiles[tiles_to_sprite[tile]].draw(x*32, y*32, 0)
      # draw fog
      if !current_state.can_see?(x,y,0)
        @effects[172+2+16].draw(x*32, y*32, 0.5, 1, 1, ALPHA_COLOR)
      end
    end
    current_state.units.each do |u|
      next unless current_state.can_see?(u.x, u.y, 0)
      @chars[u.sprite].draw(u.x*32, u.y*32, 1)
      @effects[3+2*u.team].draw_as_quad(u.x*32, u.y*32, Gosu::Color::WHITE,
        u.x*32, u.y*32 + 8, Gosu::Color::WHITE,
        u.x*32 + 8, u.y*32 + 8, Gosu::Color::WHITE,
        u.x*32 + 8, u.y*32, Gosu::Color::WHITE,
        1.5,)
      if u == @current_unit && @current_action == :select_move
        4.times do |m|
          next unless u.moves[m]
          @effects[u.moves[m].sprite].draw(
            (u.x + (m+0)%2 * ((m/2)*2-1))*32,
            (u.y + (m+1)%2 * ((m/2)*2-1))*32,
            2
          )
          #TODO make this better
          if @current_move == u.moves[m]
            @effects[139].draw(
              (u.x + (m+0)%2 * ((m/2)*2-1))*32,
              (u.y + (m+1)%2 * ((m/2)*2-1))*32,
              2
            )
          end
        end
      end
    end

    if most_recent_state?
      if @current_action == :select_path
        @path.each do |x,y|
          @effects[173].draw(
            x*32,
            y*32,
            3
          )
        end
        @effects[171].draw(
          @path_select_x*32,
          @path_select_y*32,
          5
        )
      end
      if @current_action == :select_target
        @targets.each_with_index do |(x,y), i|
           if i == @target_index
            @effects[173].draw(
              x*32,
              y*32,
              3
            )
          else
            @effects[171].draw(
              x*32,
              y*32,
              3
            )
          end
        end
      end
    end
    if @current_action == :select_unit && most_recent_state?
      @effects[123].draw(@selector_x*32, @selector_y*32, 0)
    end
  end

  def select_unit!
    u = current_state.unit_at(@selector_x, @selector_y)
    if u && u.team == 0
      @current_action = :select_move
      @current_unit = u
      @current_move = nil
      @targets = nil
      @target_index = nil
      @path_select_x, @path_select_y = nil, nil
      @path = nil
    end
  end
  def unselect_unit!
    @current_action = :select_unit
    @current_unit = nil
    @current_move =
    @targets = nil
    @target_index = nil
    @path_select_x, @path_select_y = nil, nil
    @path = nil
  end
  def select_move!
    if @current_move.targetted?
      if @current_move.targetted? == :select_from_targets
        @targets = @current_move.targets(@current_unit, current_state)
        # only move on if there are any targets...
        if @targets.any?
          @current_action = :select_target
          @target_index = 0
        else
          @targets = nil
        end
      elsif @current_move.targetted? == :path
        @current_action = :select_path
        @path = [[@current_unit.x, @current_unit.y]]
        @path_select_x, @path_select_y = @current_unit.x, @current_unit.y
      end
    else
      add_state_changes! @current_move.add_state_changes(@current_unit, current_state)
      unselect_unit!
    end
  end

  def select_target!
    add_state_changes! @current_move.add_state_changes(@current_unit, @targets[@target_index], current_state)
    unselect_unit!
  end

  def prev_target!
    @target_index -= 1
    @target_index = @targets.size-1 if @target_index == -1
  end
  def next_target!
    @target_index += 1
    @target_index = 0 if @target_index == @targets.size
  end
  def current_target
    @targets[@target_index]
  end

  def update_path!
    point = [@path_select_x, @path_select_y]
    if @path.include?(point)
      # shorten down to that point
      @path = @path[0,@path.index(point)+1]
    elsif point_dist(*@path[-1], *point) == 1 &&
      @current_move.valid_on_path?(point, current_state) &&
      @path.length <= @current_move.max_path_length

      @path << point
    end
  end

  def add_state_changes! list
    @state_changes += list
    @state_changes += most_recent_state.countdown_buffs(@current_unit.uid)
    @state_changes += most_recent_state.handle_deaths
   end

  def select_path!
    return unless [@path_select_x, @path_select_y] == @path.last
    add_state_changes! @current_move.add_state_changes(@current_unit, @path, current_state)
    @selector_x, @selector_y = @path_select_x, @path_select_y
    unselect_unit!
  end

  def button_down(id)
    return exit if id == Gosu::KbEscape

    if @current_action == :select_unit
      case id
      when buttons[:left]
        @selector_x -= 1
      when buttons[:right]
        @selector_x += 1
      when buttons[:up]
        @selector_y -= 1
      when buttons[:down]
        @selector_y += 1
      when buttons[:select]
        select_unit!
      when buttons[:cancel]
        # no-op
        puts :cancel
      end
    elsif @current_action == :select_move
      case id
      when buttons[:left]
        @current_move = @current_unit.moves[1] if @current_unit.moves[1]
      when buttons[:right]
        @current_move = @current_unit.moves[3] if @current_unit.moves[3]
      when buttons[:up]
        @current_move = @current_unit.moves[0] if @current_unit.moves[0]
      when buttons[:down]
        @current_move = @current_unit.moves[2] if @current_unit.moves[2]
      when buttons[:select]
        select_move!
      when buttons[:cancel]
        unselect_unit!
      end
    elsif @current_action == :select_target
      case id
      when buttons[:left], buttons[:up]
        prev_target!
      when buttons[:right], buttons[:down]
        next_target!
      when buttons[:select]
        select_target!
      when buttons[:cancel]
        select_unit!
      end
    elsif @current_action == :select_path
      case id
      when buttons[:left]
        @path_select_x -= 1
        update_path!
      when buttons[:right]
        @path_select_x += 1
        update_path!
      when buttons[:up]
        @path_select_y -= 1
        update_path!
      when buttons[:down]
        @path_select_y += 1
        update_path!
      when buttons[:select]
        select_path!
      when buttons[:cancel]
        unselect_unit!
      end
    end
  end
end

GameUi.new.show
