--- Various geometric intersections
-- @module intersect

local current_folder = (...):gsub('%.[^%.]+$', '') .. "."

local constants = require(current_folder .. "constants")
local vec3      = require(current_folder .. "vec3")

local abs, min, max = math.abs, math.min, math.max
local FLT_EPSILON   = constants.FLT_EPSILON

local intersect = {}


-- ray.position is a vec3
-- ray.direction is a vec3
-- aabb.min is a vec3
-- aabb.max is a vec3
local dir, dirfrac = vec3(), vec3()
function intersect.ray_aabb(ray, aabb)
	vec3.normalize(dir, ray.direction)
	dirfrac.x = 1 / dir.x
	dirfrac.y = 1 / dir.y
	dirfrac.z = 1 / dir.z

	local t1 = (aabb.min.x - ray.position.x) * dirfrac.x
	local t2 = (aabb.max.x - ray.position.x) * dirfrac.x
	local t3 = (aabb.min.y - ray.position.y) * dirfrac.y
	local t4 = (aabb.max.y - ray.position.y) * dirfrac.y
	local t5 = (aabb.min.z - ray.position.z) * dirfrac.z
	local t6 = (aabb.max.z - ray.position.z) * dirfrac.z

	local tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6))
	local tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6))

	-- ray is intersecting AABB, but whole AABB is behind us
	if tmax < 0 then
		return false
	end

	-- ray does not intersect AABB
	if tmin > tmax then
		return false
	end

	-- return position of intersection
	return tmin
end

-- ray.position is a vec3
-- ray.direction is a vec3
-- plane.position is a vec3
-- plane.normal is a vec3
-- https://www.cs.princeton.edu/courses/archive/fall00/cs426/lectures/raycast/sld017.htm
function intersect.ray_plane(ray, plane)
	local d = vec3.dist(ray.position, plane.position)
	local r = vec3.dot(ray.direction, plane.normal)

	-- ray does not intersect plane
	if r <= 0 then
		return false
	end

	-- distance of direction
	local t = -(vec3.dot(ray.position, plane.normal) + d) / r
	local out = vec3()
	vec3.mul(out, ray.direction, t)
	vec3.add(out, ray.position, out)

	-- return position of intersection
	if vec3.dot(out, plane.normal) + d < FLT_EPSILON then
		return out
	end

	-- ray does not intersect plane
	return false
end

-- ray.position is a vec3
-- ray.direction is a vec3
-- triangle[1] is a vec3
-- triangle[2] is a vec3
-- triangle[3] is a vec3
-- http://www.lighthouse3d.com/tutorials/maths/ray-triangle-intersection/
local h, s, q, e1, e2 = vec3(), vec3(), vec3(), vec3(), vec3()
function intersect.ray_triangle(ray, triangle)
	vec3.sub(e1, triangle[2], triangle[1])
	vec3.sub(e2, triangle[3], triangle[1])

	vec3.cross(h, ray.direction, e2)
	local a = vec3.dot(h, e1)

	-- if a is too close to 0, ray does not intersect triangle
	if abs(a) <= FLT_EPSILON then
		return false
	end

	local f = 1 / a
	vec3.sub(s, ray.position, triangle[1])
	local u = vec3.dot(s, h) * f

	-- ray does not intersect triangle
	if u < 0 or u > 1 then
		return false
	end

	vec3.cross(q, s, e1)
	local v = vec3.dot(ray.direction, q) * f

	-- ray does not intersect triangle
	if v < 0 or u + v > 1 then
		return false
	end

	-- at this stage we can compute t to find out where
	-- the intersection point is on the line
	local t = vec3.dot(q, e2) * f

	-- return position of intersection
	if t >= FLT_EPSILON then
		local out = vec3()
		vec3.mul(out, ray.direction, t)
		vec3.add(out, ray.position, out)
		return out
	end

	-- ray does not intersect triangle
	return false
end

-- a[1] is a vec3
-- a[2] is a vec3
-- b[1] is a vec3
-- b[2] is a vec3
-- Algorithm is ported from the C algorithm of
-- Paul Bourke at http://local.wasp.uwa.edu.au/~pbourke/geometry/lineline3d/
-- Archive.org am hero \o/
local p13, p43, p21, out1, out2 = vec3(), vec3(), vec3(), vec3(), vec3()
function intersect.line_line(a, b)
	-- new points
	vec3.sub(p13, a[1], b[1])
	vec3.sub(p43, b[2], b[1])
	vec3.sub(p21, a[2], a[1])

	-- if lengths are negative or too close to 0, lines do not intersect
	if vec3.len2(p43) < FLT_EPSILON or vec3.len2(p21) < FLT_EPSILON then
		return false
	end

	-- dot products
	local d1343 = vec3.dot(p13, p43)
	local d4321 = vec3.dot(p43, p21)
	local d1321 = vec3.dot(p13, p21)
	local d4343 = vec3.dot(p43, p43)
	local d2121 = vec3.dot(p21, p21)
	local denom = d2121 * d4343 - d4321 * d4321

	-- if denom is too close to 0, lines do not intersect
	if abs(denom) < FLT_EPSILON then
		return false
	end

	local numer = d1343 * d4321 - d1321 * d4343
	local mua   = numer / denom
	local mub   = (d1343 + d4321 * (mua)) / d4343

	-- return positions of intersection on each line
	vec3.mul(out1, mua, p21)
	vec3.add(out1, a[1], out)
	vec3.mul(out2, mub, p43)
	vec3.add(out2, b[1], out2)

	return out1, out2
end

-- a[1] is a vec3
-- a[2] is a vec3
-- b[1] is a vec3
-- b[2] is a vec3
function intersect.segment_segment(a, b)
	local c1, c2 = intersect.line_line(a, b)

	-- return positions of line intersections if within segment ranges
	if c1 and c2 then
		if ((a[1] <= c1 and c1 <= a[2]) or (a[1] >= c1 and c1 >= a[2])) and
			((b[1] <= c2 and c2 <= b[2]) or (b[1] >= c2 and c2 >= b[2])) then
			return c1, c2
		end
	end

	-- segments do not intersect
	return false
end

-- point is a vec3
-- aabb.min is a vec3
-- aabb.max is a vec3
function intersect.point_aabb(point, aabb)
	return
		aabb.min.x <= point.x and
		aabb.max.x >= point.x and
		aabb.min.y <= point.y and
		aabb.max.y >= point.y and
		aabb.min.z <= point.z and
		aabb.max.z >= point.z
end

-- a.min is a vec3
-- a.max is a vec3
-- b.min is a vec3
-- b.max is a vec3
function intersect.aabb_aabb(a, b)
	return
		a.min.x <= b.max.x and
		a.max.x >= b.min.x and
		a.min.y <= b.max.y and
		a.max.y >= b.min.y and
		a.min.z <= b.max.z and
		a.max.z >= b.min.z
end

-- outer.min is a vec3
-- outer.max is a vec3
-- inner.min is a vec3
-- inner.max is a vec3
function intersect.encapsulate_aabb(outer, inner)
	return
		outer.min <= inner.min and
		outer.max >= inner.max
end

-- a.position is a vec3
-- a.radius is a number
-- b.position is a vec3
-- b.radius is a number
function intersect.circle_circle(a, b)
	return vec3.dist(a.position, b.position) <= a.radius + b.radius
end

return intersect
