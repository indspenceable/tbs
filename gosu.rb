require 'gosu'
require './lib/game_runner'
KEYS = {
  :left => Gosu::KbH,
  :right => Gosu::KbL,
  :up => Gosu::KbK,
  :down => Gosu::KbJ,
  :cancel => Gosu::KbEscape,
  :accept => Gosu::KbA,
}

class GosuDisplay < Gosu::Window
  SCREEN_WIDTH = 640
  SCREEN_HEIGHT = 480
  TILE_SIZE_X = 10
  TILE_SIZE_Y = 16

  include GameRunner

  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false)

    setup

    @character_tiles = Gosu::Image.load_tiles(self, 'char.png', 8, 8, true)
    @landscape_tiles = Gosu::Image.load_tiles(self, 'tiles.png', 24, 24, true)
    @effect_tiles    = Gosu::Image.load_tiles(self, 'tiles.png', 24, 24, true)
    @font = Gosu::Font.new(self, "courier", 12)
  end

  def tile_for_glyph(x,y)
    # return screen.map.draw_str('x') unless lit_spaces.nil? || lit_spaces.include?([x,y])
    c = @current_action.level.unit_at(x,y)
    if c
      color = TEAM_TO_COLOR[c.team]
      attrs = c.action_available ? 0 : Curses::A_BOLD
      return screen.map.draw_str(c.glyph, color, attrs)
    end


    {
      '.' => @landscape_tiles[0]
    }

  end

  def add_glyph(screen, x,y, highlight_squares, lit_spaces)

    tile_for_glyph(x,y).draw(x*TILE_SIZE_X, y*TILE_SIZE_Y, 0)
  end

  def display_character_info(screen)
    # raise "not implemented"
  end

  def display_messages(screen)
    # no-op
  end

  def draw_current_action(_)
    #butts
  end

  def draw
    display(nil)
  end

  def finish_display
  end

  #TODO this is not ideal but it lives here so fuck it.
  def button_down(id)
    if id == KEYS[:cancel]
      @current_action = @current_action.cancel
    else
      @current_action = @current_action.key(id)
    end
  end
end

# class GameWindow < Gosu::Window
#   def tiles
#     @tiles ||= {}
#   end
#   def initialize
#     super(SCREEN_WIDTH, SCREEN_HEIGHT, false)
#     @character_tiles = Gosu::Image.load_tiles(self, 'char.png', 8, 8, true)
#     @landscape_tiles = Gosu::Image.load_tiles(self, 'tiles.png', 24, 24, true)
#     @effect_tiles    = Gosu::Image.load_tiles(self, 'tiles.png', 24, 24, true)
#     @font = Gosu::Font.new(self, "courier", 12)

#     @mode = :select_unit

#     setup!
#   end
#   def setup!
#     @units = [
#       Unit.new(0, 'Will the archer', 0, 3, 3),
#       Unit.new(1, 'Bob the knight', 1, 2, 4)
#     ]
#     @map = Array.new(MAP_SIZE_X) do
#       Array.new(MAP_SIZE_Y) do
#         ' '
#       end
#     end
#     @x, @y = 0, 0
#   end

#   def char_at(x,y)
#     @units.find{|c| c.x == x && c.y == y}
#   end

#   def update
#     # noop
#   end

#   def draw_tile(x,y)
#     @landscape_tiles[0].draw(x*TILE_SIZE, y*TILE_SIZE, 0)
#   end

#   def draw_units
#     @units.each do |c|
#       @character_tiles[c.image_index].draw_as_quad(
#       (c.x+0)*TILE_SIZE, (c.y+0)*TILE_SIZE, Gosu::Color::WHITE,
#       (c.x+1)*TILE_SIZE, (c.y+0)*TILE_SIZE, Gosu::Color::WHITE,
#       (c.x+1)*TILE_SIZE, (c.y+1)*TILE_SIZE, Gosu::Color::WHITE,
#       (c.x+0)*TILE_SIZE, (c.y+1)*TILE_SIZE, Gosu::Color::WHITE,
#         1)
#     end
#   end

#   def mode
#     # do we have a unit?
#     return :select_unit unless @unit
#   end

#   def current_hovered_unit
#     char_at(@x,@y)
#   end

#   def draw
#     #draw the map
#     MAP_SIZE_X.times do |x|
#       MAP_SIZE_Y.times do |y|
#         draw_tile(x,y)
#       end
#     end
#     #draw all characters
#     draw_units
#     # show our the cursor
#     if mode == :select_unit
#       @effect_tiles[5].draw(@x*TILE_SIZE,@y*TILE_SIZE,2)
#     end

#     # are we hovering a tile? If so, draw the info panel
#     [@selected_unit, current_hovered_unit].uniq.compact.each_with_index do |u, i|
#       draw_info_panel(u, i)
#     end

#     if @path
#       puts "path is #{@path}"
#       @path.each do |x,y|
#         puts "x is #{x}, #{y}"
#         @effect_tiles[6].draw(x*TILE_SIZE,y*TILE_SIZE,2)
#       end
#     end
#   end

#   def draw_info_panel(c, i)
#     #@font.draw_rel(text.text, text.x - @camera_x, text.y - @camera_y, 999999, 0.5, 0.5, (TEXT_FADE_OUT - text.time)/2, (TEXT_FADE_OUT - text.time)/2, text.color)
#     @font.draw(c.name, TILE_SIZE*MAP_SIZE_X, 14*i, 3)
#   end

#   def button_down(id)
#     self.send("button_down_#{@mode}", id)
#   end
#   def button_down_select_unit(id)
#     case id
#     when Gosu::KbK
#       @y -= 1
#     when Gosu::KbH
#       @x -= 1
#     when Gosu::KbJ
#       @y += 1
#     when Gosu::KbL
#       @x += 1
#     when Gosu::KbA
#       if current_hovered_unit
#         @selected_unit = current_hovered_unit
#         @mode = :select_target
#         @path = [[@x, @y]]
#       end
#     when Gosu::KbEscape
#       exit
#     end
#   end

#   def set_path!
#     if @path.include?([@x,@y])
#       @path = (@path.take_while{|x| x != [@x,@y]} + [[@x,@y]])
#     else
#       @path << [@x, @y]
#     end
#   end

#   def valid_path?
#     @path.last == [@x,@y]
#   end

#   def button_down_select_target(id)
#     case id
#     when Gosu::KbK
#       @y -= 1
#       set_path!
#     when Gosu::KbH
#       @x -= 1
#       set_path!
#     when Gosu::KbJ
#       @y += 1
#       set_path!
#     when Gosu::KbL
#       @x += 1
#       set_path!
#     when Gosu::KbA
#       if valid_path?
#         @selected_unit.x = @x
#         @selected_unit.y = @y
#         @selected_unit = nil
#         @mode = :select_unit
#         @path = nil
#       else
#         # NOPE
#       end
#     when Gosu::KbEscape
#       @selected_unit = nil
#     end
#   end
# end

GosuDisplay.new.show
