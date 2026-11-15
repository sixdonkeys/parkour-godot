# Survey: movement-numbers

Fetched 2026-11-15. Excerpts are word for word from the address above them. The Wikipedia text is CC BY-SA 4.0; it is quoted here for study only and nothing from it ships. Wikipedia excerpts are in wiki markup, as served by `action=raw`.

## What a trained athlete does

### Wikipedia, "Footspeed" — https://en.wikipedia.org/w/index.php?title=Footspeed&action=raw

> The record is 44.72&nbsp;km/h (27.78&nbsp;mph), measured between metre 60 and metre 80 of the [[100 metres]] sprint at the [[2009 World Championships in Athletics]] by [[Usain Bolt]].

> (Bolt's ''average'' speed over the course of this race was 37.578&nbsp;km/h or 23.35&nbsp;mph.)

### Wikipedia, "Sprint (running)" — https://en.wikipedia.org/w/index.php?title=Sprint_(running)&action=raw

> Some of the fastest humans reach their maximum speed around the 60-metre mark.

### Wikipedia, "Long jump" — https://en.wikipedia.org/w/index.php?title=Long_jump&action=raw

> Powell's record of {{T&Fcalc|8.95}} has now stood for over

> Elite jumpers usually leave the ground at an angle of 20° or less;

> The greater the speed at takeoff, the longer the trajectory of the center of mass will be.

### Wikipedia, "Standing long jump" — https://en.wikipedia.org/w/index.php?title=Standing_long_jump&action=raw

> The current unofficial record is held by [[Byron Jones (American football)|Byron Jones]], who recorded a jump of {{T&Fcalc|3.73}} at the [[NFL Combine]] on February 23, 2015

> a minimum performance in a standing long jump test is required to join the Federal Police (2.14 m for men 1.66 m for women

### Wikipedia, "High jump" — https://en.wikipedia.org/w/index.php?title=High_jump&action=raw

> [[Javier Sotomayor]] (Cuba) is the world record holder with a jump of {{T&Fcalc|2.45}} set in 1993

### Wikipedia, "Vertical jump" — https://en.wikipedia.org/w/index.php?title=Vertical_jump&action=raw

> The counter-movement of the legs, a quick bend of the knees which lowers the [[center of mass]] prior to springing upwards, has been shown to improve jump height by 12% compared to jumping without

### Wikipedia, "Parkour" — https://en.wikipedia.org/w/index.php?title=Parkour&action=raw

> * "Precision jump": Jumping and landing accurately with the feet on small or narrow obstacles.

> * "Wall run": Running toward a high wall and then jumping and pushing off the wall with a foot to reach the top of the wall.

## What is good to play: the numbers working controllers ship with

### Jeh3no, advanced first-person controller (MIT), `player_character_script.gd` — https://github.com/Jeh3no/Godot-Advanced-State-Machine-First-Person-Controller at commit 7285087aa8eee52d2332083503147b91c88d943d

> @export var walk_speed: float = 7.0

> @export var run_speed: float = 12.0

> @export var jump_height: float = 2.0
> @export var jump_time_to_peak: float = 0.3
> @export var jump_time_to_fall: float = 0.25

> @export var coyote_jump_cooldown: float = 0.3

### DeiranZ, parkour controller (MIT), `src/player/player.gd` — https://github.com/DeiranZ/godot-parkour-fps-controller at commit 4e401a258a83ddabc1a02d66befac53657970eba

> var speed: float = 15

> var gravity: float = 9.8
> var jump: float = 8

### NOSHOT controller (MIT), `Scripts/PlayerMovement.cs` — https://github.com/theRealUnd3rdog/Godot_Noshot_Controller at commit 15ac57ce0b7f1ab94c264fecd14e87732c8264fb

> [Export] public float walkingSpeed {private set; get;} = 5.0f;
> [Export] public float sprintingSpeed {private set; get;} = 8.0f;
> [Export] public float maxSpeed {private set; get;} = 12f;

> [Export] private float _jumpVelocity = 4.5f;

### GDQuest third-person controller (code MIT), `player/player.gd` — https://github.com/gdquest-demos/godot-4-3d-third-person-controller at commit b3bd6e81084f568be8aa44a69a0c2b1e52e806b3

> @export var move_speed := 8.0

> @export var jump_initial_impulse := 12.0

> var _gravity: float = -30.0

### Godot demo `3d/platformer` (MIT), `player/player.gd` — https://github.com/godotengine/godot-demo-projects at commit b761b4cd5718a7118f2c95eb55f181d0a5f004f1

> const MAX_SPEED: float = 6.0

> const JUMP_VELOCITY: float = 12.5

### Andicraft, stairs-character (MIT), `stairs_character.gd` — https://github.com/Andicraft/stairs-character at commit 5403d02f6b64b49a1d1bd7af11dd51a6edfc9e6c

> @export var _step_height : float = 0.33

## What the brief fixes — `BUILD-BRIEF.md`, item 1

> Each main route is 1.5 to 2.5 km long, a run of three to five minutes.

> Flow: at least 60% of each main route's recorded run at or above 70% of top speed, with no stop longer than 1 s (from `desert-course`).

## Arithmetic on the above (the builder's, not quoted)

- 44.72 km/h is 12.42 m/s; Bolt's race average, 37.578 km/h, is 10.44 m/s.
- Route length over run time: 1,500 m in 300 s is 5.0 m/s; 2,500 m in 180 s is 13.9 m/s. A top speed has to let the average land in that range with stops, jumps and turns counted.
- Jump heights the game numbers imply: Jeh3no 2.0 m (stated); GDQuest 12² ÷ (2 × 30) = 2.4 m; DeiranZ 8² ÷ (2 × 9.8) = 3.3 m.
