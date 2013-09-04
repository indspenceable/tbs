require 'gosu'
require './board'

# TODO this should all be encapsulated somewhere.
def point_dist(x,y,x2,y2)
  (x-x2).abs + (y-y2).abs
end
def distance(u1,u2)
  (u1.x - u2.x).abs + (u1.y-u2.y).abs
end
def _unit_at(units,x,y)
  units.find{|u| u.x == x && u.y == y}
end

class Movement
  def sprite
    58
  end
  def targetted?
    :path
  end
  def enact actor, game, path
    point = path[-1]
    actor.x = point[0]
    actor.y = point[1]
  end
end

class MeleeAttack
  def sprite
    53
  end
  def targetted?
    :select_from_targets
  end
  def targets actor, game
    game.units.select{|u| distance(u,actor) == 1 }.map do |u|
      [u.x, u.y]
    end
  end
  def enact actor, game, target
    puts "MeleeAttack#enact #{actor} attacked #{target}"
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
  def enact(unit, game, target)
    puts "heal #{target}"
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
          _targets << u
          break
        elsif game.blocked?(actor.x + x*(j+1), actor.y + y*(j+1))
          break
        end
      end
    end
    _targets.map{|u| [u.x, u.y]}
  end
  def enact(unit, game, target)
    puts "Ranged attack! -> #{target}"
  end
end

class Defend
  def sprite
    48
  end
  def targetted?
    false
  end
  def enact(unit, game)
    puts "DEFENDED #{unit}."
    # This will add a buff to the unit, which will expire in 1 turn.
  end
end

class Unit
  def sprite
    1
  end
  attr_accessor :x, :y, :moves
  def initialize x,y
    @x, @y = x, y
    @moves = [
      MeleeAttack.new,
      Movement.new,
      Defend.new,
      Bow.new,
    ]
  end
end

class GameUi < Gosu::Window
  def initialize
    super(640,480,false)

    @game = Game.new(20,15) do |x,y|
      rand(3) == 0 ? :wall : :floor
    end

    @tiles = Gosu::Image.load_tiles(self, 'tiles.png', 32, 32, true)
    @effects = Gosu::Image.load_tiles(self, 'effects.png', 32, 32, true)
    @chars = Gosu::Image.load_tiles(self, 'characters.png', 32, 32, true)
    @selector_x, @selector_y = 0,0

    (rand(50)+10).times.map do
      x,y = rand(20),rand(15)
      @game.add_unit!(Unit.new(x,y)) unless @game.unit_at(x,y) || @game.blocked?(x,y)
    end
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

  def draw
    @game.each_with_x_y do |tile, x, y|
      if tile==:floor
        @tiles[12].draw(x*32, y*32, 0)
      else
        @tiles[5].draw(x*32, y*32, 0)
      end
    end
    @game.units.each do |u|
      @chars[u.sprite].draw(u.x*32, u.y*32, 1)
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
    if @current_action == :select_unit
      @effects[123].draw(@selector_x*32, @selector_y*32, 0)
    end
  end

  def select_unit!
    u = @game.unit_at(@selector_x, @selector_y)
    if u
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
        @targets = @current_move.targets(@current_unit, @game)
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
      @current_move.enact(@current_unit, @game)
      unselect_unit!
    end
  end
  def select_target!
    @current_move.enact(@current_unit, @game, @targets[@target_index])
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
    elsif point_dist(*@path[-1], *point) == 1 && @game.open?(*point) && !@game.unit_at(*point)
      @path << point
    end
  end

  def select_path!
    @current_move.enact(@current_unit, @game, @path)
    @selector_x, @selector_y = @current_unit.x, @current_unit.y
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
