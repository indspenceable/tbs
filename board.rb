class Board
  def initialize(x,y)
    @map = Array.new(20) do
      Array.new(15) do
        yield(x,y)
      end
    end
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
