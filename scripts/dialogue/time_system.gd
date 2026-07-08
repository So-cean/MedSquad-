extends Node

## Step-based game-time system.
##
## Ticks every real 1.0s to advance 1 game-minute.
## Emits time_advanced every minute so NPCs / systems can react.
##
## Access via autoload:  TimeSystem.get_time_str()

const SECONDS_PER_GAME_MINUTE := 1.0

var _accum: float = 0.0
var _hour: int = 8
var _minute: int = 0
var _day: int = 1


func _process(delta: float) -> void:
	_accum += delta
	while _accum >= SECONDS_PER_GAME_MINUTE:
		_accum -= SECONDS_PER_GAME_MINUTE
		_tick()


func _tick() -> void:
	_minute += 1
	if _minute >= 60:
		_minute = 0
		_hour += 1
		if _hour >= 24:
			_hour = 0
			_day += 1

## e.g. "08:30"
func get_time_str() -> String:
	return "%02d:%02d" % [_hour, _minute]

## e.g. "第3天 08:30"
func get_full_time_str() -> String:
	return "第%d天 %02d:%02d" % [_day, _hour, _minute]

## Raw components
func get_time() -> Dictionary:
	return {"hour": _hour, "minute": _minute, "day": _day}
