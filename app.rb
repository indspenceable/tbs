require 'gosu'
require './game'
require './state_change'
require './actions'
require './unit'
require 'httparty'

ALPHA_COLOR = Gosu::Color.argb(0x66ffffff)

MAP_WIDTH_TILES = (ARGV[1] || 20).to_i
MAP_HEIGHT_TILES = (ARGV[2] || 15).to_i

MAP_WIDTH = MAP_WIDTH_TILES * 32
MAP_HEIGHT = MAP_HEIGHT_TILES * 32
UI_WIDTH = 160

FONT_SIZE = 16

raise "No team!" unless ARGV[0]
CURRENT_TEAM =  ARGV[0].to_i

class GameUi < Gosu::Window
  def initialize()
    super(MAP_WIDTH+UI_WIDTH,MAP_HEIGHT,false)

    @tiles = Gosu::Image.load_tiles(self, 'tiles.png', 32, 32, true)
    @effects = Gosu::Image.load_tiles(self, 'effects.png', 32, 32, true)
    @chars = Gosu::Image.load_tiles(self, 'characters.png', 32, 32, true)
    @font = Gosu::Font.new(self, "courier", FONT_SIZE)

    @selector_x, @selector_y = 0,0

    @state_changes = []
    current_state

    @current_action = :select_unit
    @current_unit = nil

    @camera_x = 0
    @camera_y = 0
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
    return nil unless @state_changes.any?
    # if this is the first time we are setting it, jump to the last state
    if @current_state_id == nil
      @current_state_id = @state_changes.length-1
      @state = @state_changes[@current_state_id].ending_state
    end
    # otherwise, only advance if we need to advance the state.
    if !most_recent_state? && can_update_state?
      @current_state_id += 1
      @count = 0
      @state = @state_changes[@current_state_id].ending_state
    end
    return @state
  end

  def tiles_to_sprite
    {:floor => 12, :wall => 5, :slime => 66}
  end

  def draw_map
    current_state.each_with_x_y do |tile, _x, _y|
      x, y = _x-@camera_x, _y-@camera_y
      next unless x < MAP_WIDTH_TILES && x >= 0 && y < MAP_HEIGHT_TILES && y >= 0
      @tiles[tiles_to_sprite[tile]].draw(x*32, y*32, 0)
      # draw fog
      if !current_state.can_see?(_x,_y,CURRENT_TEAM)
        @effects[172+2+16].draw(x*32, y*32, 0.5, 1, 1, ALPHA_COLOR)
      end
    end
  end

  def try_to_talk_to_server
    if @pending_move
      # @server.receive(YAML.dump(qscs))
      new_changes = HTTParty.post('http://localhost:4567/game', :body => {:action_yaml => @pending_move, :index => number_of_validated_state_changes}).body
      @pending_move = nil
      apply_state_changes_from_server(new_changes)
      return
    end

    @throttle ||= 0
    @throttle += 1
    return unless @throttle > 50
    @throttle = 0
    new_changes = HTTParty.get('http://localhost:4567/updates', :body => {:index => number_of_validated_state_changes}).body
    apply_state_changes_from_server(new_changes)
  end

  def draw
    try_to_talk_to_server
    return unless @state_changes.any?
    @count ||= 3
    @count += 1
    draw_map
    draw_units
    draw_doodads
  end

  def on_camera?(x,y)
    x >= @camera_x && x < @camera_x + MAP_WIDTH_TILES &&
    y >= @camera_y && y < @camera_y + MAP_HEIGHT_TILES
  end

  def draw_units
    current_state.units.each do |u|
      next unless current_state.can_see?(u.x, u.y, CURRENT_TEAM) && on_camera?(u.x,u.y)
      x, y = u.x-@camera_x, u.y-@camera_y

      @chars[u.sprite].draw(x*32, y*32, 1)
      @effects[3+2*u.team].draw_as_quad(x*32, y*32, Gosu::Color::WHITE,
        x*32, y*32 + 8, Gosu::Color::WHITE,
        x*32 + 8, y*32 + 8, Gosu::Color::WHITE,
        x*32 + 8, y*32, Gosu::Color::WHITE,
        1.5,)
    end
  end
  def draw_doodads
    draw_quad(
      MAP_WIDTH, 0, Gosu::Color::BLACK,
      MAP_WIDTH+UI_WIDTH, 0, Gosu::Color::BLACK,
      MAP_WIDTH+UI_WIDTH, MAP_HEIGHT, Gosu::Color::BLACK,
      MAP_WIDTH, MAP_HEIGHT, Gosu::Color::BLACK,
      0)
    # this goes in DRAW UI BOX
    if @current_action == :select_move
      # draw a box where the menu is going to go.


      @current_unit.moves.each_with_index do |move, index|
        color = @current_move ==  move ? Gosu::Color::RED : Gosu::Color::WHITE
        @font.draw(move.display_name, MAP_WIDTH, (FONT_SIZE+4)*index, 1, 1, 1, color)
      end
    else
      unit = (@target_index &&
        current_state.can_see?(*@targets[@target_index], CURRENT_TEAM) &&
        current_state.unit_at(*@targets[@target_index])) ||
        (@targets && @target_index.nil? &&
          current_state.can_see?(@selector_x, @selector_y, CURRENT_TEAM) &&
          current_state.unit_at(@selector_x, @selector_y))||
        (@current_action==:select_move &&
          @current_unit) ||
        (current_state.can_see?(@selector_x, @selector_y, CURRENT_TEAM) &&
          current_state.unit_at(@selector_x, @selector_y))

      if most_recent_state? && unit
        lines = []
        lines << unit.class_name
        lines << "Fatigue: #{%w(Unused Moved Attacked)[unit.fatigue]}"
        lines << ""
        lines << "#{unit.hp} / #{unit.max_hp}"
        lines.each_with_index do |l,i|
          @font.draw(l, MAP_WIDTH, (FONT_SIZE+4)*i, 10)
        end
      end
    end

    if most_recent_state?
      if @current_action == :select_path
        @path.each do |_x,_y|
          x, y = _x-@camera_x, _y-@camera_y
          @effects[173].draw(
            x*32,
            y*32,
            3
          )
        end
        @effects[171].draw(
          (@path_select_x-@camera_x)*32,
          (@path_select_y-@camera_y)*32,
          5
        )
      end
      if @current_action == :select_from_target_list
        @targets.each_with_index do |(_x,_y), i|
          x, y = _x-@camera_x, _y-@camera_y
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
      if @current_action == :select_target
        @targets.each_with_index do |(_x,_y), i|
          x, y = _x-@camera_x, _y-@camera_y
          if (_x == @selector_x) && (_y==@selector_y)
            # @effects[173].draw(
            #   x*32,
            #   y*32,
            #   3
            # )
          else
            @effects[171].draw(
              x*32,
              y*32,
              3
            )
          end
        end
        @effects[173].draw(
          (@selector_x-@camera_x)*32,
          (@selector_y-@camera_y)*32,
          4
        )
      end
    end
    if @current_action == :select_unit && most_recent_state?
      @effects[123].draw((@selector_x-@camera_x)*32, (@selector_y-@camera_y)*32, 0)
    end
  end

  def select_unit!
    u = current_state.unit_at(@selector_x, @selector_y)
    if u && u.team == CURRENT_TEAM
      @current_action = :select_move
      @current_unit = u
      @current_move = @current_unit.moves[0]
      @targets = nil
      @target_index = nil
      @path_select_x, @path_select_y = nil, nil
      @path = nil
      @old_select_x, @old_select_y = nil, nil
    end
  end
  def unselect_unit!
    @selector_x = @old_select_x || @selector_x
    @selector_y = @old_select_y || @selector_y
    @current_action = :select_unit
    @current_unit = nil
    @current_move =
    @targets = nil
    @target_index = nil
    @path_select_x, @path_select_y = nil, nil
    @path = nil
  end
  def select_move!
    return unless @current_move
    puts "CURRENT FATIGUE IS #{@current_unit.fatigue} MOVE FATIGUE IS #{@current_move.fatigue_level}"
    return unless @current_move.fatigue_level > @current_unit.fatigue

    if @current_move.targetted?
      if @current_move.targetted? == :select_from_target_list || @current_move.targetted? == :select_from_targets
        @targets = @current_move.targets(@current_unit.uid, current_state)
        # only move on if there are any targets...
        if @targets.any?
          if @current_move.targetted? == :select_from_target_list
            @current_action = :select_from_target_list
            @target_index = 0
          else
            @old_select_x, @old_select_y = @selector_x, @selector_y
            unless @targets.include?([@selector_x,@selector_y])
              # @selector_x, @selector_y = @targets[0]
            end
            @current_action = :select_target
          end
        else
          @targets = nil
        end
      elsif @current_move.targetted? == :path
        @current_action = :select_path
        @path = [[@current_unit.x, @current_unit.y]]
        @path_select_x, @path_select_y = @current_unit.x, @current_unit.y
      end
    else
      # add_state_changes! @current_move.add_state_changes(@current_unit, current_state)
      transmit_move_to_server(@current_move.prep(@current_unit.uid))
      unselect_unit!
    end
  end

  def prev_move!
    index = @current_unit.moves.index(@current_move)
    @current_move = @current_unit.moves[(index-1) % (@current_unit.moves.size)]
  end
  def next_move!
    index = @current_unit.moves.index(@current_move)
    @current_move = @current_unit.moves[(index+1) % (@current_unit.moves.size)]
  end

  def select_target_from_list!
    # add_state_changes! @current_move.add_state_changes(@current_unit, @targets[@target_index], current_state)
    transmit_move_to_server(@current_move.prep(@current_unit.uid, @targets[@target_index]))

    unselect_unit!
  end

  def select_target!
    point = [@selector_x, @selector_y]
    return unless @targets.include?(point)
    # add_state_changes! @current_move.add_state_changes(@current_unit, point, current_state)
    transmit_move_to_server(@current_move.prep(@current_unit.uid, point))

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

  def point_dist(x,y,x2,y2)
    (x-x2).abs + (y-y2).abs
  end

  def scroll_camera_to_point(p)
    x,y = p
    @camera_x -= 1 while @camera_x > x
    @camera_x += 1 while @camera_x <= (x-MAP_WIDTH_TILES)
    @camera_y -= 1 while @camera_y > y
    @camera_y += 1 while @camera_y <= (y-MAP_HEIGHT_TILES)
  end

  def update_path!
    point = [@path_select_x, @path_select_y]
    scroll_camera_to_point(point)
    if @path.include?(point)
      # shorten down to that point
      @path = @path[0,@path.index(point)+1]
    elsif point_dist(*@path[-1], *point) == 1 &&
      @current_move.valid_on_path?(point, current_state, CURRENT_TEAM) &&
      @path.length <= @current_move.max_path_length

      @path << point
    end
  end

  def apply_state_changes_from_server list
    @state_changes += YAML.load(list)
  end
  def number_of_validated_state_changes
    YAML.dump(@state_changes.count)
  end

  def transmit_move_to_server(yaml)
    @pending_move = yaml
  end

  def select_path!
    return unless [@path_select_x, @path_select_y] == @path.last
    # add_state_changes! @current_move.add_state_changes(@current_unit, @path, current_state)
    transmit_move_to_server(@current_move.prep(@current_unit.uid, @path))

    @selector_x, @selector_y = @path_select_x, @path_select_y
    unselect_unit!
  end

  def button_down(id)
    return exit if id == Gosu::KbEscape
    return unless @state_changes.any?

    case @current_action
    when :select_unit, :select_target
      case id
      when buttons[:left]
        @selector_x -= 1
        scroll_camera_to_point([@selector_x, @selector_y])
      when buttons[:right]
        @selector_x += 1
        scroll_camera_to_point([@selector_x, @selector_y])
      when buttons[:up]
        @selector_y -= 1
        scroll_camera_to_point([@selector_x, @selector_y])
      when buttons[:down]
        @selector_y += 1
        scroll_camera_to_point([@selector_x, @selector_y])
      when buttons[:select]
        return unless most_recent_state? && current_state.current_team == CURRENT_TEAM
        if @current_action == :select_unit
          select_unit!
        else
          select_target!
        end
      when buttons[:cancel]
        if @current_action == :select_unit
          # no op
        else
          unselect_unit!
        end
      end
    when :select_move
      case id
      when buttons[:left]
        # @current_move = @current_unit.moves[1] if @current_unit.moves[1]
      when buttons[:right]
        # @current_move = @current_unit.moves[3] if @current_unit.moves[3]
      when buttons[:up]
        prev_move!
        # @current_move = @current_unit.moves[0] if @current_unit.moves[0]
      when buttons[:down]
        # @current_move = @current_unit.moves[2] if @current_unit.moves[2]
        next_move!
      when buttons[:select]
        select_move!
      when buttons[:cancel]
        unselect_unit!
      end
    when :select_from_target_list
      case id
      when buttons[:left], buttons[:up]
        prev_target!
      when buttons[:right], buttons[:down]
        next_target!
      when buttons[:select]
        select_target_from_list!
      when buttons[:cancel]
        select_unit!
      end
    when :select_path
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

ui = GameUi.new()
ui.show
