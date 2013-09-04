
# class Warrior < Unit
#   def initialize(x,y)
#     super(x,y)
#     @moves = [
#       MeleeAttack.new, # High damage.
#       Movement.new,
#       Knockback.new, # Push an opponent a few spaces.
#       Defend.new, # for a few turns, damage shaving
#     ]
#   end
# end
# class Rogue < Unit
#   def initialize
#     super(x,y)
#     @moves = [
#       PoisonNeedle.new, #Afflict poison status. Is this actually good?
#       Backstab.new, #Deal small damage, but large damage if flanking.
#       Movement.new,
#       #ShadowMeld.new, #Until next move, unattackable/unseeable (?)
#       SecretPassage.new, #Move through secret passages
#     ]
#   end
# end
# class Cleric < Unit
#   def initialize
#     super(x,y)
#     @moves = [
#       Movement.new,
#       Ankh.new, # Heals+removes debuffs, needs LOF
#       DivineShield.new,
#       Illuminate.new, # Anywhere nearby - display that location and neighboring
#                       # squares. Damage enemies on that square right now.
#     ]
#   end
# end

# class Cultist < Unit
#   def initialize
#     super(x,y)
#     @moves = [
#       Shadow.new, # Attack at range 2! Costs life.
#       Sacrafice.new, #Kill an ally for a temporary boost to all other nearby allies. Costs life
#       UnholyWill.new, #Additional damage for an ally, Costs life.
#       Movement.new,
#     ]
#   end
# end

# class Wizard < Unit
#   def initialize
#     super(x,y)
#     @moves = [
#       Movement.new,
#       Fireball.new, # Burst damage, can hurt friendlys
#       Glacier.new, # Blocks a space for a couple of turns. Damages adjacent folks
#       Thunderbolt.new, # Hits in a line - can hurt friendlys
#     ]
#   end
# end

# class SlimeMonster < Unit
#   def initialize
#     super(x,y)
#     @moves = [
#       Movement.new(:slime), # Leaves a trail of damaging slime wherever it goes.
#       Corode.new, # Hit an enemy and reduce the damage they do on attacks.
#       Constrict.new, # Stop an enemy from moving
#       Ooze.new, # Move through secret passages in this level?
#     ]
#   end
# end

# class Treante < Unit
#   def initialize
#     super(x,y)
#     @moves = [
#       Root.new, #regenreat HP every turn, but can't move until you use the move again
#       RootSlap.new, # Hit enemy at range, more range when rooted.
#       Defend.new, #Barkskin
#       Movement.new, #very little.
#     ]
#   end
# end

# class LivingFlame < Unit
#   def initialize(x,y)
#     super(x,y)
#     @moves = [
#       Nova.new, # hit friends and foes
#       Exploder.new, # sac self, more damage the more HP left, hits friends and foes
#       Movement.new(:flame), # leaves a trail of fire that other people take damage in
#       FlameJet.new, #Also leaves a trail of flame, does low damage if it hits something.
#     ]
#   end
# end
# class Mummy < Unit
#   def initialize(x,y)
#     super(x,y)
#     @moves = [
#       Grapple.new, #Pull mummy to enemy
#       Pull.new, #pull enemy to mummy
#       MummyTouch.new, #Med damage
#       Movement.new, #slow movement
#     end
#   end
# end
# class Assasin < Unit
#   def initialize(x,y)
#     super(x,y)
#     @moves = [
#       Assasinate.new, # tiny damage, unless target can see no friends, in which
#                       # case huge damage
#       Blink.new, # Or ShadowMeld
#       PoisonNeedle.new, # Poison
#       Movement.new, #Fast
#     ]
#   end
# end
# class Shadow < Unit
#   def initialize(x,y)
#     super(x,y)
#     @moves = [
#       Dispel.new, # Remove buffs/debuffs, and deals damage for each that it does. Can use on friends
#       DarkTouch.new, # Damage + shows this character despite LOS.
#       ShadowBlink.new, # Instantly teleport a couple of spaces, but only if no one can see you
#       ShadowMeld.new, # Removes from LOS if there's no adjacent opponent.
#     ]
#   end
# end

=begin
PoisonNeedle
Blink (Tele in a small radius)
Forcecage - blocks off an empty space
StopTheClock - stops a character from doing anything next turn

Smokebomb - Blocks LOS in spaces around this char.


Fireball - Does Splash Damage
EnemyTeleSwap - Swap places with an enemy
FriendlyTeleSwap - Swap places with an ally

=end
