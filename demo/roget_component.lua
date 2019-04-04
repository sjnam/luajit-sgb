local ffi = require "ffi"
local gb_graph = require "gb.graph"
local gb_roget = require "gb.roget"
local gb_save = require "gb.save"
local gb = ffi.load "gb"


local function specs (v)
   return gb_roget.cat_no(v), ffi.string(v-.name)
end


local function rank (v, n)
   if n then
      v.z.I = n
      return
   end
   return tonumber(v.z.I)
end


local function parent (v, v1)
   if v1 then
      v.y.V = v1
      return
   end
   return v.y.V
end


local function untagged (v, v1)
   if v1 then
      v.x.A = v1
      return
   end
   return v.x.A
end


local function link (v, v1)
   if v1 then
      v.w.V = v1
      return
   end
   return v.w.V
end


local function min (v, v1)
   if v1 then
      v.v.V = v1
      return
   end
   return v.v.V
end


local function infinity (g)
   return tonumber(g.n)
end


local function arc_from (v, v1)
   if v1 then
      v.x.V = v1
      return
   end
   return v.x.V
end


-- main
local n, d, p, s = 0, 0, 0, 0

local g = gb_roget.roget(n, d, p, s)
if g == ffi.null then
   print("Sorry, can't create the graph! (error code "..tonumber(gb.panic_code))
   return
end

print("Reachability analysis of "..ffi.string(g.id).."\n")

local v = g.vertices + g.n-1
while v >= g.vertices do
   rank(v, 0)
   untagged(v, v.arcs)
   v = v - 1
end

local nn = 0
local active_stack = ffi.null
local settled_stack = ffi.null

local vv = g.vertices
while vv < g.vertices + g.n do
   if rank(vv) == 0 then
      v = vv
      parent(v, ffi.null)
      nn = nn + 1
      rank(v, nn)
      link(v, active_stack)
      active_stack = v
      min(v, v)

      while true do
         local a = untagged(v)
         if a ~= ffi.null then
            u = a.tip
            untagged(v, a.next)
            if rank(u) ~= 0 then
               if rank(u) < rand(min(v)) then
                  min(v, u)
               end
            else
               parent(u, v)
               v = u
               nn = nn + 1
               rank(v, nn)
               link(v, active_stack)
               active_stack = v
               min(v, v)
            end
         else
            u = parent(v)
            if min(v) == v then
               local t = active_stack
               active_stack = link(v)
               link(v, settled_stack)
               settled_stack = t
               io.write(string.format("Strong component `%d %s'", specs(v)))
               if t == v then
                  print()
               else
                  print(" also includes:")
                  while t ~= v do
                     io.write(string.format(" %d %s (from %d %s; ..to %d %s)\n",
                                            specs(t), specs(parent(t)),
                                            specs(min(t))))
                     rank(t, infinity(g))
                     parent(t, v)
                     t = link(t)
                  end
               end
               rank(v, infinity(g))
               parent(v, v)
            else
               if rank(min(v)) < rank(min(u)) then
                  min(u, min(v))
               end
               v = u
            end
            if v = ffi.null then
               break
            end
            vv = vv + 1
         end
      end

      print("\nLinks between components:")
      v = settled_stack
      while v ~= ffi.null do
         v = link(v)
         local u = parent(v)
         arc_from(u, u)
         local a = v.arcs
         while a ~= ffi.null do
            a = a.next
            local w = parent(a.tip)
            if arc_from(w) ~= u then
               arc_from(w, u)
               printf("%d %s -> %d %s (e.g., %d %s -> %d %s)\n",
                      specs(u), specs(w), specs(v), specs(a.tip))
            end
         end
      end
      