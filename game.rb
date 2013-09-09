require './permissive_fov'

class Game
  attr_reader :units
  include PermissiveFieldOfView
  def initialize(w, h, team_count=2)
    @width, @height = w, h
    @map = Array.new(w) do |x|
      Array.new(h) do |y|
        yield(x,y)
      end
    end
    @team_count = 0
    @current_team = 0
    @units =[]
  end

  def next_turn!
    @units.each do |u|
      u.restore_movement!
    end
    @current_team = (@current_team+1)%2
  end

  def current_team
    @current_team
  end

  MAP1 = <<-EOS
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xx......xxxxxxx..........................x
xx...............xxx.....................x
xx..xxxx.........xxxxxxxxxxxxxxxxx...xxxxx
xx..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...xxxxx
xx..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...xxxxx
xx......xxxxxxx..xxx.....................x
xxxxxxx...........xx...xxxxxxxxxxxxxx....x
xxxxxxxxxxxxx.....xx...xxxxxxxxxxxxxx....x
xxxxxxxxxxxxx.....xx...xxxxxxxxxxxxxx....x
xx................xx...xxxxxxxxxxxxxx....x
xx................xx...xxxxxxxxxxxxxx....x
xx....xxxxxxx..........xxxxxxxxxx........x
xx....xxxxxxx..xx......xxxxxxxxxx........x
xxxx...xxxxxx..xxxxxxxxxxxxxxxxxx.....xxxx
xxxx...xxxxxx..xxxxxxxxxxxxxxxxxx.....xxxx
xxxx............xxxxxxxxxxxxxxxxx.....xxxx
xxxxxxxxx...xxxxxxxxxxxxxxxxxxxxx.....xxxx
xxxxxxxxx...xxxxxxxxxxxxxxxxxxxxx.....xxxx
xxxxxxxxx.............................xxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.....xxxx
EOS

  MAP2 = <<-EOS
xxxxxxxxxxxxxxxxxxxx
x..................x
x..................x
x..xxxxxxxxxxxxxx..x
x..xxxxx....xxxxx..x
x..xxxxx....xxxxx..x
x...........xxxxx..x
x..xxxxx....xxxxx..x
x..xxxxx....xxxxx..x
x..xxxxxx..xxxxxx..x
x..xxxxxx..xxxxxx..x
x.....xx....xx.....x
x.....xx...........x
x.....xx....xx.....x
xxxxxxxxxxxxxxxxxxxx
  EOS

  def self.seeded(units_per_team, teams, map)
    w = map.split("\n").first.length
    map = map.gsub(/[ \n]/, '')
    h = map.length/w

    gs = Game.new(w,h) do |x,y|
      #rand(3) == 0 ? :wall : rand(3) == 0 ? :slime : :floor
      c = map[y*w + x]
      c == 'x' ? :wall : c == '.' ? :floor : :slime
    end

    classes = [Warrior, Assasin, Cleric, Cultist, Wizard, Rogue, SlimeMonster, Ent]

    (units_per_team*teams).times.map do |i|
      x,y = rand(w),rand(h)
      team = i%teams
      while gs.unit_at(x,y) || gs.blocked?(x,y)
        x,y = rand(w),rand(h)
      end
      gs.add_unit!(classes.shuffle.shift.new(x, y, i, team))
    end

    gs
  end

  def same?(o)
    o.each_with_x_y do |t,x,y|
      unless @map[x][y] == t
        puts "Tile at #{x}, #{y} is different. <#{@map[x][y]}><#{t}>"
        return false
      end
    end
    @units.count.times do |i|
      unless @units[i].same?(o.units[i])
        return false
      end
    end
    return true
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
    @unit_sees_friends = {}
    [0,1].each do |team|
      #TODO fix los to encapsulate this variable.
      @los_current_team = team
      units_by_team(team).each do |u|
        @current_viewer = u
        do_fov(u.x, u.y, u.sight_range)
      end
    end
  end
  def los_blocked?(x,y)
    blocked?(x,y)
  end
  def light(x,y)
    raise "Need a team!" unless @los_current_team
    @see_tiles[[@los_current_team, x, y]] = true
    if unit_at(x,y) && unit_at(x,y).team == @los_current_team && unit_at(x,y) != @current_viewer
      @unit_sees_friends[@current_viewer.uid] = true
    end
  end
  def can_see?(x,y,team)
    @see_tiles[[team, x, y]]
  end

  def blocked?(x,y)
    return true if x < 0 || x >= @width || y < 0 || y >= @height
    @map[x][y] == :wall
  end
  def open?(x,y)
   !blocked?(x,y)
  end
  def can_see_friends?(uid)
    @unit_sees_friends[uid]
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
    unit_at(*point) || blocked?(*point)
    # or, ice cube! or something.
  end
end
