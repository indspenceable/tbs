require 'sinatra'
require './game'
require './state_change'
require './actions'
require './unit'


class Server
  def initialize
    @state_changes = [StateChange::StartGame.new(Game.seeded(2,2, Game::MAP1))]
  end
  def receive move
    move = YAML.load(move)

    @state_changes += Action.exec(move, @state_changes.last.ending_state)
  end

  def newer_changes(number_yaml)
    index = YAML.load(number_yaml)
    if @state_changes.length > index
      YAML.dump(@state_changes[index, @state_changes.length])
    else
      YAML.dump([])
    end
  end
end

s = Server.new

post '/game' do
  s.receive(params[:action_yaml])
  s.newer_changes(params[:index])
end
get '/updates' do
  s.newer_changes(params[:index])
end
