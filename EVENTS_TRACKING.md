# Event Tracking Implementation

This document describes all the analytics events that have been implemented throughout the game using AxolAPI.

## Event Types

### sendEvent(name, value)
All events use this method with optional numeric values

---

## Implemented Events

### Title & Menu Flow
- **GAME_START** - Sent when Globals.init() is called (game launches)
  - Location: `Globals.hx`
  
- **TITLE_TO_OFFICE** - Player leaves title screen and enters office
  - Location: `TitleState.hx`

### Office Interactions
- **PORTAL_ENTER** - Player clicks portal to start a run
  - Value: Current money amount
  - Location: `OfficeState.hx`

- **DESK_CLICKED** - Player clicks desk (catalog view - not yet implemented)
  - Location: `OfficeState.hx`

- **PHONE_CLICKED** - Player clicks phone (shop - not yet implemented)
  - Location: `OfficeState.hx`

- **TRASH_CLICKED** - Player clicks trash can to view clear data dialog
  - Location: `OfficeState.hx`

- **DATA_CLEARED_CREATURES** - Player confirms clearing save data
  - Value: Number of creatures that were deleted
  - Location: `OfficeState.hx`

- **DATA_CLEARED_MONEY** - Player confirms clearing save data
  - Value: Amount of money that was lost
  - Location: `OfficeState.hx`

### Gameplay Events
- **RUN_START** - Player fades in and gains control in PlayState
  - Value: Starting O2 amount
  - Location: `PlayState.hx`

- **PHOTO_TAKEN** - Player takes a photo
  - Value: Number of enemies captured in that photo (0 if missed)
  - Location: `PlayState.hx`

- **OUT_OF_FILM** - Player tries to take photo but has no film left
  - Location: `Player.hx`

- **FILM_DEPLETED** - Player just used their last piece of film
  - Location: `Player.hx`

- **ENEMY_HIT** - Player gets hit by an enemy
  - Value: Damage dealt (1-5 O2)
  - Location: `PlayState.hx`

- **RUN_COMPLETE** - Player successfully returns through portal
  - Value: Remaining O2 when exiting
  - Location: `PlayState.hx`

- **PHOTOS_CAPTURED** - Sent when completing a run
  - Value: Number of photos captured in that run
  - Location: `PlayState.hx`

### Death/Failure Events
- **O2_DEPLETED** - Player ran out of oxygen
  - Value: 0 (no O2 left)
  - Location: `PlayState.hx`

- **ENEMY_KNOCKOUT** - Enemy hit caused player to run out of O2
  - Value: Enemy power level that dealt the final blow
  - Location: `PlayState.hx`

### Results & Saving
- **CREATURE_SAVED** - Player successfully saves a creature
  - Value: Reward amount ($) earned from that save
  - Location: `GameResults.hx`

- **OFFICE_RETURN_NO_SAVES** - Player returns to office without saving any creatures
  - Location: `GameResults.hx`

- **OFFICE_RETURN_ALL_SAVED** - Player returns to office after saving all creatures
  - Value: Total number of creatures saved
  - Location: `GameResults.hx`

---

## Analytics Use Cases

### Player Engagement
- Track how many runs players start vs complete
- See average O2 remaining when exiting (are runs too easy/hard?)
- Monitor title screen → office → portal conversion

### Difficulty Tuning
- Compare O2_DEPLETED vs ENEMY_KNOCKOUT deaths
- Track average damage taken per run (via ENEMY_HIT events)
- Monitor how many photos players successfully capture per run

### Economy Tracking
- Total money earned via CREATURE_SAVED scores
- See how much progress players lose when clearing data
- Track portal entries with money values to see progression curve

### Feature Usage
- Monitor DESK_CLICKED and PHONE_CLICKED for future feature prioritization
- Track OUT_OF_FILM to tune film capacity
- See PHOTO_TAKEN success rate (value > 0 vs value = 0)

### Player Behavior
- How many players clear their save data (DATA_CLEARED events)?
- Do players return through portal with no photos (OFFICE_RETURN_NO_SAVES)?
- What's the typical run length? (time between RUN_START and RUN_COMPLETE/death)

---

## Example Queries

### Completion Rate
```
successful_runs = count(RUN_COMPLETE)
total_runs = count(RUN_START)
completion_rate = successful_runs / total_runs
```

### Average Photos Per Run
```
avg_photos = avg(PHOTOS_CAPTURED.value)
```

### Death Analysis
```
o2_deaths = count(O2_DEPLETED)
enemy_deaths = count(ENEMY_KNOCKOUT)
death_type_ratio = o2_deaths / enemy_deaths
```

### Economy Tracking
```
total_earned = sum(CREATURE_SAVED.value)
avg_per_save = avg(CREATURE_SAVED.value)
```
