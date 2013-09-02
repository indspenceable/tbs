require 'gosu'

class Movement
  def sprite
    58
  end
end

class Attack
  def sprite
    53
  end
  def targetted?
    :select_from_targets
  end
  def targets actor, units
    units.select{|u| (u.x - actor.x).abs + (u.y-actor.y).abs == 1 }.map do |u|
      [u.x, u.y]
    end
  end
end

class Defend
  def sprite
    48
  end
  def targetted?
    false
  end
  def enact(unit)
    puts "DEFENDED #{unit}"
  end
end

class Unit
  attr_accessor :x, :y, :sprite, :moves
  def initialize x,y,sprite
    @x, @y, @sprite = x, y, sprite
    @moves = [
      Attack.new,
      Movement.new,
      nil,
      Defend.new,
    ]
  end
end

class Game < Gosu::Window
  def initialize
    super(640,480,false)

    @map = Array.new(20) do
      Array.new(15) do
        :floor
      end
    end

    @tiles = Gosu::Image.load_tiles(self, 'tiles.png', 32, 32, true)
    @effects = Gosu::Image.load_tiles(self, 'effects.png', 32, 32, true)
    @chars = Gosu::Image.load_tiles(self, 'characters.png', 32, 32, true)
    @selector_x, @selector_y = 0,0

    @units = [
      Unit.new(3,6,9),
      Unit.new(3,7,16),
      Unit.new(9,12,38)
    ]
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
    @map.each_with_index do |column, x|
      column.each_with_index do |tile, y|
        if tile==:floor
          @tiles[5].draw(x*32, y*32, 0)
        end
      end
    end
    @units.each do |u|
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
            @effects[u.moves[m].sprite].draw(
              (u.x + (m+0)%2 * ((m/2)*2-1))*32-8,
              (u.y + (m+1)%2 * ((m/2)*2-1))*32-8,
              2
            )
          end
        end
      end
    end
    if @current_action == :select_unit
      @effects[123].draw(@selector_x*32, @selector_y*32, 0)
    end
  end

  def unit_at(x,y)
    @units.find{|u| u.x == x && u.y == y}
  end

  def select_unit!
    u = unit_at(@selector_x, @selector_y)
    if u
      @current_action = :select_move
      @current_unit = u
      @current_move = nil
      @targets = nil
    end
  end
  def unselect_unit!
    @current_action = :select_unit
    @current_unit = nil
    @current_move =
    @targets = nil
  end
  def select_move!
    if @current_move.targetted?
      if @current_move.targetted? == :select_from_targets
        @current_action = :select_target
        @targets = @current_move.targets(@current_unit, @units - [@current_unit])
      end
    else
      @current_move.enact(@current_unit)
      unselect_unit!
    end
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
        # no-op
        puts "BOP"
        unselect_unit!
      end
    end
  end
end

Game.new.show
