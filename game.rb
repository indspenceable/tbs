require './permissive_fov'

class Game
  attr_reader :units
  include PermissiveFieldOfView
  def initialize(x,y)
    @width, @height = x, y
    @map = Array.new(20) do
      Array.new(15) do
        yield(x,y)
      end
    end
    @units =[]
  end
  def add_unit!(unit)
    raise "No id" unless unit.uid
    raise "Unit with that id already." if unit_by_id(unit.uid)
    raise "Unit at that position already." if unit_at(unit.x, unit.y)
    @units << unit
  end

  def units_by_team(team)
    units.select{|u| u.team == team}
  end

  def unit_at(x,y)
    units.find{|u| u.x == x && u.y == y}
  end
  def unit_by_id(uid)
    units.find{|u| u.uid == uid }
  end
  def remove_unit_by_id!(uid)
    units.delete(unit_by_id(uid))
  end

  def each_with_x_y
    @map.each_with_index do |column, x|
      column.each_with_index do |tile, y|
        yield(tile,x,y)
      end
    end
  end

  def calculate_los!
    @see_tiles = {}
    [0,1].each do |team|
      @current_team = team
      units_by_team(team).each do |u|
        do_fov(u.x, u.y, u.sight_range)
      end
    end
  end
  def los_blocked?(x,y)
    blocked?(x,y)
  end
  def light(x,y)
    raise "Need a team!" unless @current_team
    @see_tiles[[@current_team, x, y]] = true
  end
  def can_see?(x,y,team)
    @see_tiles[[team, x, y]]
  end

  def blocked?(x,y)
    @map[x][y] == :wall
  end
  def open?(x,y)
   !blocked?(x,y)
  end

  def terrain_state_changes(actor_uid, point)
    x,y = point
    sc = []
    if @map[x][y] == :slime
      sc << StateChange::Slime.new(self, actor_uid)
    end
    sc
  end

  def countdown_buffs(actor_uid)
    u = unit_by_id(actor_uid)
    # TODO make this work.
    []
  end

  def handle_deaths
    new_state_changes = []
    units.each do |unit|
      if unit.hp <= 0
        new_state_changes << StateChange::Death.new(self, unit.uid)
      end
    end
    new_state_changes
  end

  def block_movement?(uid, point)
    unit_at(*point)
    # or, ice cube! or something.
  end
end
