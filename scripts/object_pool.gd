extends Node

## Object pooling system. Autoloaded as "Pool".
## Reduces GC pressure by recycling frequently spawned nodes
## (damage numbers, coins, exp orbs, projectiles, particles).

# Pool storage: { pool_key: [available_nodes] }
var _pools: Dictionary = {}
# Active count tracking for diagnostics
var _active_counts: Dictionary = {}
# Maximum pool size per type (prevent unbounded growth)
const MAX_POOL_SIZE: int = 50

## Get or create a node from the pool.
## pool_key: unique identifier for this pool (e.g. "damage_number", "coin")
## factory: Callable that creates a new instance if pool is empty
func acquire(pool_key: String, factory: Callable) -> Node:
	if not _pools.has(pool_key):
		_pools[pool_key] = []
		_active_counts[pool_key] = 0

	var pool: Array = _pools[pool_key]
	var node: Node = null

	# Try to reuse from pool
	while not pool.is_empty():
		var candidate: Node = pool.pop_back()
		if is_instance_valid(candidate):
			node = candidate
			break

	# Create new if pool was empty
	if node == null:
		node = factory.call()

	_active_counts[pool_key] = _active_counts.get(pool_key, 0) + 1
	return node

## Return a node to the pool for reuse.
## Removes it from the scene tree and stores it.
func release(pool_key: String, node: Node) -> void:
	if not is_instance_valid(node):
		return

	if not _pools.has(pool_key):
		_pools[pool_key] = []
		_active_counts[pool_key] = 0

	var pool: Array = _pools[pool_key]
	_active_counts[pool_key] = maxi(_active_counts.get(pool_key, 1) - 1, 0)

	# Don't let pool grow too large
	if pool.size() >= MAX_POOL_SIZE:
		node.queue_free()
		return

	# Remove from tree but keep alive
	if node.get_parent():
		node.get_parent().remove_child(node)
	node.set_process(false)
	node.set_physics_process(false)
	pool.append(node)

## Release a node after a delay (for particles, damage numbers, etc.)
func release_delayed(pool_key: String, node: Node, delay: float) -> void:
	if not is_instance_valid(node):
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		release(pool_key, node)
	)

## Pre-warm a pool by creating instances ahead of time.
func prewarm(pool_key: String, count: int, factory: Callable) -> void:
	if not _pools.has(pool_key):
		_pools[pool_key] = []
		_active_counts[pool_key] = 0

	var pool: Array = _pools[pool_key]
	for i in range(count):
		if pool.size() >= MAX_POOL_SIZE:
			break
		var node: Node = factory.call()
		node.set_process(false)
		node.set_physics_process(false)
		pool.append(node)

## Clear all pools and free all pooled nodes.
func clear_all() -> void:
	for key in _pools:
		var pool: Array = _pools[key]
		for node in pool:
			if is_instance_valid(node):
				node.queue_free()
		pool.clear()
	_pools.clear()
	_active_counts.clear()

## Clear a specific pool.
func clear_pool(pool_key: String) -> void:
	if not _pools.has(pool_key):
		return
	var pool: Array = _pools[pool_key]
	for node in pool:
		if is_instance_valid(node):
			node.queue_free()
	pool.clear()
	_active_counts[pool_key] = 0

## Get pool diagnostics for debug display.
func get_stats() -> Dictionary:
	var stats := {}
	for key in _pools:
		stats[key] = {
			"pooled": _pools[key].size(),
			"active": _active_counts.get(key, 0),
		}
	return stats

## Get total number of pooled (inactive) objects across all pools.
func get_total_pooled() -> int:
	var total := 0
	for key in _pools:
		total += _pools[key].size()
	return total
