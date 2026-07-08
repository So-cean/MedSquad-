class_name FontRegistry
extends RefCounted

## Centralized Chinese font loader with caching.
##
## Static helper — not an autoload node. Use FontRegistry.get_cn_font()
## anywhere in the project to get a cached FontVariation for NotoSansSC-VF.

static var _cached_font: FontVariation = null


static func get_cn_font() -> FontVariation:
	if _cached_font:
		return _cached_font
	var tex: FontFile = load("res://assets/fonts/NotoSansSC-VF.ttf") as FontFile
	if tex:
		_cached_font = FontVariation.new()
		_cached_font.base_font = tex
	return _cached_font
