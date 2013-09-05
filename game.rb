class Game
  attr_reader :units

  def initialize(x,y)
    @map = Array.new(20) do
      Array.new(15) do
        yield(x,y)
      end
    end
    @units =[]
  end
  def add_unit!(unit)
    @units << unit
  end
  def unit_at(x,y)
    units.find{|u| u.x == x && u.y == y}
  end

  def each_with_x_y
    @map.each_with_index do |column, x|
      column.each_with_index do |tile, y|
        yield(tile,x,y)
      end
    end
  end
  def blocked?(x,y)
    @map[x][y] != :floor
  end
  def open?(x,y)
    @map[x][y] == :floor
  end
end
