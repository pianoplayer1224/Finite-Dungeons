# A timestamp
usage once/inf times
# effect:
allow an option to 'place timestamp' in shop, 
option then becomes 'travel to timestamp', 
which basicaaly time travles back to tur timestamp, 
option becomes 'place timestamp' again (if multipul uses per run), 
ie saveload
# unlock
tbd, sm to do with reward of the completing the puzzels ig
# implantation ideas
for each varaiable create a version that ends with a extra 't', 
eg 'player.hp' -— > 'player.hpt', 
when placed timestamp do sm like
```
def placet():
    player.hpt = player.hp
    player.moneyt = player.money
```
for every variable, and
```
def travel():
    player.hp = player.hpt
    player.money = player.moneyt
```
for all variable