class_name GreedySliceMerger
extends RefCounted

## Pure utility for 2D rectangular greedy quad merging on a slice mask.
## Merges adjacent identical-material cells to minimize polygon count.

static func merge_slice(mask: PackedByteArray, dim_u: int, dim_v: int) -> Array[Dictionary]:
	var quads: Array[Dictionary] = []
	var visited = PackedByteArray()
	visited.resize(dim_u * dim_v)
	visited.fill(0)

	for v in range(dim_v):
		for u in range(dim_u):
			var idx = u + v * dim_u
			if visited[idx] == 1:
				continue

			var mat = mask[idx]
			if mat == 0:
				continue

			# 1. Expand width along U
			var w = 1
			while (u + w) < dim_u:
				var next_idx = (u + w) + v * dim_u
				if visited[next_idx] == 1 or mask[next_idx] != mat:
					break
				w += 1

			# 2. Expand depth along V
			var d = 1
			var can_expand = true
			while (v + d) < dim_v and can_expand:
				for check_u in range(u, u + w):
					var row_idx = check_u + (v + d) * dim_u
					if visited[row_idx] == 1 or mask[row_idx] != mat:
						can_expand = false
						break
				if can_expand:
					d += 1

			# 3. Mark merged region as visited
			for rv in range(v, v + d):
				for ru in range(u, u + w):
					visited[ru + rv * dim_u] = 1

			quads.append({
				"u": u,
				"v": v,
				"w": w,
				"d": d,
				"mat": mat
			})

	return quads
