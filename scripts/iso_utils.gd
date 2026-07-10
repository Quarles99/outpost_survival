extends RefCounted
class_name IsoUtils

const TILE_WIDTH := 128.0
const TILE_HEIGHT := 64.0


static func grid_to_screen(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_WIDTH * 0.5,
		(grid.x + grid.y) * TILE_HEIGHT * 0.5
	)


static func screen_to_grid(screen: Vector2) -> Vector2:
	var a := screen.x / (TILE_WIDTH * 0.5)
	var b := screen.y / (TILE_HEIGHT * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)
