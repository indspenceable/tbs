class Buff
  def initialize duration, *_
    @duration = duration
  end
  def display_name
    raise "#display_name not implemented for #{self.class.name}"
  end
  def end_of_turn_state_changes(state_change)
  end
  def tick
    @duration -= 1
  end
  def expired?
    @duration <= 0
  end

end

class AttackUp < Buff
  def initialize duration, p
    super
    @p = p
  end
  def display_name
    "+#{@p} atk (#{@duration})"
  end
  def adjusted_attack_power(p)
    p+@p
  end
end
